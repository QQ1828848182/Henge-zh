import SwiftUI

struct SettingsView: View {
    @ObservedObject private var jit = JITCoordinator.shared
    @AppStorage(JITCoordinator.autoEnableKey) private var jitAtLaunch = false
    @AppStorage(HardwareMouse.speedKey) private var mouseSpeed = 1.0
    @AppStorage(HardwareMouse.reverseKey) private var reverseScrolling = false
    @AppStorage(HardwareMouse.scrollSpeedKey) private var scrollSpeed = 0.3
    @AppStorage(VolumeClicks.inputModeKey) private var inputMode = VolumeClicks.InputMode.touchscreen
    @AppStorage(VolumeClicks.modeKey) private var volumeMode = VolumeClicks.Mode.delayHold
    @AppStorage(VolumeClicks.swapKey) private var swapButtons = false
    @AppStorage(PhysicalMouseButtons.swapKey) private var swapMouseButtons = false
    @AppStorage(EngineTuning.refreshKey) private var refreshRate = 60
    @AppStorage(EngineTuning.fastFlushKey) private var fastFlush = true
    @AppStorage(EngineTuning.wfiSpinKey) private var wfiSpin = false
    @AppStorage(EngineTuning.superblocksKey) private var superblocks = false
    @AppStorage(JITBootstrap.codeCacheKey) private var codeCacheMB = JITBootstrap.defaultCodeCacheMB

    /// The second footer paragraph: how you click, given the selected input mode.
    private var inputDescription: String {
        if inputMode == .touchscreen {
            return "轻点一下是单击。轻点后按住开始拖动。双指快速轻点是右键。"
        }
        switch volumeMode {
        case .delayHold:
            return "延迟长按会先判断你是长按还是点按音量键，代价是每次点击都会拖到约 0.5 秒。"
        case .tapThenDrag:
            return "轻点后拖动同样先判断长按还是点按，但它无论你点还是按都会先发一次单击，点击更短，代价是按住前会先触发一次点击。"
        case .intercept:
            return "会打开摄像头以便正确拦截音量键。这样音量键就像鼠标按键一样工作，但摄像头一直开着，温度会更高。"
        }
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("JIT") {
                    LabeledContent("状态", value: JITBootstrap.ready ? "已开启" : "已关闭")
                    Picker("方式", selection: $jit.method) {
                        ForEach(JITMethod.allCases) { Text($0.title).tag($0) }
                    }
                    Text(jit.method == .automatic ? jit.automaticDescription : "Henge 使用 \(jit.method.title)。")
                        .font(.footnote).foregroundStyle(.secondary)
                    Button("设置 JIT") { jit.showSetup = true }
                    Toggle("打开 Henge 时开启 JIT", isOn: $jitAtLaunch)
                    if jitAtLaunch {
                        Text("LocalDevVPN 没开时，Henge 会先连接它再回来。")
                            .font(.footnote).foregroundStyle(.secondary)
                    }
                    LabeledContent("代码区域", value: "\(JITBootstrap.jitBytes >> 20) MB，每次启动申请一次")
                }
                .listRowBackground(Desk.card)
                Section("内存") {
                    LabeledContent("额外内存", value: Entitlements.increasedMemory ? "已开启" : "已关闭")
                    LabeledContent("Henge 的上限", value: ByteText.string(UInt64(Entitlements.memoryLimitAtLaunch)))
                    LabeledContent("Henge 可用", value: ByteText.string(UInt64(henge_available_memory())))
                    Text(Entitlements.increasedMemory
                         ? "开启 JIT 后，Mac 的内存不计入这个上限。如果 iOS 不允许，就改用可用存储空间。"
                         : "本次安装没有用「提高内存上限」权限签名。请改用带该权限的证书重新安装 Henge。如果重装会覆盖 App 数据，请先导出你的 Mac。")
                        .font(.footnote).foregroundStyle(.secondary)
                }
                .listRowBackground(Desk.card)
                if Device.isPad {
                    Section("鼠标与触控板") {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("指针速度")
                            Slider(value: $mouseSpeed, in: 0.5...3)
                        }
                        Toggle("反转滚动方向", isOn: $reverseScrolling)
                        VStack(alignment: .leading, spacing: 4) {
                            Text("滚动速度")
                            Slider(value: $scrollSpeed, in: 0.1...1.5)
                        }
                        Toggle("交换实体鼠标的右键与中键", isOn: $swapMouseButtons)
                        Text("只有当你的实体鼠标右键和中键在 Mac 里反了才需要打开。触控操作不受影响。重启 Mac 会话后生效。")
                            .font(.footnote).foregroundStyle(.secondary)
                        Text("妙控键盘或蓝牙鼠标可以直接操作 Mac 的指针。指针速度的更改在下次启动 Mac 时生效，滚动速度的更改立即生效。")
                            .font(.footnote).foregroundStyle(.secondary)
                    }
                    .listRowBackground(Desk.card)
                }
                if !Device.isPad {
                    Section("触控板") {
                        Picker("输入方式", selection: $inputMode) {
                            Text("触屏").tag(VolumeClicks.InputMode.touchscreen)
                            Text("音量键").tag(VolumeClicks.InputMode.volumeButtons)
                        }
                        .pickerStyle(.menu)
                        if inputMode == .volumeButtons {
                            Picker("按键模式", selection: $volumeMode) {
                                Text("延迟长按").tag(VolumeClicks.Mode.delayHold)
                                Text("轻点后拖动").tag(VolumeClicks.Mode.tapThenDrag)
                                Text("摄像头拦截").tag(VolumeClicks.Mode.intercept)
                            }
                            .pickerStyle(.menu)
                            Toggle("交换按键", isOn: $swapButtons)
                        }
                        Text("Henge 可以模拟妙控板，让你用设备触屏做出原生 macOS 手势。\n\n\(inputDescription)")
                            .font(.footnote).foregroundStyle(.secondary)
                    }
                    .listRowBackground(Desk.card)
                }
                Section("性能") {
                    Picker("Mac 刷新率", selection: $refreshRate) {
                        Text("30 Hz").tag(30)
                        Text("60 Hz").tag(60)
                        Text("120 Hz").tag(120)
                    }
                    .pickerStyle(.segmented)
                    Toggle("更快的磁盘写入", isOn: $fastFlush)
                    Toggle("更快从空闲唤醒", isOn: $wfiSpin)
                    Toggle("超级块（实验性）", isOn: $superblocks)
                    Picker("代码缓存", selection: $codeCacheMB) {
                        Text("1 GB").tag(1024)
                        Text("1.5 GB").tag(1536)
                    }
                    Text("代码缓存越大，清空得越少，但更占内存；空间够时 Henge 会选 1.5 GB。下次打开 Henge 时生效。如果 JIT 开始开不起来，请选 1 GB。")
                        .font(.footnote).foregroundStyle(.secondary)
                    Text("macOS 每次刷新都会绘制一帧：30 Hz 最省模拟 CPU，留给 App 更多算力，代价是动画更卡；60 Hz 更顺滑。更快的磁盘写入只保证顺序、不等完整同步，突然断电可能丢掉最后几次写入。更快唤醒会让空闲 CPU 多盯 50 微秒找活干，略微费电。超级块让翻译后的代码跨越条件分支继续执行。以上更改都在下次启动 Mac 时生效。")
                        .font(.footnote).foregroundStyle(.secondary)
                }
                .listRowBackground(Desk.card)
                Section("日志") {
                    ShareLink(item: HengeLog.logFileURL) { Label("分享 henge.log", systemImage: "square.and.arrow.up") }
                }
                .listRowBackground(Desk.card)
            }
            .scrollContentBackground(.hidden)
            .background(Desk.page)
            .navigationTitle("设置")
        }
    }
}
