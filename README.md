# LidBellows 风箱

把 MacBook 的屏幕转轴当成手风琴风箱：右手在键盘上按旋律，左手推拉屏幕送气，
数字键弹低音和弦。屏幕不动就没有声音，和真手风琴一样。

原生 Swift 应用，没有第三方依赖，不需要任何系统权限：只读取一个 HID 特征报告，然后输出音频。
不联网，不录音，不读写磁盘（除了保存手感设置）。

[English](#english)

## 运行

需要 macOS 14 或更新、带开合角度传感器的 MacBook（见[兼容性](docs/COMPATIBILITY.md)），
以及 Xcode Command Line Tools（`xcode-select --install`），不需要完整的 Xcode。

```sh
git clone https://github.com/YusakiKassan/LidBellows.git
cd LidBellows
./build.sh            # 生成 build/LidBellows.app
open build/LidBellows.app
```

`./build.sh --install` 会同时复制到 `~/Applications`。开发时也可以直接 `swift run`。

没有传感器的 Mac 也能打开，用 `←` `→` 模拟开合，或按住空格持续供气。

## 怎么弹

点一下窗口，按住琴键，轻轻推拉屏幕。推得越快越响、音色越亮；停手后风压先保持一会儿再慢慢漏完，
所以换方向时声音不会断。

| 键 | 作用 |
|---|---|
| `A S D F G H J K L ; '` | 白键 C4 – F5 |
| `W E T Y U O P` | 黑键 |
| `1`–`7` | 低音和弦 C Dm Em F G Am G7（低音根音加和弦） |
| `Z` / `X` | 旋律降 / 升八度（±2） |
| 空格 | 按住持续供气，不用动屏幕 |
| `←` / `→` | 模拟合拢 / 拉开屏幕 |
| `Esc` | 全部止音 |

按物理键位识别，开着中文输入法也能弹。

## 调手感

窗口里有三个滑块，调整后自动保存：

- **灵敏度**：越大越灵敏，推拉幅度小也能吹满风箱。
- **换向保持**：屏幕停住后风压保持不漏的时间，留给你换方向。
- **余气**：保持结束后风压漏完的时间。

想要“一停就断”的真手风琴手感，把换向保持拖到 0、余气拖到最左。
每个参数的含义和计算方式见 [docs/TUNING.md](docs/TUNING.md)。

## 文档

- [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md)：模块划分、线程模型、传感器协议、音色合成
- [docs/TUNING.md](docs/TUNING.md)：风箱模型和所有参数
- [docs/COMPATIBILITY.md](docs/COMPATIBILITY.md)：已验证的机型，怎么报告你的机型
- [CONTRIBUTING.md](CONTRIBUTING.md)：构建、测试、代码约定
- [ACKNOWLEDGEMENTS.md](ACKNOWLEDGEMENTS.md)：参考过的项目
- [CHANGELOG.md](CHANGELOG.md)
- [docs/RELEASING.md](docs/RELEASING.md)：开源发布清单

## 注意

传感器接口是 Apple 未公开的，不保证所有机型和以后的 macOS 都能用。
请轻柔推拉屏幕，转轴和屏幕排线不是为高强度往复设计的，使用风险自负。

## 协议

[MIT](LICENSE)

---

## English

LidBellows turns a MacBook's hinge into accordion bellows. Hold notes on the keyboard and
gently push and pull the display to blow air through the reeds; the number keys play bass
chords. A still lid is a silent instrument, just like a real accordion nobody is squeezing.

A native Swift app with no third-party dependencies and no permissions to grant. It reads
one HID feature report and plays audio; no network, no microphone.

### Build and run

Requires macOS 14+, a MacBook with a lid-angle sensor ([compatibility](docs/COMPATIBILITY.md))
and the Xcode Command Line Tools.

```sh
./build.sh && open build/LidBellows.app
./test.sh   # unit tests
```

### Play

| Keys | Action |
|---|---|
| `A S D F G H J K L ; '` | White keys, C4 – F5 |
| `W E T Y U O P` | Black keys |
| `1`–`7` | Bass chords C Dm Em F G Am G7 |
| `Z` / `X` | Melody octave down / up |
| Space | Hold for steady air without moving the lid |
| `←` / `→` | Simulate closing / opening the lid |
| `Esc` | All notes off |

Three sliders set the feel: **sensitivity** (how little motion fills the bellows),
**reversal hold** (how long the air stays put when the lid stops) and **leak** (how long it
takes to run out afterwards). See [docs/TUNING.md](docs/TUNING.md).

### Safety

The sensor interface is undocumented and may not work on every model or future macOS
release. Move the display gently; laptop hinges are not built for vigorous repeated motion.

### License

[MIT](LICENSE)
