import Testing
@testable import PostgresModelsGeneratorCore

struct IdentifierSanitizerTests {
    // MARK: structName

    @Test func structNameSimple() {
        #expect(IdentifierSanitizer.structName(from: "users") == "UsersQueries")
    }

    @Test func structNameSnakeCase() {
        #expect(IdentifierSanitizer.structName(from: "todo_items") == "TodoItemsQueries")
    }

    @Test func structNameKebabCase() {
        #expect(IdentifierSanitizer.structName(from: "user-accounts") == "UserAccountsQueries")
    }

    @Test func structNameMixed() {
        #expect(IdentifierSanitizer.structName(from: "order_line-items") == "OrderLineItemsQueries")
    }

    // MARK: functionName

    @Test func functionNameUpperCamel() {
        #expect(IdentifierSanitizer.functionName(from: "GetUser") == "getUser")
    }

    @Test func functionNameAlreadyLowerCamel() {
        #expect(IdentifierSanitizer.functionName(from: "createUser") == "createUser")
    }

    @Test func functionNameAllCaps() {
        #expect(IdentifierSanitizer.functionName(from: "LIST") == "lIST")
    }

    // MARK: columnName

    @Test func columnNameSimple() {
        #expect(IdentifierSanitizer.columnName(from: "id") == "id")
    }

    @Test func columnNameSnakeCase() {
        #expect(IdentifierSanitizer.columnName(from: "first_name") == "firstName")
    }

    @Test func columnNameMultipleUnderscores() {
        #expect(IdentifierSanitizer.columnName(from: "created_at_utc") == "createdAtUtc")
    }

    @Test func columnNameReservedWordClass() {
        #expect(IdentifierSanitizer.columnName(from: "class") == "`class`")
    }

    @Test func columnNameReservedWordIn() {
        #expect(IdentifierSanitizer.columnName(from: "in") == "`in`")
    }
}
