#if canImport(FoundationEssentials)
import FoundationEssentials
#else
import Foundation
#endif

public enum JSONValue: Equatable, Sendable {
    case null
    case bool(Bool)
    case number(Double)
    case string(String)
    case array([JSONValue])
    case object([String: JSONValue])
}

extension JSONValue: Decodable {
    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if container.decodeNil() {
            self = .null
        } else if let b = try? container.decode(Bool.self) {
            self = .bool(b)
        } else if let d = try? container.decode(Double.self) {
            self = .number(d)
        } else if let s = try? container.decode(String.self) {
            self = .string(s)
        } else if let a = try? container.decode([JSONValue].self) {
            self = .array(a)
        } else if let o = try? container.decode([String: JSONValue].self) {
            self = .object(o)
        } else {
            throw DecodingError.dataCorruptedError(
                in: container, debugDescription: "Unrecognised JSON value")
        }
    }

    public static func decode(from string: String) throws -> JSONValue {
        try JSONDecoder().decode(JSONValue.self, from: Data(string.utf8))
    }
}

extension JSONValue {
    public subscript(_ key: String) -> JSONValue? {
        if case let .object(o) = self { return o[key] }
        return nil
    }
    public subscript(_ index: Int) -> JSONValue? {
        if case let .array(a) = self, a.indices.contains(index) { return a[index] }
        return nil
    }
    public var stringValue: String? { if case let .string(s) = self { return s }; return nil }
    public var numberValue: Double? { if case let .number(n) = self { return n }; return nil }
    public var boolValue: Bool? { if case let .bool(b) = self { return b }; return nil }
    public var arrayValue: [JSONValue]? { if case let .array(a) = self { return a }; return nil }
    public var objectValue: [String: JSONValue]? { if case let .object(o) = self { return o }; return nil }
}
