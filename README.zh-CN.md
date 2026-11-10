<p align="center">
  <img src="docs/icon.png" width="120" height="120" alt="Henge">
</p>

<h1 align="center">Henge</h1>

<p align="center">把 macOS 装进你的 iPhone 和 iPad。</p>

<p align="center">
  <a href="#安装">安装</a>
  ·
  <a href="docs/architecture.md">工作原理</a>
  ·
  <a href="https://itslevii.dev">网站</a>
  ·
  <a href="https://github.com/Leviidev/Henge/releases">发行版</a>
  ·
  <a href="README.md">English</a>
</p>

<p align="center">
  <a href="https://github.com/Leviidev/Henge/releases"><img src="https://img.shields.io/github/downloads/Leviidev/Henge/total?style=flat-square&color=2E6BFF&labelColor=111111" alt="Downloads"></a>
  <a href="LICENSE"><img src="https://img.shields.io/github/license/Leviidev/Henge?style=flat-square&color=2E6BFF&labelColor=111111" alt="GPL-2.0-or-later"></a>
</p>

下载 macOS，把它装到设备上，然后就可以用了。

- **自研模拟器** — iOS 不给 App 任何 hypervisor，所以 Henge 用自己的 JIT 来跑 Mac 的 arm64 代码，并自带 MMU 和各种设备。它不用 QEMU，也不用 Virtualization.framework。
- **直接装在设备上** — Henge 会下载 Apple 的恢复镜像，然后像 Mac 那样把它恢复出来。不需要另一台 Mac，也不会解密或修改任何东西。
- **图形** — macOS 通过一块虚拟 GPU 绘制，Henge 用 Metal 重放它的命令。Safari 以及 Discord 这类 Electron 应用都能正常绘制。
- **触摸** — 屏幕就是触控板：按住拖动，双指滚动。键盘上方还有 Esc、Tab、Control、Option 和 Command。
- **键盘和鼠标** — 在 iPad 上，妙控键盘或蓝牙键盘鼠标可以直接操作这台 Mac。
- **外接显示器（iOS 27 及以上）** — 在 Mac 会话中，用支持视频的 USB-C 线或 USB-C/HDMI 扩展坞接上显示器，模式会自动切换：显示器显示这台 Mac，iPhone 或 iPad 继续当触控板和键盘。断开后画面回到设备上。访客机的现有分辨率保持不变；较旧的 iOS 版本仍然使用系统镜像。USB-C 视频已在运行 iOS 27 的 iPhone 17 Pro 上由用户确认可用（开发版本 0.1/2）。
- **共享** — macOS 与设备之间可以互相复制粘贴，还有一个共享文件夹，在「文件」里和 Mac 上都能看到。
- **贴合屏幕** — 在 iPad 上，新建的 Mac 会得到一块和 iPad 屏幕同样形状的屏幕，所以没有黑边。

在 iPhone 17 Pro 上，macOS 大约 15 秒就能到登录界面。Discord 能装上，大约 15 秒打开，登录并发送消息。

## 安装

用 SideStore 或 AltStore 侧载 [发行版](https://github.com/Leviidev/Henge/releases) 里的 `Henge.ipa`，或用 TrollStore、TrollStore Lite 安装 `Henge.tipa`。想在 SideStore 或 AltStore 里收到更新，可以添加 Henge 的源 `https://raw.githubusercontent.com/Leviidev/Henge/main/repo.json`；要 Leviidev 所有 App 的源，用 `https://itslevii.dev/repo.json`。需要 iOS 或 iPadOS 17 或更高版本，芯片为 A14 或 M1 及以上。目前只在 iPhone 17 Pro 上测试过：iPad 支持是新加的，还没有在真 iPad 上跑过。

- **需要 JIT**：StikDebug、TrollStore（只支持到 iOS 17.0）、TrollStore Lite（需要越狱）、越狱本身，或者 Henge 自带的 StikJIT 助手（iOS 26 及以上）。
- **存储**：安装 macOS Sequoia 大约需要 43 GB 可用空间。其中 17 GB 是下载的镜像，装完可以删掉；另外 26 GB 给这台 Mac。
- **内存**：一台 Mac 可以拿到 4、6 或 8 GB。如果你的证书带「提高内存上限」权限，就用该权限给 Henge 签名。

然后打开「安装」标签页，选择 macOS Sequoia 15.6.1，并保持 Henge 打开、设备插着电。界面上也提供 Tahoe 26.6.2 和 macOS 27.2。Sonoma 14.6.1 和 Ventura 13.6 的下载包更小（14.1 与 12.3 GB），适合存储空间紧张的设备：它们能安装、能完成设置，并且能在 Henge 的 iPhone 图形路径上跑 Safari（目前是在 Mac 上测的）。暂不提供 Monterey：它能装上，但桌面始终不出现。

想用 Henge，请安装[最新发行版](https://github.com/Leviidev/Henge/releases)。所有改动一做完就进 `main`，所以两次发行之间的 `main` 可能是未完成状态。

## 与 Mac 共享

每台 Mac 只需要做一次：在 Mac 上打开「终端」，然后在 Henge 里打开「详情」，点 **输入设置命令**。在 Mac 上按回车，macOS 询问 `henge-agent` 和本地网络时选「允许」。Mac 的键盘布局需要是「美国」。

之后 Mac 个人文件夹里的 Henge 文件夹，就是「文件 › Henge › 共享」那个文件夹。你在 Mac 上复制的东西，设备上也能粘贴；粘贴按钮则把设备上的内容粘贴进 Mac。

## 已知限制

- 在 macOS 里登录 Apple 账户会因验证错误而失败。
- 图形只在 macOS 自带应用、Chrome、Firefox、VS Code 和 Discord 上测过。其他应用可能绘制异常。
- 登录后的头几分钟，macOS 还在后台忙着启动，应用打开会比较慢。
- 每次启动 Henge 只能启动一台 Mac。要启动另一台，或者重启／关机 macOS 之后再启动，请退出 Henge 再打开。
- iPadOS 会留一些快捷键给自己，比如 Command-Tab。
- 这是模拟，跑得比真 Mac 慢。

## 截图

<table>
  <tr>
    <td align="center" colspan="3"><img src="Screenshots/ipad.jpg" alt="iPad 上的 Discord"><br><sub>iPad</sub></td>
  </tr>
  <tr>
    <td align="center" width="33%"><img src="Screenshots/macs.png" alt="Mac 列表"><br><sub>Mac 列表</sub></td>
    <td align="center" width="33%"><img src="Screenshots/trackpad.png" alt="触控板"><br><sub>触控板</sub></td>
    <td align="center" width="33%"><img src="Screenshots/install.png" alt="安装 macOS"><br><sub>安装 macOS</sub></td>
  </tr>
</table>

<sub>在 Mac 上截取：App 自己的界面，使用示例数据，分别是 iPad 与 iPhone 尺寸，画面是 Henge 渲染器输出的一帧。</sub>

## 构建

需要一台装有 Xcode 27 或更高版本以及 `xcodegen` 的 Mac。Henge 的 StikJIT、设备内配对、libslirp 和 glib 来自 `~/Documents/Coding/Husk` 处构建好的 [Husk](https://github.com/Leviidev/Husk) 检出目录（可用 `HUSK` 环境变量指定别的路径）：

```bash
ios/scripts/fetch_deps.sh
tools/build_ios_restore.sh
make ios-lib
ios/scripts/package_ipa.sh
```

这样会生成 `~/Desktop/Henge.ipa`；`package_ipa.sh --trollstore` 会写出 `Henge.tipa`。

`make` 会为 Mac 构建引擎 `build/hengevm`，`make test` 跑它的测试。

### 用 GitHub 构建，不需要 Mac

仓库里带了 `.github/workflows/build-ipa.yml`，在 GitHub 的 macOS runner 上编译并直接给出成品：

1. 把这个仓库推到你自己的 GitHub 账号（或先 Fork 官方仓库，再把本仓库的改动合进去）。
2. 打开仓库的 **Actions** 页面，左边选 **构建 Henge 中文版 IPA**，点 **Run workflow**。
   可选参数：`runs_on`（runner 机型）、`xcode_path`（指定 Xcode）、`husk_ref`（Husk 分支）、`make_tipa`（是否同时出 .tipa）。
3. 跑完（首次约 30–60 分钟，命中缓存后快很多）在本次运行的页面底部下载 **Artifacts**：
   `Henge-中文版-N` 里是 `Henge.ipa`（TrollStore 版本另有 `Henge.tipa`）。
4. 安装：`Henge.ipa` 用 SideStore / AltStore / Impactor 侧载——它们会用你自己的证书重签，不需要我们签名；
   `Henge.tipa` 用 TrollStore 安装。

流程做的事就是上文那几步：拉 Husk 只编译 Henge 需要的东西（`StikJIT.xcframework`、`libhusk_rppairing.a`、glib/slirp），
然后 `fetch_deps.sh` → `build_ios_restore.sh` → `make ios-lib` → `package_ipa.sh`。

> 注意：Henge 官方要求 Xcode 27 及以上（JIT 助手用 iOS 26 SDK，设备内配对用 iOS 27 API）。
> 如果公开 runner 当时还没装这个版本，第 2 步会打出警告并在编译阶段失败——那就把 `runs_on` 换成更新的镜像，
> 或者用 `xcode_path` 指向自建 runner 上的 Xcode。


## 许可

GPL-2.0-or-later。Henge 编译进了 usbmuxd（GPLv2 或 GPLv3）以及来自 Husk 的代码（GPL-2.0-or-later），因此发布的二进制整体是 GPL 作品，不能上架 App Store。详见 [docs/licensing.md](docs/licensing.md)。

macOS 和 Mac 的启动 ROM 是 Apple 的，并不属于 Henge。安装时 Henge 会从 Apple 下载这两者。
