// SPDX-License-Identifier: GPL-2.0-or-later
import Foundation

/// The private NSExtension API (ExtensionFoundation) that starts an app
/// extension of Henge's own: the same calls LiveContainer uses to start its
/// LiveProcess.
@objc private protocol NSExtensionClassShim {
    @objc(extensionWithIdentifier:error:)
    func `extension`(withIdentifier identifier: String) throws -> AnyObject
}

@objc private protocol NSExtensionShim {
    @objc(beginExtensionRequestWithInputItems:completion:)
    func beginExtensionRequest(withInputItems items: [Any], completion: @escaping (NSUUID?) -> Void)
    @objc(pidForRequestIdentifier:)
    func pid(forRequestIdentifier identifier: NSUUID) -> Int32
    @objc(setRequestCompletionBlock:)
    func setRequestCompletionBlock(_ block: @escaping (NSUUID?, [Any]?) -> Void)
    @objc(setRequestCancellationBlock:)
    func setRequestCancellationBlock(_ block: @escaping (NSUUID?, NSError?) -> Void)
    @objc(setRequestInterruptionBlock:)
    func setRequestInterruptionBlock(_ block: @escaping (NSUUID?) -> Void)
}

/// Starts the separate helper process (PlugIns/HengeJITHelper.appex) that debugs Henge.
///
/// The helper is found by the bundle identifier it has in this installation,
/// read from its own Info.plist. Sideloaders that sign with the user's own
/// Apple ID (SideStore, AltStore, Plume, Impactor) append the team ID to Henge's
/// identifier and the helper's alike, so that lookup survives them. An
/// ExtensionKit extension point, which the helper used before, is named in
/// files they do not rewrite, and iOS registered none for a renamed Henge
/// ("Failed to add observer").
///
/// One extension request per HengeJITRequest. For `enable` the request lasts
/// until Henge detaches. Log category "jit-helper".
@MainActor
enum HengeBuiltInJIT {
    static let helperFile = "HengeJITHelper.appex"

    /// Requests that have started and not finished, kept alive until they do.
    private static var running: [HelperRequest] = []

    static var unavailableReason: String? {
#if targetEnvironment(simulator)
        return "内置 JIT 只能在真机上使用。"
#else
        guard #available(iOS 26.0, *) else {
            return "内置 JIT 需要 iOS 26 或更新版本。请改用 StikDebug。"
        }
        if getenv("LC_HOME_PATH") != nil {
            return "在 LiveContainer 里无法使用内置 JIT。请改用 StikDebug。"
        }
        return nil
#endif
    }

    static var isAvailable: Bool { unavailableReason == nil }

    /// The helper's bundle identifier in this installation; nil when a sideloader left it out.
    static var helperIdentifier: String? {
        guard let url = Bundle.main.builtInPlugInsURL?.appendingPathComponent(helperFile) else { return nil }
        return Bundle(url: url)?.bundleIdentifier
    }

    static func send(_ request: HengeJITRequest,
                     started: @escaping () -> Void = {},
                     completion: @escaping (Result<HengeJITRequest.Response, Error>) -> Void) {
        func fail(_ code: Int, _ message: String) {
            HengeLog.log("jit-helper", message)
            completion(.failure(HelperRequest.error(code, message)))
        }
        guard unavailableReason == nil else {
            fail(1, unavailableReason ?? "内置 JIT 不可用。")
            return
        }
        guard let identifier = helperIdentifier else {
            fail(2, "本次安装中缺少 Henge 的 JIT 助手。请重新安装 Henge；若签名工具询问是否保留 App 扩展，请保留；或者改用 StikDebug。")
            return
        }
        if NSClassFromString("NSExtension") == nil {
            dlopen("/System/Library/Frameworks/ExtensionFoundation.framework/ExtensionFoundation", RTLD_NOW)
        }
        guard let extensionClass = NSClassFromString("NSExtension") else {
            fail(3, "iOS 没有提供 Henge 的 JIT 助手所需的扩展接口。")
            return
        }
        let factory = unsafeBitCast(extensionClass as AnyObject, to: NSExtensionClassShim.self)
        let found: AnyObject
        do { found = try factory.extension(withIdentifier: identifier) }
        catch {
            fail(2, "Henge's JIT helper (\(identifier)) could not be found: \(error.localizedDescription) "
                  + "Reinstall Henge.")
            return
        }
        guard let data = try? JSONEncoder().encode(request) else {
            fail(4, "无法编码发给 Henge 的 JIT 助手的请求。")
            return
        }
        let helper = HelperRequest(extension: found, operation: request.operation.rawValue,
                                   completion: completion)
        running.append(helper)
        helper.begin(data: data, identifier: identifier, started: started)
    }

    fileprivate static func finished(_ helper: HelperRequest) {
        running.removeAll { $0 === helper }
    }
}

/// One request to the helper, from its start to its one result.
@MainActor
private final class HelperRequest {
    private let shim: NSExtensionShim
    private let `extension`: AnyObject   // the NSExtension, kept alive for the request
    private let operation: String
    private var completion: ((Result<HengeJITRequest.Response, Error>) -> Void)?

    init(extension found: AnyObject, operation: String,
         completion: @escaping (Result<HengeJITRequest.Response, Error>) -> Void) {
        self.extension = found
        self.shim = unsafeBitCast(found, to: NSExtensionShim.self)
        self.operation = operation
        self.completion = completion
    }

    func begin(data: Data, identifier: String, started: @escaping () -> Void) {
        // The blocks can arrive on any queue; everything below runs on the main thread.
        shim.setRequestCompletionBlock { [weak self] _, items in
            let info = (items?.first as? NSExtensionItem)?.userInfo
            let payload = info?[HengeJITRequest.Response.itemKey] as? Data
            DispatchQueue.main.async { MainActor.assumeIsolated { self?.returned(payload) } }
        }
        shim.setRequestCancellationBlock { [weak self] _, error in
            let message = error?.localizedDescription ?? "请求已取消"
            DispatchQueue.main.async { MainActor.assumeIsolated {
                self?.end(.failure(Self.error(5, "Henge 的 JIT 助手已停止：\(message)")))
            } }
        }
        shim.setRequestInterruptionBlock { [weak self] _ in
            DispatchQueue.main.async { MainActor.assumeIsolated {
                self?.end(.failure(Self.error(6, "Henge 的 JIT 助手意外停止，请重试。")))
            } }
        }
        let item = NSExtensionItem()
        item.userInfo = [HengeJITRequest.itemKey: data]
        shim.beginExtensionRequest(withInputItems: [item]) { [weak self] uuid in
            DispatchQueue.main.async { MainActor.assumeIsolated {
                guard let self else { return }
                guard let uuid else {
                    self.end(.failure(Self.error(7, "Henge 的 JIT 助手没有启动。请重新安装 Henge；若签名工具询问是否保留 App 扩展，请保留。")))
                    return
                }
                HengeLog.log("jit-helper", "\(self.operation): started \(identifier) as pid "
                                        + "\(self.shim.pid(forRequestIdentifier: uuid))")
                started()
            } }
        }
    }

    private func returned(_ payload: Data?) {
        guard let payload,
              let response = try? JSONDecoder().decode(HengeJITRequest.Response.self, from: payload) else {
            end(.failure(Self.error(8, "Henge 的 JIT 助手结束了，但没有返回结果。")))
            return
        }
        HengeLog.log("jit-helper", "\(operation): finished success=\(response.success ? 1 : 0)")
        end(.success(response))
    }

    private func end(_ result: Result<HengeJITRequest.Response, Error>) {
        guard let completion else { return }   // the first result counts
        self.completion = nil
        if case .failure(let error) = result {
            HengeLog.log("jit-helper", "\(operation): \(error.localizedDescription)")
        }
        HengeBuiltInJIT.finished(self)
        completion(result)
    }

    nonisolated static func error(_ code: Int, _ message: String) -> NSError {
        NSError(domain: "HengeBuiltInJIT", code: code, userInfo: [NSLocalizedDescriptionKey: message])
    }
}
