import SwiftUI

/// Terminal state after the engine has released the previous guest.
struct StoppedMacView: View {
    let outcome: Int32
    let reason: String
    var start: (() -> Void)? = nil
    let close: () -> Void

    private var title: String {
        switch outcome {
        case Int32(HENGE_VM_OUTCOME_SHUTDOWN.rawValue): return "Mac 已关机"
        case Int32(HENGE_VM_OUTCOME_RESTART.rawValue): return "Mac 请求重启"
        case Int32(HENGE_VM_OUTCOME_HOST_STOP.rawValue): return "Mac 已停止"
        default: return "Mac 意外停止"
        }
    }

    private var detail: String {
        let next = "你可以重新启动这台 Mac，或者返回 Mac 列表。"
        switch outcome {
        case Int32(HENGE_VM_OUTCOME_SHUTDOWN.rawValue), Int32(HENGE_VM_OUTCOME_HOST_STOP.rawValue): return next
        case Int32(HENGE_VM_OUTCOME_RESTART.rawValue): return "这台 Mac 可以重新启动了。"
        default: return "Mac 已停止：\(reason)。" + next
        }
    }

    var body: some View {
        VStack(spacing: 14) {
            Image(systemName: "power").font(.system(size: 30))
            Text(title).font(.headline)
            Text(detail).font(.subheadline).foregroundStyle(.white.opacity(0.7))
                .multilineTextAlignment(.center)
            if let start { Button("启动 Mac", action: start).buttonStyle(.borderedProminent) }
            Button("关闭", action: close).buttonStyle(.bordered)
        }
        .foregroundStyle(.white)
        .padding(24)
        .frame(maxWidth: 360)
        .background(Color(white: 0.10), in: RoundedRectangle(cornerRadius: 22))
        .accessibilityIdentifier("stopped-mac")
    }
}
