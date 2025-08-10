import Foundation
import SecurityBridge
import Dispatch

public enum AssessmentStatus: String {
    case accepted, rejected, unknown
}

public struct Assessment {
    public init() {}

    public func assessExecution(at url: URL) -> AssessmentStatus {
        // Guard: only attempt assessment on Mach-O binaries
        if !MachOMagic().isMachO(url) { return .unknown }
        var status: OSStatus = errSecSuccess
        // Serialize SecAssessment for stability
        let sem = DispatchSemaphore(value: 1)
        sem.wait()
        let unmanaged = SecBridge.copyAssessment(forPath: url.path, operation: "execute", error: &status)
        sem.signal()
        guard let unmanaged = unmanaged else { return .unknown }
        let cfDict = unmanaged.takeRetainedValue()
        let dict = cfDict as NSDictionary
        if let decision = dict["decision"] as? String {
            switch decision.lowercased() {
            case "allow", "accept", "accepted": return .accepted
            case "deny", "reject", "rejected": return .rejected
            default: break
            }
        }
        return .unknown
    }

    public func assessNotarizationString(at url: URL, enabled: Bool) -> String? {
        guard enabled else { return nil }
        switch assessExecution(at: url) {
        case .accepted: return "accepted"
        case .rejected: return "rejected"
        case .unknown: return nil
        }
    }
}


