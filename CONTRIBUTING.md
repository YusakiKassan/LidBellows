# 参与贡献

欢迎提 issue 和 PR。最有用的贡献之一是[报告你的机型能不能用](docs/COMPATIBILITY.md#报告你的机型)。

## 环境

- macOS 14 或更新
- Xcode Command Line Tools（`xcode-select --install`），或完整的 Xcode

## 构建和测试

```sh
swift build          # 调试构建
swift run            # 直接运行
./build.sh           # 打包成 build/LidBellows.app
./test.sh            # 单元测试
```

只装了 Command Line Tools 时，`swift test` 找不到 `Testing.framework`，
`test.sh` 会自动补上路径；装了完整 Xcode 时它就是普通的 `swift test`。

## 代码约定

- **能脱离硬件的逻辑放进 `BellowsCore` 并写测试。** 风箱模型、键位、和弦都在那里。
  改变手感的修改要同时更新测试里的数值。
- **音频线程（`DSP.render` 及它调用的一切）不能加锁等待、不能分配内存、不能调用 Objective-C。**
  不要在里面用 `filter`、`map`、字符串、`print`。主线程只通过 `Synth.send` 发指令。
- 按物理键码识别按键，不要按字符。
- 注释说明“为什么”，不复述代码在做什么。
- 不引入第三方依赖，除非理由很充分。

## 协议

提交 PR 即表示你同意你的贡献以 [MIT 协议](LICENSE)发布。
请不要复制与 MIT 不兼容协议的代码，详见 [ACKNOWLEDGEMENTS.md](ACKNOWLEDGEMENTS.md#贡献者须知)。
