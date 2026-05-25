# App Brief — Finanças Pessoais + Notion (v1.0)
> Documento de referência para desenvolvimento via IA. Use este arquivo como contexto inicial em qualquer sessão de código. Ele descreve o produto completo, o MVP, decisões de arquitetura e o que **não** fazer.

---

## 1. Visão Geral

Um app iOS nativo que automatiza o registro de movimentações financeiras pessoais (gastos, assinaturas e receitas) diretamente em uma database do Notion, sem fricção e sem depender de um serviço externo com paywall.

**Princípios que guiam cada decisão:**
- **Zero fricção** — o usuário não deve precisar abrir o app para registrar um gasto comum.
- **Notion como backend** — toda a persistência de dados vive no Notion do usuário. O app é apenas uma camada de automação e interface.
- **Simples primeiro, escalável depois** — o app começa como ferramenta pessoal. Cada feature deve ser implementada de forma que a adição de paywall, multi-usuário e App Store no futuro seja cirúrgica, não uma reescrita.
- **Pouca manutenção** — evitar dependências frágeis. Preferir soluções nativas do iOS e da API pública do Notion.

---

## 2. Stack Técnica

| Camada | Escolha | Motivo |
|---|---|---|
| Linguagem | Swift | Nativo iOS, melhor integração com Shortcuts e NotificationCenter |
| UI | SwiftUI | Declarativo, rápido de iterar, pronto para novas versões do iOS |
| Backend de dados | Notion API (REST) | O usuário já usa Notion; zero custo de infra |
| Autenticação Notion | OAuth 2.0 (Notion Integration) | Fluxo oficial, seguro, sem armazenar credenciais |
| Automação | Apple Shortcuts (via URL Scheme) | Trigger de NFC já existe no ecossistema Apple |
| Notificações locais | UNUserNotificationCenter | Sem servidor de push; tudo roda no dispositivo |
| Armazenamento local | UserDefaults + Keychain | Configurações leves; token de acesso no Keychain |
| Background tasks | BackgroundTasks framework | Para disparar assinaturas no dia certo |

> **Sem backend próprio no MVP.** Toda lógica roda no dispositivo. Isso elimina custo de servidor e simplifica o desenvolvimento inicial.

---

## 3. Autenticação e Conexão com Notion

O app utiliza o fluxo oficial de OAuth do Notion:

1. Usuário toca em "Conectar ao Notion" no onboarding.
2. App abre o fluxo de autorização via `ASWebAuthenticationSession` (nativo iOS, sem sair do app).
3. Notion retorna um `access_token` que é armazenado no **Keychain** do dispositivo.
4. A partir daí, todas as chamadas à Notion API usam esse token.

O app **nunca armazena credenciais do usuário**. O token pode ser revogado a qualquer momento pelo próprio Notion.

**Preparação para paywall futuro:** o `access_token` do Notion fica no Keychain e é independente de qualquer sistema de conta do app. Quando um sistema de autenticação próprio for adicionado (ex: Supabase, RevenueCat), ele se sobrepõe sem mexer na integração com o Notion.

---

## 4. Onboarding

O onboarding guia o usuário por no máximo 3 etapas:

### Etapa 1 — Conectar ao Notion
Autorização OAuth conforme descrito acima.

### Etapa 2 — Selecionar ou criar a database de balanço
O app lista as databases disponíveis na workspace do usuário e pede para selecionar qual é a tabela principal de balanço financeiro.

Se o usuário não tiver uma, exibe um botão:
> **"Criar database modelo no meu Notion"**
Ao tocar, o app usa a Notion API para criar automaticamente uma database com a estrutura correta (ver seção 5.1) na workspace do usuário.

### Etapa 3 — Instalar o Apple Shortcut
O app exibe um botão:
> **"Adicionar Atalho ao meu app Atalhos"**

Ao tocar, o app abre o app **Atalhos** via URL scheme com o shortcut pré-configurado para importação:
```
shortcuts://import-shortcut?url=<URL_DO_ARQUIVO_SHORTCUT>&name=Registrar Gasto
```

O shortcut usa uma **automação de NFC**: ao aproximar o celular de uma tag NFC (colada na maquininha ou carteira), abre um formulário rápido (ou usa o Siri para capturar valor e categoria) e chama o app via URL scheme para registrar o gasto.

> **Nota de implementação:** o arquivo `.shortcut` deve ser hospedado em uma URL pública e estável (ex: GitHub Releases ou CDN simples). O app faz o deep link direto para importação.

---

## 5. Features — MVP

### 5.1 Expenses (core — já validado pelo SyncSpend)

**Estrutura esperada da database principal de balanço no Notion:**

| Coluna | Tipo Notion | Obrigatório |
|---|---|---|
| Nome / Descrição | Title | Sim |
| Valor | Number | Sim |
| Tipo | Select (`Gasto`, `Receita`, `Assinatura`) | Sim |
| Categoria | Select (personalizável) | Sim |
| Método de pagamento | Select | Não |
| Data | Date | Sim |
| Moeda | Select (`BRL`, `USD`, `EUR`) | Não (default BRL) |
| Notas | Rich Text | Não |

**Fluxo de registro de um gasto:**
1. Trigger via NFC (Apple Shortcut) ou abertura manual do app.
2. Usuário informa valor, categoria e método de pagamento (campos mínimos).
3. App envia para a database principal via Notion API.
4. Confirmação visual instantânea (toast/haptic feedback).

**Categorias padrão sugeridas:** Alimentação, Transporte, Saúde, Lazer, Moradia, Educação, Compras, Outros.
O usuário pode adicionar/remover categorias diretamente pelo Notion; o app busca as opções existentes dinamicamente via API.

---

### 5.2 Subscriptions (novo — crítico)

Gerencia assinaturas e contas recorrentes, disparando lançamentos automáticos na tabela de balanço principal.

#### Database de Assinaturas no Notion

O app cria (ou vincula) uma **database separada** na workspace do usuário. Botão no app:
> **"Criar database de Assinaturas no meu Notion"**

**Estrutura da database de assinaturas:**

| Coluna | Tipo Notion | Descrição |
|---|---|---|
| Nome do serviço | Title | Ex: Netflix, Spotify, iCloud+ |
| Valor | Number | Valor cobrado |
| Moeda | Select (`BRL`, `USD`, `EUR`) | Default BRL |
| Dia do vencimento | Number | Dia do mês (1–31) |
| Categoria | Select | Ex: Entretenimento, SaaS, Utilities |
| Método de pagamento | Select | Ex: Cartão de crédito, Débito automático |
| Ativa | Checkbox | Se desmarcado, o app ignora a assinatura |
| Última cobrança | Date | Preenchido automaticamente pelo app após cada lançamento |
| Notas | Rich Text | Observações livres |

#### Comportamento automático

O app usa o **BackgroundTasks framework** para rodar uma verificação diária. A lógica é:

```
Para cada assinatura com Ativa = true:
  Se hoje == dia do vencimento E ainda não foi lançada hoje:
    Criar entrada na database de balanço principal com:
      - Tipo: "Assinatura"
      - Nome: [nome do serviço]
      - Valor: [valor]
      - Categoria: [categoria]
      - Método: [método de pagamento]
      - Data: hoje
    Atualizar campo "Última cobrança" na database de assinaturas
    Enviar notificação local: "✅ [Netflix] lançado: R$ 55,90" ou "❌ Falha ao lançar [Netflix]"
```

> **Detalhe importante:** o app nunca duplica um lançamento. Antes de criar uma entrada, ele verifica se já existe uma entrada na database principal com o mesmo nome de serviço e data.

#### Fallback manual

O usuário pode abrir o app e ver a lista de assinaturas com status de cada uma (lançada/pendente neste mês). Há um botão para disparar manualmente qualquer assinatura pendente.

---

### 5.3 Gerenciamento de Categorias (sync bidirecional)

Categorias não vivem dentro do app — elas vivem no campo **Select** da database de balanço no Notion. O app apenas lê e escreve nesse campo via API. Isso elimina a necessidade de manter duas listas em sincronia manualmente.

#### Notion → App (leitura)

Toda vez que o usuário abre a tela de registro ou o seletor de categorias, o app faz uma chamada a `GET /v1/databases/{id}` e busca as opções atuais do campo Select. Se o usuário tiver adicionado "Pets" direto no Notion, na próxima abertura da tela o app já exibe "Pets".

#### App → Notion (escrita)

Se o usuário criar uma categoria nova dentro do app, o app chama `PATCH /v1/databases/{id}` atualizando as opções do campo Select. A nova categoria aparece imediatamente no Notion.

#### Limitação conhecida: app aberto

> **Dor:** se o usuário adicionar uma categoria no Notion enquanto o app já está aberto, ela **não aparece automaticamente** — a lista só é buscada novamente quando a tela é reaberta.

**Solução:** botão de atualizar (ícone de reload) visível na tela de categorias e no seletor de categorias durante o registro de um gasto. Ao tocar, o app refaz a chamada à API e atualiza a lista na hora, sem precisar fechar e reabrir o app.

Adicionalmente, o app deve rebuscar a lista de categorias automaticamente sempre que:
- O app volta ao foreground (via `sceneWillEnterForeground`)
- O usuário puxa a tela pra baixo (pull-to-refresh, se a tela for uma lista scrollável)

Não há necessidade de polling contínuo ou webhooks para esse caso — a busca sob demanda é suficiente e não desperdiça chamadas de API.

---

## 6. Features — Fase 2 (fora do MVP)

### 6.1 Incomes via Notificações

> **Status:** avaliar para a segunda fase. Complexidade moderada, mas viável.

**Abordagem para MVP da Fase 2:** parsing de notificações push de apps bancários, começando pelo **Nubank**.

**Como funciona no iOS:**
O iOS permite que o usuário autorize o app a ler notificações via **UNUserNotificationCenter** (leitura passiva) ou, mais robustamente, via um **Notification Service Extension** — uma extensão do app que intercepta notificações antes de serem exibidas.

**Lógica de parsing (Nubank como piloto):**

Notificação típica do Nubank: `"Você recebeu R$ 150,00 via Pix de João Silva"`

O app aplica regex para extrair:
- Valor: `R$\s*([\d.,]+)`
- Origem: `de\s+(.+)$`
- Tipo: palavras-chave como "recebeu", "depósito", "Pix" → classifica como `Receita`

Após o parse, o app:
1. Exibe uma notificação local: `"💰 Receita detectada: R$150,00 de João Silva — Confirmar?"`
2. Usuário toca em "Confirmar" (UNNotificationAction) ou abre o app.
3. O lançamento é enviado ao Notion com Tipo = "Receita".

**Expansão futura:** adicionar padrões de regex para outros bancos (Itaú, Inter, C6). Cada banco tem padrões distintos de notificação — isso vira uma lista de parsers mantida no próprio app.

**O que NÃO fazer nessa fase:** integração direta com APIs de bancos. Open Finance brasileiro é real mas exige certificação, contrato com cada instituição e overhead de segurança que não faz sentido para um app pessoal/early stage.

---

## 7. Arquitetura de Paywall (preparação)

O app é lançado com **acesso total e gratuito**. Mas toda a base de código deve ser escrita respeitando os seguintes contratos:

### Feature Flags

Criar um protocolo `FeatureAccess` logo no início:

```swift
protocol FeatureAccess {
    var canUseSubscriptions: Bool { get }
    var canUseIncomes: Bool { get }
    var canConnectMultipleWorkspaces: Bool { get }
}
```

Implementação inicial (MVP — tudo liberado):
```swift
struct FreeAccess: FeatureAccess {
    var canUseSubscriptions: Bool { true }
    var canUseIncomes: Bool { true }
    var canConnectMultipleWorkspaces: Bool { true }
}
```

Quando o paywall for adicionado, basta criar uma implementação `PremiumAccess` que verifica o status da assinatura (via RevenueCat, por exemplo) e substituir no container de injeção de dependência. **Zero mudança nas views ou na lógica de negócio.**

### Pontos de paywall futuros sugeridos

| Feature | Plano gratuito | Plano premium |
|---|---|---|
| Expenses manuais | ✅ Ilimitado | ✅ Ilimitado |
| Assinaturas | ✅ Até 5 | ✅ Ilimitado |
| Incomes automáticos | ❌ | ✅ |
| Múltiplas workspaces Notion | ❌ | ✅ |
| Exportação de relatórios | ❌ | ✅ |

> Esses limites são sugestões — o layout já existe no código via `FeatureAccess`, basta definir os valores.

### SDK recomendado para monetização futura

**RevenueCat** — gerencia assinaturas iOS (mensal, anual, vitalício) com painel de analytics, webhooks e suporte a introductory offers. Tem SDK Swift oficial e plano gratuito para até ~$2.5k MRR.

---

## 8. Preparação para App Store (futuro)

O app pode ser instalado via **TestFlight** ou **sideload** (AltStore/Xcode) durante a fase pessoal. Para publicação futura na App Store, os ajustes necessários são:

1. **Privacy Manifest (`PrivacyInfo.xcprivacy`)** — declarar uso de Keychain, notificações e background tasks. Obrigatório desde 2024.
2. **App Privacy Nutrition Label** — declarar no App Store Connect quais dados são coletados. Neste app: nenhum dado vai para servidores próprios (tudo fica no Notion do usuário).
3. **Background Task justification** — documentar o uso do BackgroundTasks framework para a Apple. A justificativa aqui é "disparar lançamentos de assinaturas recorrentes no horário configurado".
4. **Onboarding de permissões** — notificações locais precisam de permissão explícita. O onboarding já deve pedir isso de forma contextual ("Para te avisar quando uma assinatura for lançada").
5. **Paywall com StoreKit 2** — se for adicionar monetização, usar StoreKit 2 nativo (não depende de SDK externo, mas RevenueCat facilita o painel).
6. **Nome e bundle ID** — definir antes de subir para a App Store. Trocar depois é trabalhoso.

> **Importante:** nenhum desses itens bloqueia o desenvolvimento ou uso pessoal. São ajustes pontuais feitos na etapa de publicação.

---

## 9. O que NÃO fazer (decisões já tomadas)

- ❌ **Não criar backend próprio no MVP** — sem servidor, sem banco de dados próprio, sem autenticação própria. Tudo no Notion.
- ❌ **Não integrar diretamente com APIs de bancos** — complexidade regulatória e de manutenção desnecessária neste estágio.
- ❌ **Não usar React Native ou Flutter** — o app depende de integrações nativas (Shortcuts, NFC, BackgroundTasks, Notification Extensions) que são mais estáveis e simples em Swift puro.
- ❌ **Não replicar o SyncSpend visualmente** — a referência de identidade visual é o **Notion**, não o SyncSpend. Ver seção 11.

---

## 10. Escopo do MVP — Checklist

- [ ] Autenticação OAuth com Notion
- [ ] Onboarding: conectar Notion → selecionar/criar database → instalar Shortcut
- [ ] Registro manual de expense (valor, categoria, método, data)
- [ ] Trigger via Apple Shortcut + NFC
- [ ] Listagem simples de lançamentos recentes (últimos 30 dias, puxando do Notion)
- [ ] Módulo de assinaturas: criar/editar assinaturas, lançamento automático diário, notificação de sucesso/falha
- [ ] Botão "criar database de assinaturas no Notion"
- [ ] Protocolo `FeatureAccess` no código (tudo liberado por padrão)
- [ ] Categorias com sync bidirecional (leitura + escrita via Notion API)
- [ ] Botão de reload de categorias + rebusca automática ao voltar ao foreground

**Fora do MVP:**
- Módulo de incomes via notificações
- Relatórios / gráficos
- Múltiplas workspaces
- Paywall

---

## 11. Identidade do App (a definir)

### Nome

Ainda não definido. Ao nomear, considerar:
- Algo que remeta a controle financeiro **pessoal e sem fricção**, não a "gestão corporativa"
- Evitar nomes que soem como SaaS B2B
- Verificar disponibilidade no App Store e domínio `.app` ou `.io` caso queira divulgar futuramente

### Direção Visual

A referência primária de identidade visual é o **Notion**, não o SyncSpend. O objetivo é que o app pareça uma extensão natural do Notion no iOS — como se fosse um cliente nativo oficial dele.

**Princípios:**

- **Tipografia:** sem serifa, pesada nos títulos, leve nos textos de suporte. Seguir a hierarquia do Notion: tamanhos bem distintos entre título, subtítulo e corpo.
- **Espaçamento generoso:** muito respiro entre os elementos. Nada apertado. O espaço em branco (ou preto) faz parte do design.
- **Modo escuro por padrão:** o Notion é fortemente associado ao modo escuro. O app deve ter modo escuro como padrão, com suporte a modo claro via configuração do sistema.
- **Zero decoração desnecessária:** sem gradientes chamativos, sem ilustrações, sem ícones coloridos por padrão. Paleta neutra com um único acento de cor para ações primárias.
- **Liquid Glass (iOS 26+):** adotar o sistema de materiais do iOS nativamente — `ultraThinMaterial`, barras translúcidas, menus contextuais com vidro. Isso faz o app parecer nativo e moderno sem esforço de UI customizada. O Notion já adotou essa direção na versão iOS mais recente; o app segue o mesmo caminho.
- **Velocidade de input acima de tudo:** o usuário não deve passar mais de 5 segundos registrando um gasto manual. Nenhum elemento visual deve competir com as ações principais da tela.

> A consistência visual com o Notion não é acidental — como o app é uma extensão da workspace do usuário, parecer parte do mesmo ecossistema reforça a sensação de que tudo está integrado.

---

*Documento gerado em 2026-05-25. Atualizar este arquivo a cada decisão de produto significativa.*
