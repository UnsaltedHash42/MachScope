import Foundation
import SecurityBridge

public enum AssessmentStatus: String {
    case accepted, rejected, unknown
}

public struct Assessment {
    public init() {}

    public func assessExecution(at url: URL) -> AssessmentStatus {
        var status: OSStatus = errSecSuccess
        guard let unmanaged = SecBridge.copyAssessment(forPath: url.path, operation: "execute", error: &status) else {
            return .unknown
        }
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
}


