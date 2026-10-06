import Foundation
import Darwin
import NameFixCore
import NameFixRuntime
import NameFixApplication

@main struct NameFixCLI {
    static func main() async {
        do { try await run() }
        catch { let code = (error as? RuleFailure)?.rawValue ?? (error as? FSError)?.code ?? "OperationError"; FileHandle.standardError.write(Data((code + "\n").utf8)); exit(code == "Cancelled" ? 3 : 1) }
    }
    static func run() async throws {
        var args = Array(CommandLine.arguments.dropFirst())
        if args.isEmpty || args.contains("--help") {
            print("""
            namefix [options] /absolute/file/or/folder ...
            Dry-run is the default. Files are never changed without interactive confirmation.
            --nfd / --keep-form           Output NFD / preserve form (default NFC)
            --no-recurse                 Scan selected folders and immediate children
            --prefix TEXT --suffix TEXT  Free basic rules (may repeat)
            --upper / --lower / --title / --spaces
            --insert POSITION TEXT       Grapheme-safe insertion
            --remove-first N / --remove-last N / --keep-first N / --keep-last N
            --name TEXT / --extension TEXT
            --rules-json FILE.json       Free rule pipeline; Pro rules require entitlement
            --replace FROM TO            Free literal replacement
            --number START               Append a padded sequential number
            --recipe FILE.json           Load a Pro preset
            --csv FILE.csv               Two columns: source,new name; includes header
            --execute                    Preview then ask for terminal confirmation
            --json                       Emit machine-readable preview only
            --undo TRANSACTION-UUID      Preview an undo using the shared journal
            Exit 0: preview/success; 1: error; 2: excluded/partial; 3: cancelled.
            """); return
        }
        var pipeline = RulePipeline(), paths: [RawPath] = [], recursive = true, execute = false, json = false, access = try await UnconfiguredEntitlementProvider().verifiedEntitlement().access(), undoID: UUID?
        func take() throws -> String { guard !args.isEmpty else { throw RuleFailure.invalid }; return args.removeFirst() }
        while !args.isEmpty {
            let arg = args.removeFirst()
            switch arg {
            case "--nfd": pipeline.target = .nfd
            case "--keep-form": pipeline.target = .unchanged
            case "--no-recurse": recursive = false
            case "--execute": execute = true
            case "--json": json = true
            case "--prefix", "--suffix", "--number":
                let value = try take(); var rule = RenameRule(arg == "--prefix" ? .prefix : arg == "--suffix" ? .suffix : .numbering)
                if arg == "--number" { guard let number = Int(value) else { throw RuleFailure.invalid }; rule.start = number; rule.text = "_" } else { rule.text = value }
                pipeline.rules.append(rule)
            case "--upper", "--lower", "--title", "--spaces":
                let kind: RuleKind = arg == "--upper" ? .uppercase : arg == "--lower" ? .lowercase : arg == "--title" ? .titlecase : .spaces
                pipeline.rules.append(RenameRule(kind))
            case "--name", "--extension":
                var rule = RenameRule(.setName); rule.text = try take(); if arg == "--extension" { rule.scope = .fileExtension }; pipeline.rules.append(rule)
            case "--insert", "--remove-first", "--remove-last", "--keep-first", "--keep-last":
                guard let position = Int(try take()) else { throw RuleFailure.invalid }
                let kind: RuleKind = arg == "--insert" ? .insert : arg == "--remove-first" ? .removeFirst : arg == "--remove-last" ? .removeLast : arg == "--keep-first" ? .keepFirst : .keepLast
                var rule = RenameRule(kind); rule.position = position; if arg == "--insert" { rule.text = try take() }; pipeline.rules.append(rule)
            case "--rules-json": pipeline = try JSONDecoder().decode(RulePipeline.self, from: boundedRead(URL(fileURLWithPath: take())))
            case "--replace": var rule = RenameRule(.replace); rule.text = try take(); rule.replacement = try take(); pipeline.rules.append(rule)
            case "--recipe":
                let url = URL(fileURLWithPath: try take()); let data = try boundedRead(url)
                pipeline = try JSONDecoder().decode(Recipe.self, from: data).pipeline
                // Named preset execution is Pro even when it contains only free rules.
                #if DEBUG
                guard CommandLine.arguments.contains("--development-pro") else { throw RuleFailure.proRequired }
                #else
                throw RuleFailure.proRequired
                #endif
            case "--csv":
                let rows = try DelimitedText.parse(boundedRead(URL(fileURLWithPath: take())))
                pipeline.mapping = NameMapping(rows: try rows.dropFirst().map { row in guard row.count == 2 else { throw RuleFailure.invalid }; return .init(source: row[0], destination: row[1]) })
            case "--undo": guard let id = UUID(uuidString: try take()) else { throw RuleFailure.invalid }; undoID = id
            #if DEBUG
            case "--development-pro": access = .pro
            #endif
            default:
                guard !arg.hasPrefix("--"), arg.hasPrefix("/"), !arg.utf8.contains(0) else { throw RuleFailure.invalid }
                // "/folder/" must name the folder itself, not an entry called "folder" inside it.
                var path = arg; while path.count > 1, path.hasSuffix("/") { path.removeLast() }
                paths.append(RawPath(path))
            }
        }
        guard !(json && execute) else { throw RuleFailure.invalid }
        var support = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0].appendingPathComponent("Moongchi/NameFix/History")
        #if DEBUG
        if let fixtureRoot = ProcessInfo.processInfo.environment["NAMEFIX_TEST_SUPPORT"] { support = URL(fileURLWithPath: fixtureRoot).appendingPathComponent("History") }
        #endif
        let token = CancellationToken()
        signal(SIGINT, SIG_IGN)
        let cancel = DispatchSource.makeSignalSource(signal: SIGINT, queue: .global())
        cancel.setEventHandler { token.cancel() }; cancel.resume(); defer { cancel.cancel() }
        let plan: RenamePlan
        if let undoID { plan = try History.undo(store: JournalStore(root: support), id: undoID, generation: UUID()) }
        else {
            guard !paths.isEmpty else { throw RuleFailure.invalid }
            try pipeline.validate(access: access)
            let scan = Scanner.scan(roots: paths, recursive: recursive, token: token, target: pipeline.target)
            guard !scan.limited, !scan.cancelled else { throw RuleFailure.budget }
            let entries = try await RulePreview.apply(scan.entries, pipeline: pipeline, access: access, token: token)
            plan = try Planning.make(entries: entries, selected: Set(entries.filter { $0.status.fixable }.map(\.id)), generation: UUID())
        }
        if json { let encoder = JSONEncoder(); encoder.outputFormatting = [.prettyPrinted, .sortedKeys]; FileHandle.standardOutput.write(try encoder.encode(plan)); print(""); if plan.excluded > 0 { exit(2) }; return }
        for op in plan.operations { print("\(op.source.display) → \(String(decoding: op.destination, as: UTF8.self))") }
        print("Changes: \(plan.operations.count); excluded: \(plan.excluded)")
        guard execute, !plan.operations.isEmpty else { if plan.excluded > 0 { exit(2) }; return }
        guard isatty(STDIN_FILENO) != 0 else { throw FSError("InteractiveConfirmationRequired") }
        print("Type RENAME to confirm this preview (anything else cancels):", terminator: " ")
        guard readLine() == "RENAME", !token.cancelled else { exit(3) }
        let result = try await TransactionCoordinator(store: JournalStore(root: support)).execute(plan, token: token)
        print("\(result.status): \(result.succeeded) succeeded, \(result.failed) failed; journal \(result.id)")
        if result.status == "Cancelled" { exit(3) }
        if result.failed > 0 || result.status == "RecoveryNeedsReview" { exit(2) }
    }
    static func boundedRead(_ url: URL) throws -> Data {
        let size = try url.resourceValues(forKeys: [.fileSizeKey]).fileSize ?? 0
        guard size <= 32_000_000 else { throw RuleFailure.budget }
        return try Data(contentsOf: url)
    }
}
