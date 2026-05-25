# SyncSpend — Análise do Schema Notion (Finance Balance)

## Visão Geral

O banco de dados de destino é a tabela **Finance Balance**, dentro da página **Finance** no Notion. É um tracker financeiro pessoal com 8 campos, cobrindo tanto entradas quanto saídas, com suporte a múltiplas categorias e métodos de pagamento.

---

## Schema Completo

| Campo | Tipo | Valores possíveis | Observações |
|---|---|---|---|
| **Name** | Título (text) | Livre | Nome da transação / estabelecimento |
| **Amount** | Número (real) | Qualquer valor numérico | Sem formatação de moeda definida no schema — usa `real` |
| **Type** | Select | `Income`, `Expense` | Distingue entrada vs. saída |
| **Category** | Select | Ver lista abaixo | 16 opções de categoria |
| **Payment Method** | Select | `Credit Card`, `Debit Card`, `PIX`, `Cash` | Método de pagamento |
| **Date** | Data + Hora | Formato `DD/MM/YYYY HH:mm` | Data real da transação |
| **Ref. Date** | Data | Formato `DD/MM/YYYY` | Data de referência (ex: fechamento da fatura) |
| **Description** | Texto livre | Qualquer texto | Campo opcional para notas adicionais |

### Categorias disponíveis

| Categoria | Cor | Contexto |
|---|---|---|
| Salary | Marrom | Renda — salário |
| Freelance | Amarelo | Renda — trabalho freelance |
| Payback | Roxo | Recebimento de devolução |
| Borrow | Laranja | Dinheiro emprestado (recebido ou dado) |
| Car | Marrom | Despesas com veículo |
| Entertainment | Verde | Lazer e entretenimento |
| FeetCare | Vermelho | Cuidados pessoais (podologia/pedicure) |
| Fuel | Amarelo | Combustível |
| Health | Vermelho | Saúde |
| Insurance | Cinza | Seguros |
| Internet | Azul | Serviço de internet |
| Phone | Padrão | Telefone |
| Shopping | Padrão | Compras gerais |
| Subscription | Rosa | Assinaturas recorrentes |
| The Plan | Laranja | Categoria específica — possivelmente um planejamento financeiro pessoal |
| Other | Cinza | Outros / não classificados |

---

## Análise para o SyncSpend

### Campos preenchíveis automaticamente via Apple Wallet

Quando o usuário passa o cartão na maquininha, as informações disponíveis no recibo/notificação do Apple Wallet são:

| Campo Notion | Fonte Apple Wallet | Preenchimento |
|---|---|---|
| **Name** | Nome do estabelecimento (merchant name) | ✅ Automático |
| **Amount** | Valor da transação | ✅ Automático |
| **Date** | Timestamp da transação | ✅ Automático |
| **Payment Method** | Sempre `Credit Card` no contexto do Apple Wallet | ✅ Automático (fixo) |
| **Type** | Sempre `Expense` para compras no cartão | ✅ Automático (fixo) |
| **Category** | Não disponível diretamente — precisa de inferência | ⚠️ Inferido ou manual |
| **Ref. Date** | Não disponível — depende do ciclo da fatura | ⚠️ Calculado ou manual |
| **Description** | Não disponível na notificação | ❌ Manual ou vazio |

### Pontos de atenção

**1. Category — o campo mais crítico**
A categorização automática é o maior desafio. As opções são bastante específicas (FeetCare, The Plan, Borrow). A abordagem mais viável é:
- Inferência por nome do estabelecimento (ex: "Shell" → Fuel, "Netflix" → Subscription)
- Fallback para `Other` quando não há correspondência
- Possibilidade de o usuário corrigir depois no Notion

**2. Ref. Date — data de referência da fatura**
Este campo parece servir para agrupar transações por ciclo de fatura (ex: compra feita em 20/05 cai na fatura de junho). O SyncSpend pode:
- Calcular automaticamente com base no dia de fechamento do cartão do usuário
- Deixar vazio inicialmente e o usuário preenche
- Receber como configuração fixa (ex: "meu cartão fecha todo dia 10")

**3. Amount — formato numérico**
O schema usa `number_format: "real"` sem definição de moeda. Isso significa que o valor será armazenado como número puro (ex: `49.90`). O SyncSpend deve garantir que o valor vindo do Apple Wallet seja convertido para número antes de inserir.

**4. Name — merchant name vs. nome amigável**
O Apple Wallet costuma retornar nomes de estabelecimentos em formato bruto (ex: `POSTO IPIRANGA 0042 SP`). Pode ser interessante uma camada de normalização ou deixar como veio para manter fidelidade ao extrato.

---

## Mapeamento de Payload para Inserção no Notion

Para cada transação capturada via Apple Wallet, o SyncSpend deverá montar um payload assim:

```json
{
  "Name": "Shell - Posto Centro",
  "Amount": 150.00,
  "Type": "Expense",
  "Category": "Fuel",
  "Payment Method": "Credit Card",
  "date:Date:start": "2026-05-25T14:32:00",
  "date:Ref. Date:start": "2026-06-10",
  "Description": ""
}
```

---

## Gaps e Sugestões de Evolução do Schema

| Gap identificado | Sugestão |
|---|---|
| Sem campo de moeda | Adicionar propriedade `Currency` (select: BRL, USD, EUR) para suportar gastos internacionais |
| Sem campo de parcelas | Adicionar `Installments` (número) para registrar compras parceladas |
| Sem campo de estabelecimento | O `Name` está acumulando dois papéis; separar em `Merchant` (texto) e `Name` (título livre) pode ajudar na categorização automática |
| Sem tag de recorrência | Flag `Recurring` (checkbox) para identificar assinaturas vs. compras únicas |
| `The Plan` sem descrição | Categoria ambígua — documentar ou renomear para algo mais claro |

---

## Resumo

O schema do Finance Balance é simples, funcional e bem estruturado para um controle financeiro pessoal. Para o SyncSpend, os campos **Name**, **Amount**, **Date**, **Type** e **Payment Method** chegam automaticamente da transação. O principal trabalho de automação inteligente está em inferir a **Category** corretamente e calcular o **Ref. Date** com base no ciclo de fatura do usuário.
