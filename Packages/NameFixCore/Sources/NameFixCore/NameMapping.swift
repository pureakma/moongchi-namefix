import Foundation

public struct NameMapping: Codable, Equatable, Sendable {
    public struct Row: Codable, Equatable, Sendable {
        public var source: String
        public var destination: String
        public init(source: String, destination: String) { self.source = source; self.destination = destination }
    }
    public var rows: [Row]
    public init(rows: [Row]) { self.rows = rows }
    public func index() throws -> [Data: String] {
        guard rows.count <= 200_000 else { throw RuleFailure.budget }
        var index: [Data: String] = [:]
        for row in rows {
            guard !row.source.isEmpty, NameRules.valid(Data(row.destination.utf8)), index.updateValue(row.destination, forKey: Data(row.source.utf8)) == nil else { throw RuleFailure.invalid }
        }
        return index
    }
}
public struct DelimitedTextError: Error, Sendable { public var row: Int; public var reason: RuleFailure; public init(row: Int, reason: RuleFailure) { self.row = row; self.reason = reason } }
public enum DelimitedText {
    /// UTF-8 only. Preserve Unicode scalar spelling; do not canonicalize map keys.
    public static func parse(_ data: Data, separator: Unicode.Scalar = ",", cancelled: () -> Bool = { false }) throws -> [[String]] {
        guard data.count <= 32_000_000 else { throw RuleFailure.budget }
        guard var text = String(data: data, encoding: .utf8), [",", "\t"].contains(separator) else { throw RuleFailure.invalid }
        if text.unicodeScalars.first == "\u{FEFF}" { text.removeFirst() }
        let chars = text.unicodeScalars
        var result: [[String]] = [], row: [String] = [], field = "", quoted = false, afterQuote = false, i = chars.startIndex, visited = 0
        func finishField() { row.append(field); field = ""; afterQuote = false }
        func finishRow() { finishField(); result.append(row); row = [] }
        while i < chars.endIndex {
            if visited % 1024 == 0 && cancelled() { throw RuleFailure.cancelled }
            visited += 1
            let c = chars[i], next = chars.index(after: i)
            if quoted {
                if c == "\"" {
                    if next < chars.endIndex && chars[next] == "\"" { field.unicodeScalars.append(c); i = next }
                    else { quoted = false; afterQuote = true }
                } else { field.unicodeScalars.append(c) }
            } else if c == separator { finishField() }
            else if c == "\n" || c == "\r" {
                finishRow()
                if c == "\r", next < chars.endIndex, chars[next] == "\n" { i = next }
            } else if c == "\"" && field.isEmpty && !afterQuote { quoted = true }
            else {
                guard !afterQuote, c != "\"" else { throw DelimitedTextError(row: result.count + 1, reason: .invalid) }
                field.unicodeScalars.append(c)
            }
            if row.count > 1024 || result.count > 200_001 { throw RuleFailure.budget }
            i = chars.index(after: i)
        }
        guard !quoted else { throw DelimitedTextError(row: result.count + 1, reason: .invalid) }
        if !field.isEmpty || !row.isEmpty || afterQuote { finishRow() }
        return result
    }
    public static func encode(_ rows: [[String]], spreadsheetSafe: Bool = true) -> Data {
        Data(rows.map { row in row.map { field in
            var value = field
            if spreadsheetSafe, let first = value.first, ["=", "+", "-", "@", "\t", "\r", "\n"].contains(first) { value = "'" + value }
            return "\"" + value.replacingOccurrences(of: "\"", with: "\"\"") + "\""
        }.joined(separator: ",") }.joined(separator: "\r\n").utf8)
    }
}
