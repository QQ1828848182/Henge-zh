import SwiftUI
import UniformTypeIdentifiers

/// Mac apps without macOS (experimental): apps and programs brought in from a .dmg or an .app and run through
/// Henge's translation layer (tl/), inside Henge, with no Mac started. Today that is command-line programs; an app
/// that draws with AppKit, SwiftUI or Mac Catalyst is listed with what it would need.
enum MacAppsFeature {
    static let key = "henge.macApps"
}

struct MacApp: Identifiable, Hashable {
    let url: URL
    let name: String
    let identifier: String
    let minMacOS: String
    let executable: String
    let arm64: Bool
    let intel: Bool
    let kind: Int32
    var id: String { url.path }

    init?(url: URL) {
        var info = HengeTlInfo()
        var err = [CChar](repeating: 0, count: 256)
        guard henge_tl_info(url.path, &info, &err, err.count) == 0 else { return nil }
        self.url = url
        name = withUnsafeBytes(of: info.name) { String(cString: $0.bindMemory(to: CChar.self).baseAddress!) }
        identifier = withUnsafeBytes(of: info.identifier) { String(cString: $0.bindMemory(to: CChar.self).baseAddress!) }
        minMacOS = withUnsafeBytes(of: info.min_macos) { String(cString: $0.bindMemory(to: CChar.self).baseAddress!) }
        executable = withUnsafeBytes(of: info.executable) { String(cString: $0.bindMemory(to: CChar.self).baseAddress!) }
        arm64 = info.arm64 != 0
        intel = info.x86_64 != 0
        kind = info.kind
    }

    var canRun: Bool { kind == Int32(HENGE_TL_PROGRAM.rawValue) }
    /// An AppKit app opens against Henge's own AppKit (experimental: browsers built on Chromium are what it is made for).
    var canOpenWindowed: Bool { kind == Int32(HENGE_TL_APPKIT.rawValue) && arm64 }

    var verdict: (title: String, detail: String) {
        switch UInt32(kind) {
        case HENGE_TL_PROGRAM.rawValue:
            return ("无需 macOS 即可运行（实验性）",
                    "这是一个无窗口程序：Henge 把它加载进自己内部运行，不需要启动 Mac。")
        case HENGE_TL_SWIFTUI.rawValue:
            return ("暂不支持：SwiftUI 应用",
                    "iOS 有它调用的 SwiftUI，但在 Henge 内部把它作为 App 启动还没做完。在 Mac 里可以运行。")
        case HENGE_TL_CATALYST.rawValue:
            return ("暂不支持：Mac Catalyst 应用",
                    "它由 iPad App 的代码构建而成，调用的东西大多在 iOS 上存在，但在 Henge 内部启动还没做完。在 Mac 里可以运行。")
        case HENGE_TL_APPKIT.rawValue:
            return ("实验性：AppKit 应用",
                    "它用 AppKit 绘制窗口，而 iOS 没有 AppKit，Henge 自带了一套。这是为基于 Chromium 的浏览器（Chromium，以及用 Electron 或 CEF 构建的应用）做的，其他应用可能早早退出。")
        default:
            return ("仅 Intel",
                    "它没有 Apple 芯片的代码。有 Rosetta 的 Mac 能跑，Henge 目前还不行。")
        }
    }

    var kindSymbol: String {
        switch UInt32(kind) {
        case HENGE_TL_PROGRAM.rawValue: return "terminal"
        case HENGE_TL_INTEL.rawValue: return "cpu"
        default: return "macwindow"
        }
    }
}

@MainActor
final class MacAppsStore: ObservableObject {
    static let shared = MacAppsStore()
    @Published private(set) var apps: [MacApp] = []
    @Published var busy: String?
    @Published var problem: String?

    static var folder: URL {
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        return docs.appendingPathComponent("Mac 应用", isDirectory: true)
    }

    func reload() {
        let folder = Self.folder
        Task.detached(priority: .userInitiated) {
            try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
            let items = (try? FileManager.default.contentsOfDirectory(at: folder, includingPropertiesForKeys: nil)) ?? []
            let found = items.filter { !$0.lastPathComponent.hasPrefix(".") && $0.pathExtension != "txt" }
                .compactMap(MacApp.init(url:))
                .sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
            await MainActor.run { self.apps = found }
        }
    }

    /// A .dmg (its apps and programs are copied out), an .app, or a lone program.
    func bring(in url: URL) {
        let scoped = url.startAccessingSecurityScopedResource()
        busy = "正在导入 \(url.lastPathComponent)…"
        problem = nil
        let folder = Self.folder
        Task.detached(priority: .userInitiated) {
            defer { if scoped { url.stopAccessingSecurityScopedResource() } }
            try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
            var trouble: String?
            if url.pathExtension.lowercased() == "dmg" {
                var err = [CChar](repeating: 0, count: 512)
                let copied = henge_tl_import_dmg(url.path, folder.path, &err, err.count)
                if copied <= 0 { trouble = String(cString: err) }
                HengeLog.log("macapps", "\(url.lastPathComponent): \(copied) items copied\(copied <= 0 ? " (\(String(cString: err)))" : "")")
            } else {
                let to = folder.appendingPathComponent(url.lastPathComponent)
                try? FileManager.default.removeItem(at: to)
                do { try FileManager.default.copyItem(at: url, to: to) } catch { trouble = error.localizedDescription }
                if trouble == nil, MacApp(url: to) == nil {
                    try? FileManager.default.removeItem(at: to)
                    trouble = "\(url.lastPathComponent) 不是 Mac 应用或程序。"
                }
            }
            let found = trouble
            await MainActor.run {
                self.busy = nil
                self.problem = found
                self.reload()
            }
        }
    }

    func addSamples() {
        guard let samples = Bundle.main.url(forResource: "tl-samples", withExtension: "dmg") else {
            problem = "这个版本没有示例程序。"
            return
        }
        bring(in: samples)
    }

    func delete(_ app: MacApp) {
        try? FileManager.default.removeItem(at: app.url)
        try? FileManager.default.removeItem(at: Self.output(for: app))
        reload()
    }

    /// What a program printed, beside it (visible in Files, for a run that ended Henge).
    static func output(for app: MacApp) -> URL {
        folder.appendingPathComponent("\(app.url.lastPathComponent) output.txt")
    }
}

/// The list: what was brought in, and a way to bring in more.
struct MacAppsView: View {
    @ObservedObject private var store = MacAppsStore.shared
    @Environment(\.dismiss) private var dismiss
    @State private var picking = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 0) {
                    Text("Mac 应用和程序在这里通过 Henge 自带的翻译层运行，不必启动一台 Mac。目前无窗口的程序可以运行，有窗口的应用还在开发中。属实验性功能。")
                        .font(.system(size: 14)).foregroundStyle(Desk.dim)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 4).padding(.bottom, 12)
                    if let busy = store.busy { NoticeRow(symbol: "arrow.down.circle.fill", text: busy) }
                    if let problem = store.problem { NoticeRow(symbol: "exclamationmark.triangle.fill", text: problem, tint: Desk.warn) }
                    if store.apps.isEmpty && store.busy == nil {
                        VStack(spacing: 10) {
                            Image(systemName: "shippingbox").font(.system(size: 34)).foregroundStyle(Desk.faint)
                            Text("这里还是空的").font(.system(size: 17, weight: .semibold))
                            Text("从「文件」里导入 .dmg 或 .app，或者试试 Henge 自带的示例程序。")
                                .font(.system(size: 14)).foregroundStyle(Desk.dim).multilineTextAlignment(.center)
                        }
                        .padding(28).frame(maxWidth: .infinity).deskCard()
                    }
                    ForEach(store.apps) { app in
                        NavigationLink(value: app) { MacAppRow(app: app) }.buttonStyle(.plain).padding(.bottom, 10)
                    }
                    Button("添加示例程序") { store.addSamples() }
                        .buttonStyle(DeskButtonStyle()).padding(.top, 8)
                }
                .padding(.horizontal, 16).padding(.vertical, 12).deskColumn()
            }
            .background(Desk.page)
            .navigationTitle("Mac 应用")
            .navigationDestination(for: MacApp.self) { MacAppRunView(app: $0) }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("完成") { dismiss() } }
                ToolbarItem(placement: .primaryAction) {
                    Button { picking = true } label: { Image(systemName: "plus") }.accessibilityLabel("导入 Mac 应用")
                }
            }
            .fileImporter(isPresented: $picking, allowedContentTypes: [.diskImage, .applicationBundle, .folder, .unixExecutable, .data]) { result in
                if case let .success(url) = result { store.bring(in: url) }
            }
            .onAppear { store.reload() }
        }
    }
}

private struct MacAppRow: View {
    let app: MacApp
    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: app.kindSymbol).font(.system(size: 22)).foregroundStyle(app.canRun ? Desk.accent : Desk.faint).frame(width: 34)
            VStack(alignment: .leading, spacing: 3) {
                Text(app.name).font(.system(size: 17, weight: .semibold)).foregroundStyle(Desk.text).lineLimit(1)
                Text(app.verdict.title).font(.system(size: 13)).foregroundStyle(app.canRun ? Desk.good : Desk.dim).lineLimit(1)
            }
            Spacer()
            Image(systemName: "chevron.right").font(.system(size: 13, weight: .semibold)).foregroundStyle(Desk.faint)
        }
        .padding(16).deskCard()
    }
}

/// One app or program: what it is, and Run for a program, with what it printed.
struct MacAppRunView: View {
    let app: MacApp
    @ObservedObject private var store = MacAppsStore.shared
    @Environment(\.dismiss) private var dismiss
    @State private var running = false
    @State private var output = ""
    @State private var result: String?
    @State private var confirmDelete = false
    @State private var showScreen = false

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                VStack(alignment: .leading, spacing: 8) {
                    Text(app.verdict.title).font(.system(size: 17, weight: .semibold)).foregroundStyle(app.canRun ? Desk.good : Desk.text)
                    Text(app.verdict.detail).font(.system(size: 14)).foregroundStyle(Desk.dim)
                }
                .frame(maxWidth: .infinity, alignment: .leading).padding(17).deskCard()

                DeskHeading("关于")
                VStack(alignment: .leading, spacing: 6) {
                    if !app.identifier.isEmpty { LabeledContent("标识符", value: app.identifier) }
                    LabeledContent("架构", value: [app.arm64 ? "Apple 芯片" : nil, app.intel ? "Intel" : nil].compactMap { $0 }.joined(separator: " and "))
                    if !app.minMacOS.isEmpty { LabeledContent("需要 macOS", value: app.minMacOS + " 或更高版本") }
                }
                .font(.system(size: 15)).padding(17).deskCard()

                if app.canRun {
                    Button(running ? "运行中…" : "运行") { run() }
                        .buttonStyle(DeskButtonStyle()).disabled(running || (result == nil && henge_tl_ran_program() != 0)).padding(.top, 16)
                    Text("程序在 Henge 内部运行，每次启动只能跑一个。跑过一个之后，请退出 Henge 再打开，才能跑下一个或启动 Mac。")
                        .font(.system(size: 13)).foregroundStyle(Desk.dim).frame(maxWidth: .infinity, alignment: .leading).padding(.top, 8)
                    if result != nil || !output.isEmpty {
                        DeskHeading("输出")
                        VStack(alignment: .leading, spacing: 8) {
                            Text(output.isEmpty ? "（没有输出）" : output)
                                .font(.system(size: 12, design: .monospaced)).textSelection(.enabled)
                                .frame(maxWidth: .infinity, alignment: .leading)
                            if let result { Text(result).font(.system(size: 13, weight: .semibold)).foregroundStyle(Desk.dim) }
                        }
                        .padding(17).deskCard()
                    }
                }
                if app.canOpenWindowed {
                    Button("打开（实验性）") { showScreen = true }
                        .buttonStyle(DeskButtonStyle()).disabled(henge_tl_ran_program() != 0).padding(.top, 16)
                    Text("它在 Henge 内部运行，每次启动只跑一个 App，不需要 Mac。轻点是单击，单指滚动，双指拖动，长按是右键；点键盘按钮可以呼出键盘。退出 Henge（上滑关掉）即可停止。")
                        .font(.system(size: 13)).foregroundStyle(Desk.dim).frame(maxWidth: .infinity, alignment: .leading).padding(.top, 8)
                }
                Button("删除", role: .destructive) { confirmDelete = true }.padding(.top, 24)
            }
            .padding(.horizontal, 16).padding(.vertical, 12).deskColumn()
        }
        .background(Desk.page)
        .navigationTitle(app.name)
        .fullScreenCover(isPresented: $showScreen) { MacAppScreen(app: app) }
        .confirmationDialog("删除 \(app.name)？", isPresented: $confirmDelete, titleVisibility: .visible) {
            Button("删除", role: .destructive) { store.delete(app); dismiss() }
        }
    }

    private func run() {
        running = true
        result = nil
        output = ""
        let exe = app.executable, out = MacAppsStore.output(for: app)
        HengeLog.log("macapps", "running \(app.name) (\(exe))")
        Task.detached(priority: .userInitiated) {
            var err = [CChar](repeating: 0, count: 512)
            let rc = henge_tl_run(exe, out.path, &err, err.count)
            let text = (try? String(contentsOf: out, encoding: .utf8)) ?? ""
            let why = String(cString: err)
            HengeLog.log("macapps", "\(exe) returned \(rc)\(why.isEmpty ? "" : ": \(why)")")
            await MainActor.run {
                output = String(text.suffix(20000))
                result = rc == -1 && !why.isEmpty ? "无法运行：\(why)" : "已结束，退出码 \(rc)。"
                running = false
            }
        }
    }
}
