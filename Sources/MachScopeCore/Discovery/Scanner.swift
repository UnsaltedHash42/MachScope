import Foundation

public final class Scanner {
    private let extractor: SignInfoExtractor

    public init(rulesEngine: RulesEngine? = nil) {
        self.extractor = SignInfoExtractor(rulesEngine: rulesEngine)
    }

    public func scan(urls: [URL], concurrency: Int = 8, assessmentEnabled: Bool = false) -> [Record] {
        if urls.isEmpty { return [] }
        let queue = OperationQueue()
        queue.maxConcurrentOperationCount = max(1, concurrency)
        let lock = NSLock()
        var records: [Record] = []

        for url in urls {
            queue.addOperation { [weak self] in
                guard let self = self else { return }
                let record = self.extractor.buildRecord(for: url, assessmentEnabled: assessmentEnabled)
                lock.lock()
                records.append(record)
                lock.unlock()
            }
        }
        queue.waitUntilAllOperationsAreFinished()
        return records
    }
}

// no-op


