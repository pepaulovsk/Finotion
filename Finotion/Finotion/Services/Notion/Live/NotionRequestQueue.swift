import Foundation

actor NotionRequestQueue {
    private var lastRequestTime: Date = .distantPast
    private let minimumInterval: TimeInterval

    init(minimumInterval: TimeInterval = 0.35) {
        self.minimumInterval = minimumInterval
    }

    func waitForSlot() async {
        let elapsed = Date.now.timeIntervalSince(lastRequestTime)
        if elapsed < minimumInterval {
            try? await Task.sleep(for: .seconds(minimumInterval - elapsed))
        }
        lastRequestTime = Date.now
    }
}
