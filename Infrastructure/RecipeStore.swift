import Foundation
import NameFixCore

public struct Recipe: Identifiable, Codable, Equatable, Sendable {
    public var id = UUID()
    public var name: String
    public var pipeline: RulePipeline
    public init(name: String, pipeline: RulePipeline) { self.name = name; self.pipeline = pipeline }
}
public struct RecipeLibrary: Codable, Sendable {
    public var schemaVersion = 1
    public var recipes: [Recipe] = []
    public var lastFree = RulePipeline()
    public init() {}
}
public actor RecipeStore {
    public let url: URL
    private var readOnly = false
    public init(url: URL) { self.url = url }
    public func load() throws -> RecipeLibrary {
        guard FileManager.default.fileExists(atPath: url.path) else { return RecipeLibrary() }
        do {
            guard (try url.resourceValues(forKeys: [.fileSizeKey]).fileSize ?? 0) <= 8_000_000 else { throw RuleFailure.budget }
            let data = try Data(contentsOf: url)
            guard data.count <= 8_000_000 else { throw RuleFailure.budget }
            let library = try JSONDecoder().decode(RecipeLibrary.self, from: data)
            guard library.schemaVersion == 1 else { throw RuleFailure.schema }
            try validate(library)
            return library
        } catch { readOnly = true; throw error }
    }
    private func validate(_ library: RecipeLibrary) throws {
        guard library.recipes.count <= 10000, Set(library.recipes.map(\.id)).count == library.recipes.count else { throw RuleFailure.invalid }
        try library.lastFree.validate(access: .free)
        for recipe in library.recipes {
            guard !recipe.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty, recipe.name.count <= 200 else { throw RuleFailure.invalid }
            try recipe.pipeline.validate(access: .pro)
        }
    }
    public func save(_ library: RecipeLibrary) throws {
        guard !readOnly else { throw FSError("RecipeReadOnly") }
        try validate(library)
        // Refuse what load() would reject, so one oversized preset cannot lock the whole library.
        let encoder = JSONEncoder(); encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        guard try encoder.encode(library).count <= 8_000_000 else { throw RuleFailure.budget }
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try Durable.atomic(library, to: url)
    }
}
