import Foundation

public final class Scanner {
    private let extractor: SignInfoExtractor

    public init(rulesEngine: RulesEngine? = nil) {
        self.extractor = SignInfoExtractor(rulesEngine: rulesEngine)
    }

    public func scan(
        urls: [URL],
        concurrency: Int = 8,
        progress: ((Int, Int) -> Void)? = nil
    ) -> [Record] {
        if urls.isEmpty { return [] }
        let queue = OperationQueue()
        queue.maxConcurrentOperationCount = max(1, concurrency)
        let lock = NSLock()
        var indexedRecords: [(Int, Record)] = []
        var lastProgress = Date()

        for (index, url) in urls.enumerated() {
            queue.addOperation { [weak self] in
                guard let self = self else { return }
                let record = autoreleasepool(invoking: { () -> Record in
                    return self.extractor.buildRecord(for: url)
                })
                var progressCount: Int?
                lock.lock()
                indexedRecords.append((index, record))
                let completed = indexedRecords.count
                let now = Date()
                if progress != nil,
                   completed % 500 == 0 || now.timeIntervalSince(lastProgress) >= 2 {
                    lastProgress = now
                    progressCount = completed
                }
                lock.unlock()
                if let progressCount {
                    progress?(progressCount, urls.count)
                }
            }
        }
        queue.waitUntilAllOperationsAreFinished()
        return indexedRecords.sorted { lhs, rhs in
            if lhs.1.path == rhs.1.path {
                return lhs.0 < rhs.0
            }
            return lhs.1.path.utf8.lexicographicallyPrecedes(rhs.1.path.utf8)
        }.map(\.1)
    }
}

// no-op


