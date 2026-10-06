import Foundation

public enum NormalizationTarget: String, Codable, CaseIterable, Sendable {
    case nfc = "NFC", nfd = "NFD", unchanged = "KeepForm"
    public func apply(_ text: String) -> String {
        switch self { case .nfc: text.precomposedStringWithCanonicalMapping; case .nfd: text.decomposedStringWithCanonicalMapping; case .unchanged: text }
    }
}
public enum ProductAccess: String, Codable, Sendable { case free, pro }
public enum RuleKind: String, Codable, CaseIterable, Sendable {
    case replace = "RuleReplace", prefix = "RulePrefix", suffix = "RuleSuffix", insert = "RuleInsert", removeFirst = "RuleRemoveFirst", removeLast = "RuleRemoveLast", keepFirst = "RuleKeepFirst", keepLast = "RuleKeepLast", spaces = "RuleSpaces", uppercase = "RuleUppercase", lowercase = "RuleLowercase", titlecase = "RuleTitlecase", setName = "RuleSetName", numbering = "RuleNumbering", regex = "RuleRegex", wildcard = "RuleWildcard", accents = "RuleAccents", metadata = "RuleMetadata"
    public var pro: Bool { [.regex, .wildcard, .accents, .metadata].contains(self) }
}
public enum RuleScope: String, Codable, CaseIterable, Sendable { case stem = "Stem", name = "Name", fileExtension = "Extension" }
public struct RenameRule: Identifiable, Codable, Equatable, Sendable {
    public var id = UUID()
    public var kind: RuleKind
    public var scope: RuleScope = .stem
    public var enabled = true
    public var text = ""
    public var replacement = ""
    public var position = 0
    public var start = 1
    public var step = 1
    public var digits = 3
    public var repeatCount = 1
    public var restartCount = 0
    public var perFolder = false
    public var conditionExtension = ""
    public var metadataFallback: String?
    public init(_ kind: RuleKind) { self.kind = kind }
    public static func == (a: Self, b: Self) -> Bool {
        a.id == b.id && a.kind == b.kind && a.scope == b.scope && a.enabled == b.enabled &&
        Data(a.text.utf8) == Data(b.text.utf8) && Data(a.replacement.utf8) == Data(b.replacement.utf8) &&
        Data(a.conditionExtension.utf8) == Data(b.conditionExtension.utf8) && a.metadataFallback.map({ Data($0.utf8) }) == b.metadataFallback.map({ Data($0.utf8) }) &&
        a.position == b.position && a.start == b.start && a.step == b.step && a.digits == b.digits && a.repeatCount == b.repeatCount && a.restartCount == b.restartCount && a.perFolder == b.perFolder
    }
    public var requiresPro: Bool { kind.pro || !conditionExtension.isEmpty || (kind == .numbering && (step < 1 || perFolder || repeatCount != 1 || restartCount != 0)) }
}
public enum RuleFailure: String, Error, Sendable { case regexBudget = "RegexBudgetExceeded", proRequired = "ProRequired", invalid = "RuleInvalid", regex = "RegexInvalid", budget = "RuleBudgetExceeded", cancelled = "Cancelled", schema = "NewerSchema", missingMetadata = "MetadataMissing" }
public struct RuleContext: Sendable {
    public var index: Int
    public var folderIndex: Int
    public var isDirectory: Bool
    public var metadata: [String: String]
    public init(index: Int = 0, folderIndex: Int = 0, isDirectory: Bool = false, metadata: [String: String] = [:]) { self.index = index; self.folderIndex = folderIndex; self.isDirectory = isDirectory; self.metadata = metadata }
}
public struct RuleStep: Sendable { public var title: String; public var before: String; public var after: String }
public enum SequenceOrder: String, Codable, CaseIterable, Sendable { case path = "OrderPath", reversePath = "OrderReverse", name = "OrderName", manual = "OrderManual" }
public struct RulePipeline: Codable, Equatable, Sendable {
    public var schemaVersion = 1
    public var target: NormalizationTarget = .nfc
    public var rules: [RenameRule] = []
    public var mapping: NameMapping?
    public var pairExtensions: [String]?
    public var order: SequenceOrder?
    public var manualPaths: [Data]?
    public var dateFormat: String?
    public var timeZone: String?
    public init(target: NormalizationTarget = .nfc, rules: [RenameRule] = []) { self.target = target; self.rules = rules }
    public var requiresPro: Bool { mapping != nil || !(pairExtensions ?? []).isEmpty || rules.contains { $0.enabled && $0.requiresPro } }
    public func validate(access: ProductAccess) throws {
        guard schemaVersion == 1 else { throw RuleFailure.schema }
        guard rules.count <= 1024, Set(rules.map(\.id)).count == rules.count else { throw RuleFailure.invalid }
        if requiresPro && access != .pro { throw RuleFailure.proRequired }
        if let mapping { _ = try mapping.index() }
        if let pairExtensions, !pairExtensions.isEmpty {
            guard pairExtensions.count >= 2, pairExtensions.count <= 20,
                  Set(pairExtensions.map { $0.lowercased() }).count == pairExtensions.count,
                  pairExtensions.allSatisfy({ !$0.isEmpty && $0.count <= 16 && $0.allSatisfy({ $0.isLetter || $0.isNumber }) }),
                  mapping == nil, rules.allSatisfy({ !$0.enabled || $0.scope == .stem && $0.conditionExtension.isEmpty }) else { throw RuleFailure.invalid }
        }
        if let manualPaths { guard manualPaths.count <= 200000, Set(manualPaths).count == manualPaths.count else { throw RuleFailure.invalid } }
        for r in rules where r.enabled {
            guard (r.metadataFallback?.utf8.count ?? 0) <= 8192, r.text.utf8.count <= 8192, r.replacement.utf8.count <= 8192, (0...4096).contains(r.position), (0...18).contains(r.digits), r.repeatCount > 0, r.restartCount >= 0 else { throw RuleFailure.invalid }
            if [.replace, .regex, .wildcard, .metadata].contains(r.kind) && r.text.isEmpty { throw RuleFailure.invalid }
        }
    }
    public func evaluate(_ original: String, context: RuleContext = RuleContext(), access: ProductAccess = .free, cancelled: () -> Bool = { false }) throws -> [RuleStep] {
        try validate(access: access)
        var value = target.apply(original)
        var steps = [RuleStep(title: target.rawValue, before: original, after: value)]
        var components = Self.parts(value, directory: context.isDirectory)
        for r in rules where r.enabled {
            if cancelled() { throw RuleFailure.cancelled }
            let parts = components
            if !r.conditionExtension.isEmpty && parts.ext.lowercased() != r.conditionExtension.lowercased() { continue }
            let input = r.scope == .name ? value : r.scope == .fileExtension ? parts.ext : parts.stem
            let output = try Self.apply(r, input: input, context: context, cancelled: cancelled)
            guard output.utf8.count <= 16384 else { throw RuleFailure.budget }
            let before = value
            switch r.scope {
            case .name: value = output; components = Self.parts(value, directory: context.isDirectory)
            case .stem:
                components.stem = output
                value = output + (components.ext.isEmpty ? "" : "." + components.ext)
            case .fileExtension:
                if context.isDirectory { throw RuleFailure.invalid }
                components.ext = output
                value = components.stem + (output.isEmpty ? "" : "." + output)
            }
            steps.append(RuleStep(title: r.kind.rawValue, before: before, after: value))
        }
        // A chosen output form also applies to text inserted by rules.
        let final = target.apply(value)
        if Data(final.utf8) != Data(value.utf8) { steps.append(RuleStep(title: target.rawValue, before: value, after: final)) }
        return steps
    }
    public static func parts(_ name: String, directory: Bool) -> (stem: String, ext: String) {
        guard !directory, let dot = name.lastIndex(of: "."), dot != name.startIndex, dot != name.index(before: name.endIndex) else { return (name, "") }
        return (String(name[..<dot]), String(name[name.index(after: dot)...]))
    }
    private static func apply(_ r: RenameRule, input: String, context: RuleContext, cancelled: () -> Bool) throws -> String {
        switch r.kind {
        case .replace: return input.replacingOccurrences(of: r.text, with: r.replacement, options: .literal)
        case .prefix: return r.text + input
        case .suffix: return input + r.text
        case .insert:
            let at = input.index(input.startIndex, offsetBy: min(r.position, input.count)); return String(input[..<at]) + r.text + input[at...]
        case .removeFirst: return String(input.dropFirst(r.position))
        case .removeLast: return String(input.dropLast(r.position))
        case .keepFirst: return String(input.prefix(r.position))
        case .keepLast: return String(input.suffix(r.position))
        case .spaces: return input.split(whereSeparator: \.isWhitespace).joined(separator: " ")
        case .uppercase: return input.uppercased(with: Locale(identifier: "en_US_POSIX"))
        case .lowercase: return input.lowercased(with: Locale(identifier: "en_US_POSIX"))
        case .titlecase: return input.capitalized(with: Locale(identifier: "en_US_POSIX"))
        case .setName: return r.text
        case .accents: return input.folding(options: .diacriticInsensitive, locale: Locale(identifier: "en_US_POSIX"))
        case .metadata:
            let value = context.metadata[r.text].flatMap { $0.isEmpty ? nil : $0 } ?? r.metadataFallback
            guard let value, !value.isEmpty else { throw RuleFailure.missingMetadata }
            return input + r.replacement + value
        case .numbering:
            var i = (r.perFolder ? context.folderIndex : context.index) / r.repeatCount
            if r.restartCount > 0 { i %= r.restartCount }
            let (multiple, overflow) = i.multipliedReportingOverflow(by: r.step)
            let (number, overflow2) = r.start.addingReportingOverflow(multiple)
            guard !overflow, !overflow2 else { throw RuleFailure.invalid }
            let raw = String(number), sign = number < 0 ? "-" : "", magnitude = number < 0 ? String(raw.dropFirst()) : raw
            return input + r.text + sign + String(repeating: "0", count: max(0, r.digits - magnitude.count)) + magnitude
        case .regex, .wildcard:
            let pattern = r.kind == .regex ? r.text : NSRegularExpression.escapedPattern(for: r.text).replacingOccurrences(of: "\\*", with: ".*").replacingOccurrences(of: "\\?", with: ".")
            guard input.utf16.count <= 8192 else { throw RuleFailure.budget }
            let expression: NSRegularExpression
            do { expression = try NSRegularExpression(pattern: pattern) } catch { throw RuleFailure.regex }
            let deadline = Date().addingTimeInterval(0.05)
            var aborted = false, replacements: [(NSRange, String)] = []
            expression.enumerateMatches(in: input, options: [.reportProgress, .reportCompletion], range: NSRange(input.startIndex..., in: input)) { match, _, stop in
                if cancelled() || Date() > deadline { aborted = true; stop.pointee = true; return }
                if let match { replacements.append((match.range, expression.replacementString(for: match, in: input, offset: 0, template: r.replacement))) }
            }
            if aborted { throw cancelled() ? RuleFailure.cancelled : RuleFailure.regexBudget }
            let result = NSMutableString(string: input)
            for (range, replacement) in replacements.reversed() { result.replaceCharacters(in: range, with: replacement) }
            return result as String
        }
    }
}
