# 架构

LidBellows 是一个 Swift Package，分两个 target：

| Target | 内容 | 依赖 |
|---|---|---|
| `BellowsCore` | 纯逻辑：风箱模型、键位、和弦、音高换算 | 只有 Foundation，有单元测试 |
| `LidBellows` | 应用：传感器、合成器、主循环、界面 | AppKit、SwiftUI、AVFoundation、IOKit |

能脱离硬件验证的都放在 `BellowsCore`，这样不用真机也能测手感有没有被改坏。

## 数据流

```
LidSensor ──角度──▶ Engine.tick (120 Hz) ──▶ Bellows ──风压──▶ Synth 指令队列 ──▶ 音频线程
                         ▲                                   ▲
KeyView ──物理键码──▶ Engine.keyDown/keyUp ──── noteOn/noteOff ┘
                         │
                         └──▶ @Published 状态 (约 30 Hz) ──▶ SwiftUI 界面
```

## 文件

| 文件 | 作用 |
|---|---|
| `Sources/BellowsCore/Bellows.swift` | 角度采样 → 角速度 → 风压，含换向检测。见 [TUNING.md](TUNING.md) |
| `Sources/BellowsCore/Keymap.swift` | 物理键码到动作的映射、低音和弦的排列、MIDI 音高 |
| `Sources/LidBellows/LidSensor.swift` | 通过 IOKit HID 读取开合角度 |
| `Sources/LidBellows/Synth.swift` | 实时合成器：AVAudioEngine + AVAudioSourceNode |
| `Sources/LidBellows/Engine.swift` | 主循环：读传感器、推进风箱、给合成器发指令、保存手感设置 |
| `Sources/LidBellows/KeyCatcher.swift` | 拿键盘焦点的隐形 NSView，转发物理键码 |
| `Sources/LidBellows/ContentView.swift` | 界面：风压条、手感滑块、琴键、和弦按钮 |
| `Sources/LidBellows/App.swift` | 入口；失去前台时全部止音 |

## 传感器

开合角度传感器是一个未公开的 HID 设备：

- 匹配条件：vendor `0x05AC`，primary usage page `0x20`（Sensor），primary usage `0x8A`
- **特征报告 7**：报告 ID 后跟 4 字节小端整数，单位 0.01°。优先使用。
- **特征报告 1**：报告 ID 后跟 2 字节小端整数，单位 1°。报告 7 不可用时退回。
- 0°–200° 以外的读数当作无效。

实测（MacBook Air M5，macOS 26.5.1）：传感器约 10 Hz 刷新，屏幕静止时读数在 ±0.05° 内抖动。

主循环每 1/120 秒读一次，只把**变化了的**读数交给风箱模型，因为重复的读数不包含运动信息。
连续约 2 秒读失败、或系统从睡眠唤醒时，重新打开设备。

协议最早由 [samhenrigold/LidAngleSensor](https://github.com/samhenrigold/LidAngleSensor) 逆向得出，
这里是独立实现。

## 合成器

### 线程

主线程只往一个容量 512 的指令队列里追加指令（按下、松开、风压、换风）。
音频回调每次渲染前用 **try-lock** 取走队列：拿不到锁就跳过，下一个缓冲区再取。
所以音频线程永远不会等主线程，也不在渲染时分配内存。队列满了就丢弃新指令，而不是阻塞。

离线测试（48 kHz，512 帧一个缓冲区）：24 个音同时响时，最慢一次渲染 0.24 ms，时限是 10.7 ms。

### 音色

- **旋律音**：三片簧，分别偏 −12、0、+11 音分（musette 调律），彼此拍频产生手风琴的颤音感。
  每个音另有一个固定的 ±2 音分偏差，模拟簧片永远调不完全准。
- **低音和弦**：单簧加一片低八度的簧，不做 musette。
  和弦 = 第二八度的根音（MIDI 36–47）+ 折叠到第三八度的三和弦（MIDI 48–59），
  所以所有和弦都在同一个音区，类似 Stradella 低音键盘。
- **波形**：带限锯齿波（polyBLEP），高音区不会混叠出杂音。
- **随风压变化**：总音量 ∝ 风压^1.1；低通滤波器截止频率 = 350 + 5200 × 风压^1.8 Hz，
  所以推得越猛越亮，不只是更响。另有少量随风压变化的气流噪声。
- **包络**：起音 12 ms，松键后 60 ms 淡出。风压在音频线程上再平滑 15 ms，避免拉链噪声。
- **换风**：推拉方向一换，所有在响的音短暂降到 75% 再在约 50 ms 内恢复，模仿换风的重音。
- **输出**：tanh 软削波防止大和弦破音，再经过一个 14% 湿声的小房间混响。
- 最多 24 个同时发声的音。没有空闲的音时，先抢已松键里最轻的，再抢最老的。

## 键盘

`KeyView` 用 macOS 虚拟键码（物理位置）识别按键，所以和输入法、键盘语言无关。
每个物理键记住它按下时开始的音，松开时停掉同一批音，
所以按住音时换八度，也不会让音卡住。带 Cmd 或 Ctrl 的组合键交给菜单处理（Cmd-Q 等照常可用）。
窗口失去键盘焦点或应用退到后台时全部止音，因为之后的松键事件会发给别的应用。

## 没有传感器时

方向键以 80°/s 的速度模拟开合，角度限制在 15°–130°，并以 20 Hz 喂给风箱模型，
让模型看到的输入和真传感器差不多。从模拟切回真传感器时，风箱模型重新开始测速，
避免两个角度之间的跳变被当成一次猛拉。
