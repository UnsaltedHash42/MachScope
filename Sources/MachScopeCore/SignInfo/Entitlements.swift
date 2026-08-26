import Foundation

public enum EntitlementValue: Codable, Sendable, Equatable {
    case bool(Bool)
    case string(String)
    case int(Int)
    case double(Double)
    case array([EntitlementValue])
    case dictionary([String: EntitlementValue])
    case data(Int)
    case unknown

    public var isTrue: Bool {
        self == .bool(true)
    }

    public var asString: String? {
        guard case .string(let value) = self else { return nil }
        return value
    }

    public var asStringArray: [String]? {
        guard case .array(let values) = self else { return nil }
        let strings = values.compactMap(\.asString)
        return strings.count == values.count ? strings : nil
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .bool(let value):
            try container.encode(value)
        case .string(let value):
            try container.encode(value)
        case .int(let value):
            try container.encode(value)
        case .double(let value):
            try container.encode(value)
        case .array(let value):
            try container.encode(value)
        case .dictionary(let value):
            try container.encode(value)
        case .data(let count):
            try container.encode(["data_bytes": count])
        case .unknown:
            try container.encodeNil()
        }
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if container.decodeNil() {
            self = .unknown
        } else if let value = try? container.decode(Bool.self) {
            self = .bool(value)
        } else if let value = try? container.decode(Int.self) {
            self = .int(value)
        } else if let value = try? container.decode(Double.self) {
            self = .double(value)
        } else if let value = try? container.decode(String.self) {
            self = .string(value)
        } else if let value = try? container.decode([EntitlementValue].self) {
            self = .array(value)
        } else if let value = try? container.decode([String: EntitlementValue].self) {
            if value.count == 1, case .int(let count)? = value["data_bytes"] {
                self = .data(count)
            } else {
                self = .dictionary(value)
            }
        } else {
            throw DecodingError.dataCorruptedError(
                in: container,
                debugDescription: "Unsupported entitlement value"
            )
        }
    }
}

public struct Entitlements: Sendable {
    public let values: [String: EntitlementValue]

    public init(values: [String: EntitlementValue] = [:]) {
        self.values = values
    }

    public static func fromSigningInfo(_ info: [String: Any]) -> Entitlements {
        guard let rawValues = info["entitlements-dict"] as? [String: Any] else {
            return Entitlements()
        }
        return Entitlements(values: rawValues.mapValues(convert))
    }

    private static func convert(_ value: Any) -> EntitlementValue {
        if let number = value as? NSNumber {
            if CFGetTypeID(number) == CFBooleanGetTypeID() {
                return .bool(number.boolValue)
            }
            let type = String(cString: number.objCType)
            if type == "f" || type == "d" {
                return .double(number.doubleValue)
            }
            return .int(number.intValue)
        }
        if let string = value as? String {
            return .string(string)
        }
        if let data = value as? Data {
            return .data(data.count)
        }
        if let array = value as? [Any] {
            return .array(array.map(convert))
        }
        if let dictionary = value as? [String: Any] {
            return .dictionary(dictionary.mapValues(convert))
        }
        return .unknown
    }
}


