import Foundation

public struct HTMLReport {
    public init() {}
    public func render(records: [Record]) -> String {
        return "<!doctype html><meta charset=\"utf-8\"><title>MachScope Report</title><h1>MachScope Report</h1><p>Records: \(records.count)</p>"
    }
}


