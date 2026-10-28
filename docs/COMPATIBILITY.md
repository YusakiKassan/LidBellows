# 兼容性

开合角度传感器的 HID 接口没有公开文档。有些机型有这个传感器但不暴露接口，
以后的 macOS 更新也可能改变访问方式。

## 已验证

| 机型 | 型号标识 | 芯片 | macOS | 报告 | 结果 |
|---|---|---|---|---|---|
| MacBook Air | Mac17,4 | M5 | 26.5.1 | 7（0.01°） | 可用。约 10 Hz 刷新，静止抖动约 ±0.05° |

## 预计可用（未验证）

其他项目的报告显示，以下机型通常有可访问的传感器：

- 2021 年及以后的 14 / 16 英寸 Apple 芯片 MacBook Pro
- MacBook Air（M2，2022）及以后，包括 15 英寸
- MacBook Pro（16 英寸，2019）

## 已知不可用

- MacBook Air（M1，2020）
- 13 英寸 MacBook Pro（M1 / M2，带 Touch Bar）
- 没有内建屏幕的 Mac

这些机器上应用仍能打开，用方向键或空格代替屏幕。

## 检查你的机器

```sh
hidutil list | grep -i 0x8104
```

有输出说明系统里有这个设备。打开 LidBellows，右上角显示：

- `开合传感器 · 0.01°`：读到了高精度报告
- `开合传感器 · 1°`：只有整度报告，可以用但手感会粗一些
- `没找到传感器`：不支持，或者被别的程序占用

## 报告你的机型

欢迎提交 [传感器兼容性 issue](https://github.com/YusakiKassan/LidBellows/issues/new?template=sensor-report.yml)，写上：

- 机型和型号标识（苹果菜单 → 关于本机 → 更多信息，或 `sysctl -n hw.model`）
- macOS 版本（`sw_vers -productVersion`）
- 右上角显示的传感器状态
- 屏幕静止时风压是否保持 0，推拉是否顺畅
