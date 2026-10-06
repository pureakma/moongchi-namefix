import SwiftUI
import AppKit

/// Gradient tile with a white symbol: the colourful icon of the introduction, the help and the developer card.
struct ColorTile: View {
    let symbol: String
    let colors: [Color]
    var size: CGFloat = 40
    var body: some View {
        RoundedRectangle(cornerRadius: size * 0.28, style: .continuous)
            .fill(LinearGradient(colors: colors, startPoint: .topLeading, endPoint: .bottomTrailing))
            .frame(width: size, height: size)
            .overlay { Image(systemName: symbol).font(.system(size: size * 0.46, weight: .semibold)).foregroundStyle(.white) }
            .shadow(color: (colors.last ?? .clear).opacity(0.28), radius: size * 0.12, y: size * 0.06)
            .accessibilityHidden(true)
    }
}
enum Tint {
    static let blue = [Color(red: 0.25, green: 0.66, blue: 1.0), Color(red: 0.10, green: 0.40, blue: 0.96)]
    static let purple = [Color(red: 0.72, green: 0.52, blue: 1.0), Color(red: 0.45, green: 0.30, blue: 0.94)]
    static let green = [Color(red: 0.36, green: 0.84, blue: 0.56), Color(red: 0.10, green: 0.62, blue: 0.42)]
    static let orange = [Color(red: 1.0, green: 0.72, blue: 0.30), Color(red: 0.96, green: 0.47, blue: 0.16)]
    static let pink = [Color(red: 1.0, green: 0.52, blue: 0.66), Color(red: 0.92, green: 0.26, blue: 0.48)]
    static let teal = [Color(red: 0.32, green: 0.82, blue: 0.86), Color(red: 0.08, green: 0.58, blue: 0.70)]
    static let slate = [Color(red: 0.58, green: 0.63, blue: 0.72), Color(red: 0.36, green: 0.41, blue: 0.52)]
}

/// First-run introduction: what the app is good at, in four pages. It always uses its own light
/// colours, whatever theme the app is in, and comes back from Settings or the Help menu.
struct OnboardingView: View {
    @ObservedObject var model: AppModel
    @State private var page: Int
    @State private var hide: Bool
    static let hiddenKey = "NameFix.Onboarding.Hidden"
    static let pageCount = 4
    init(model: AppModel, page: Int = 0) {
        self.model = model
        _page = State(initialValue: page)
        _hide = State(initialValue: UserDefaults.standard.bool(forKey: Self.hiddenKey))
    }
    private let ink = Color(red: 0.11, green: 0.13, blue: 0.19), soft = Color(red: 0.38, green: 0.42, blue: 0.50)
    private let line = Color(red: 0.87, green: 0.89, blue: 0.93)
    private var colors: [Color] { [Tint.blue, Tint.green, Tint.purple, Tint.orange][page] }
    private var pointSymbols: [String] {
        [["text.badge.checkmark", "square.and.arrow.down.on.square", "folder.badge.plus"],
         ["doc.badge.ellipsis", "exclamationmark.shield", "arrow.uturn.backward"],
         ["square.stack.3d.up", "bookmark", "tablecells"],
         ["gift", "wifi.slash", "folder.badge.gearshape"]][page]
    }
    var body: some View {
        VStack(spacing: 0) {
            hero
            VStack(alignment: .leading, spacing: 10) {
                Text(model.t("OnbTitle\(page + 1)")).font(L10n.font(model.settings.language, size: 24, weight: .bold)).foregroundStyle(ink)
                    .fixedSize(horizontal: false, vertical: true).accessibilityAddTraits(.isHeader)
                Text(model.t("OnbBody\(page + 1)")).font(L10n.font(model.settings.language, size: 14, weight: .regular)).foregroundStyle(soft)
                    .fixedSize(horizontal: false, vertical: true)
                VStack(alignment: .leading, spacing: 9) {
                    ForEach(0..<3, id: \.self) { index in
                        HStack(spacing: 10) {
                            ColorTile(symbol: pointSymbols[index], colors: colors, size: 26)
                            Text(model.t("OnbPoint\(page + 1)\(["A", "B", "C"][index])")).foregroundStyle(ink).fixedSize(horizontal: false, vertical: true)
                        }
                    }
                }.padding(.top, 6)
            }
            .padding(.horizontal, 34).padding(.top, 22).frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            Rectangle().fill(line).frame(height: 1)
            controls.padding(.horizontal, 22).padding(.vertical, 14)
        }
        .font(L10n.font(model.settings.language)).background(Color.white)
        .environment(\.colorScheme, .light)
        .accessibilityElement(children: .contain).accessibilityIdentifier("onboarding")
    }

    // MARK: Hero — one picture per page

    private var hero: some View {
        ZStack {
            LinearGradient(colors: [colors[0].opacity(0.22), colors[1].opacity(0.10)], startPoint: .topLeading, endPoint: .bottomTrailing)
            Circle().fill(colors[0].opacity(0.18)).frame(width: 260, height: 260).offset(x: -210, y: -70)
            Circle().fill(colors[1].opacity(0.12)).frame(width: 200, height: 200).offset(x: 230, y: 80)
            // The pictures only illustrate the text below them.
            Group {
                switch page {
                case 0: repairPicture
                case 1: tiles(main: "checkmark.shield.fill", left: ("eye.fill", Tint.teal), right: ("arrow.uturn.backward", Tint.blue))
                case 2: batchPicture
                default: tiles(main: "gift.fill", left: ("lock.fill", Tint.teal), right: ("folder.badge.gearshape", Tint.pink))
                }
            }.accessibilityHidden(true)
        }
        .frame(height: 214).frame(maxWidth: .infinity).clipped()
        .overlay(alignment: .topTrailing) {
            Button { close() } label: { Image(systemName: "xmark").font(.system(size: 11, weight: .bold)).foregroundStyle(soft).frame(width: 26, height: 26).background(Color.white.opacity(0.85), in: Circle()) }
                .buttonStyle(.plain).keyboardShortcut(.cancelAction).padding(12).help(model.t("Close")).accessibilityLabel(model.t("Close"))
        }
    }
    private func tiles(main: String, left: (String, [Color]), right: (String, [Color])) -> some View {
        HStack(spacing: 22) {
            ColorTile(symbol: left.0, colors: left.1, size: 58).rotationEffect(.degrees(-8)).offset(y: 14)
            ColorTile(symbol: main, colors: colors, size: 104)
            ColorTile(symbol: right.0, colors: right.1, size: 58).rotationEffect(.degrees(8)).offset(y: 14)
        }
    }
    /// The app icon beside the three kinds of names it repairs.
    private var repairPicture: some View {
        HStack(spacing: 26) {
            Image(nsImage: NSApp.applicationIconImage).resizable().interpolation(.high).frame(width: 112, height: 112).accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 8) {
                nameRow("ㅎㅏㄴㄱㅡㄹ.hwp", "한글.hwp")
                nameRow("か\u{309B}いと\u{309B}.pdf", "がいど.pdf")
                nameRow("cafe\u{00B4}.txt", "café.txt")
            }
        }
    }
    private var batchPicture: some View {
        VStack(alignment: .leading, spacing: 8) {
            nameRow("IMG_0012.jpg", "Trip_001.jpg")
            nameRow("IMG_0013.jpg", "Trip_002.jpg")
            nameRow("IMG_0014.jpg", "Trip_003.jpg")
        }
    }
    private func nameRow(_ before: String, _ after: String) -> some View {
        HStack(spacing: 10) {
            Text(before).foregroundStyle(soft).frame(width: 128, alignment: .leading)
            Image(systemName: "arrow.right").font(.system(size: 11, weight: .bold)).foregroundStyle(colors[1])
            Text(after).fontWeight(.semibold).foregroundStyle(ink).frame(width: 104, alignment: .leading)
            Image(systemName: "checkmark.circle.fill").foregroundStyle(Tint.green[1])
        }
        .font(.system(size: 13)).lineLimit(1).padding(.horizontal, 12).padding(.vertical, 7)
        .background(Color.white, in: RoundedRectangle(cornerRadius: 9, style: .continuous))
        .shadow(color: Color.black.opacity(0.07), radius: 5, y: 2)
    }

    // MARK: Controls

    private var controls: some View {
        HStack(spacing: 12) {
            Button { hide.toggle() } label: {
                HStack(spacing: 6) {
                    Image(systemName: hide ? "checkmark.square.fill" : "square").font(.system(size: 15)).foregroundStyle(hide ? Tint.blue[1] : soft)
                    Text(model.t("OnbHide")).foregroundStyle(soft)
                }.contentShape(Rectangle())
            }.buttonStyle(.plain).accessibilityAddTraits(hide ? .isSelected : []).accessibilityIdentifier("onboardingHide")
            Spacer(minLength: 8)
            HStack(spacing: 6) {
                ForEach(0..<Self.pageCount, id: \.self) { index in
                    Capsule().fill(index == page ? colors[1] : line).frame(width: index == page ? 18 : 7, height: 7)
                }
            }.accessibilityElement(children: .ignore).accessibilityLabel("\(page + 1) / \(Self.pageCount)")
            Spacer(minLength: 8)
            if page > 0 {
                Button(model.t("OnbBack")) { page -= 1 }.buttonStyle(IntroButton(fill: Color(red: 0.94, green: 0.95, blue: 0.97), text: ink))
            }
            Button(model.t(page == Self.pageCount - 1 ? "OnbStart" : "OnbNext")) { if page == Self.pageCount - 1 { close() } else { page += 1 } }
                .buttonStyle(IntroButton(fill: colors[1], text: .white)).keyboardShortcut(.defaultAction).accessibilityIdentifier("onboardingNext")
        }
    }
    private func close() {
        UserDefaults.standard.set(hide, forKey: Self.hiddenKey)
        model.sheet = nil; model.flushQueued()
    }
}

/// Buttons with their own colours, so the introduction looks the same in a dark window.
private struct IntroButton: ButtonStyle {
    let fill: Color, text: Color
    func makeBody(configuration: Configuration) -> some View {
        configuration.label.fontWeight(.semibold).foregroundStyle(text).padding(.horizontal, 18).padding(.vertical, 8)
            .background(fill.opacity(configuration.isPressed ? 0.8 : 1), in: RoundedRectangle(cornerRadius: 9, style: .continuous))
    }
}

/// "How to use": three steps, the topics as cards with colour icons, and the shortcuts.
struct HelpView: View {
    @ObservedObject var model: AppModel
    let palette: Palette
    private let shortcuts: [(String, String)] = [
        ("⌘O", "AddFiles"), ("⇧⌘O", "AddFolders"), ("⌘R", "Rescan"), ("⌘F", "Search"), ("⌘A", "SelectVisible"),
        ("⌘1", "RestoreNames"), ("⌘2", "BatchWorkspace"), ("⇧⌘E", "ExportShort"), ("⇧⌘W", "ResetInputs"), ("⌘,", "Settings")
    ]
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                HStack(alignment: .center, spacing: 14) {
                    Image(nsImage: NSApp.applicationIconImage).resizable().interpolation(.high).frame(width: 56, height: 56).accessibilityHidden(true)
                    VStack(alignment: .leading, spacing: 4) {
                        Text(model.t("EmptyTitle")).font(.title3).fontWeight(.semibold)
                        Text(model.t("EmptyDescription")).foregroundStyle(palette.secondary).fixedSize(horizontal: false, vertical: true)
                    }
                }
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 180), spacing: 10, alignment: .top)], spacing: 10) { steps }
                topic("HelpSeparation", "text.badge.checkmark", Tint.purple, ["NormalizationNotice", "HelpAuto"])
                topic("SafetyTitle", "checkmark.shield.fill", Tint.green, ["FilesystemHelp", "ConflictHelp", "ConcurrentChangeHelp", "HelpRecovery"])
                topic("BatchWorkspace", "pencil.line", Tint.orange, ["HelpBatch"])
                card {
                    heading("HelpShortcuts", "keyboard", Tint.slate)
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 250), spacing: 12, alignment: .leading)], alignment: .leading, spacing: 8) {
                        ForEach(shortcuts, id: \.0) { key, label in
                            HStack(spacing: 10) {
                                Text(key).font(.system(size: 12, weight: .semibold, design: .rounded)).frame(minWidth: 44).padding(.vertical, 3).padding(.horizontal, 4)
                                    .background(palette.control, in: RoundedRectangle(cornerRadius: 6)).overlay(RoundedRectangle(cornerRadius: 6).stroke(palette.border, lineWidth: 1))
                                Text(model.t(label)).lineLimit(1)
                                Spacer(minLength: 0)
                            }.accessibilityElement(children: .combine)
                        }
                    }
                }
                HStack(spacing: 8) {
                    Image(systemName: "lock.fill").foregroundStyle(palette.secondary).accessibilityHidden(true)
                    Text(model.t("LocalOnly")).foregroundStyle(palette.secondary)
                    Spacer(minLength: 8)
                    Button(model.t("ShowIntro")) { model.sheet = "onboarding" }
                }
            }.frame(maxWidth: .infinity, alignment: .leading)
        }
    }
    @ViewBuilder private var steps: some View {
        step(1, "HelpStepAdd", "HelpStepAddDetail", Tint.blue)
        step(2, "HelpStepCheck", "HelpStepCheckDetail", Tint.purple)
        step(3, "HelpStepRename", "HelpStepRenameDetail", Tint.green)
    }
    private func step(_ number: Int, _ title: String, _ detail: String, _ colors: [Color]) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(String(number)).font(.system(size: 14, weight: .bold, design: .rounded)).foregroundStyle(.white).frame(width: 26, height: 26)
                .background(LinearGradient(colors: colors, startPoint: .topLeading, endPoint: .bottomTrailing), in: Circle()).accessibilityHidden(true)
            Text(model.t(title)).fontWeight(.semibold).fixedSize(horizontal: false, vertical: true)
            Text(model.t(detail)).font(.callout).foregroundStyle(palette.secondary).fixedSize(horizontal: false, vertical: true)
        }
        .padding(14).frame(maxWidth: .infinity, minHeight: 132, alignment: .topLeading)
        .background(palette.surface, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).stroke(palette.border.opacity(0.7), lineWidth: 0.5))
        .accessibilityElement(children: .combine)
    }
    private func topic(_ title: String, _ symbol: String, _ colors: [Color], _ texts: [String]) -> some View {
        card {
            heading(title, symbol, colors)
            ForEach(texts, id: \.self) { key in
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Circle().fill(colors[1]).frame(width: 5, height: 5).offset(y: -3).accessibilityHidden(true)
                    Text(model.t(key)).fixedSize(horizontal: false, vertical: true)
                }
            }
        }
    }
    private func heading(_ title: String, _ symbol: String, _ colors: [Color]) -> some View {
        HStack(spacing: 10) {
            ColorTile(symbol: symbol, colors: colors, size: 30)
            Text(model.t(title)).font(.headline).accessibilityAddTraits(.isHeader)
        }
    }
    private func card<Content: View>(@ViewBuilder _ content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 10, content: content)
            .padding(16).frame(maxWidth: .infinity, alignment: .leading)
            .background(palette.surface, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).stroke(palette.border.opacity(0.7), lineWidth: 0.5))
    }
}

/// Last card of Settings: the app, who makes it, and where to go for help.
struct DeveloperCard: View {
    @ObservedObject var model: AppModel
    let palette: Palette
    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .center, spacing: 16) {
                Image(nsImage: NSApp.applicationIconImage).resizable().interpolation(.high).frame(width: 68, height: 68).accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 4) {
                    Text("Moongchi NameFix").font(.title3).fontWeight(.semibold)
                    Text(model.t("VersionLine", AppInfo.version, AppInfo.build)).font(.callout).foregroundStyle(palette.secondary)
                    Text(model.t("LocalOnly")).font(.caption).foregroundStyle(palette.secondary).fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 0)
            }
            Rectangle().fill(palette.border.opacity(0.7)).frame(height: 1).accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 10) {
                row("person.fill", Tint.blue, "DeveloperLabel") { Text(AppInfo.developer).fontWeight(.medium) }
                if let website = AppInfo.website {
                    row("globe", Tint.teal, "Website") { link(website.host ?? website.absoluteString, website) }
                }
                if let support = AppInfo.support {
                    row("ladybug.fill", Tint.pink, "ContactSupport") { link(support.scheme == "mailto" ? String(support.absoluteString.dropFirst(7)) : (support.host ?? support.absoluteString), support) }
                }
            }
            ViewThatFits(in: .horizontal) {
                HStack(spacing: 8) { actions }
                VStack(alignment: .leading, spacing: 8) { actions }
            }
        }
        .padding(18).frame(maxWidth: .infinity, alignment: .leading)
        .background(LinearGradient(colors: [Tint.blue[0].opacity(0.14), Tint.purple[0].opacity(0.10), palette.surface.opacity(0.6)], startPoint: .topLeading, endPoint: .bottomTrailing), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .background(palette.surface, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).stroke(palette.border.opacity(0.8), lineWidth: 0.5))
        .accessibilityElement(children: .contain).accessibilityIdentifier("developerCard")
    }
    @ViewBuilder private var actions: some View {
        Button { model.sheet = "help" } label: { Label(model.t("HelpTitle"), systemImage: "questionmark.circle") }
        Button { model.sheet = "onboarding" } label: { Label(model.t("ShowIntro"), systemImage: "sparkles") }.accessibilityIdentifier("showIntro")
        Button { model.sheet = "about" } label: { Label(model.t("License"), systemImage: "doc.text") }
    }
    private func row<Value: View>(_ symbol: String, _ colors: [Color], _ label: String, @ViewBuilder value: () -> Value) -> some View {
        HStack(spacing: 10) {
            ColorTile(symbol: symbol, colors: colors, size: 24)
            Text(model.t(label)).foregroundStyle(palette.secondary)
            Spacer(minLength: 8)
            value()
        }
    }
    private func link(_ title: String, _ url: URL) -> some View {
        Button { NSWorkspace.shared.open(url) } label: { HStack(spacing: 4) { Text(title); Image(systemName: "arrow.up.right").font(.caption) } }
            .buttonStyle(.link).help(url.absoluteString)
    }
}
