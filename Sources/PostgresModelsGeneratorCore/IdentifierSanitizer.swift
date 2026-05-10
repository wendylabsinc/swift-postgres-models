import Foundation

public struct IdentifierSanitizer {
    public static let reservedWords: Set<String> = [
        "class", "struct", "enum", "func", "var", "let", "if", "else", "for", "while",
        "do", "try", "catch", "throw", "throws", "return", "import", "in", "is", "as",
        "self", "Self", "true", "false", "nil", "switch", "case", "default", "break",
        "continue", "where", "guard", "defer", "repeat", "init", "deinit", "extension",
        "protocol", "typealias", "associatedtype", "operator", "subscript", "static",
        "open", "public", "internal", "fileprivate", "private", "final", "override",
        "required", "convenience", "lazy", "weak", "unowned", "mutating", "nonmutating",
        "inout", "some", "any", "actor", "async", "await", "type"
    ]

    /// `"todo_items"` → `"TodoItemsQueries"`, `"user-accounts"` → `"UserAccountsQueries"`
    public static func structName(from stem: String) -> String {
        let words = stem.components(separatedBy: CharacterSet(charactersIn: "_-"))
        let capitalized = words.filter { !$0.isEmpty }.map { capitalizeFirst($0) }
        return capitalized.joined() + "Queries"
    }

    /// `"GetUser"` → `"getUser"`, `"createUser"` → `"createUser"`
    public static func functionName(from name: String) -> String {
        guard !name.isEmpty else { return name }
        return name.prefix(1).lowercased() + name.dropFirst()
    }

    /// `"first_name"` → `"firstName"`, reserved words get backtick-escaped
    public static func columnName(from name: String) -> String {
        let words = name.components(separatedBy: "_")
        guard let first = words.first else { return name }
        let result = first + words.dropFirst().map { capitalizeFirst($0) }.joined()
        return reservedWords.contains(result) ? "`\(result)`" : result
    }

    private static func capitalizeFirst(_ s: String) -> String {
        guard !s.isEmpty else { return s }
        return s.prefix(1).uppercased() + s.dropFirst()
    }
}
