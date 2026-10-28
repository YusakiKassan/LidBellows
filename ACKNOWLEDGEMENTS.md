# 致谢

LidBellows 的代码全部是独立编写的，没有复制以下任何项目的源代码。
从它们那里借鉴的是思路、公开的硬件事实和设计取舍。

| 项目 | 协议 | 借鉴了什么 |
|---|---|---|
| [samhenrigold/LidAngleSensor](https://github.com/samhenrigold/LidAngleSensor) | Apache-2.0 | 开合角度传感器的 HID 协议（设备匹配条件、特征报告格式）。这一系列项目的源头 |
| [dappermint/maccordion](https://github.com/dappermint/maccordion) | MIT | musette 三簧音色、低通滤波随风压打开、音频线程不加锁不分配的原则 |
| [braydonglass/Accordion](https://github.com/braydonglass/Accordion) | MIT | 精简的模块划分、睡眠唤醒后重连传感器、按物理键记住音以防卡音 |
| [tiagofranzen/gaita](https://github.com/tiagofranzen/gaita) | MIT | 用一段时间内读数的最小二乘斜率测速 |
| [AloveZ66671/Accordion-mac](https://github.com/AloveZ66671/Accordion-mac) | MIT | 数字键低音和弦；机型兼容性信息 |
| [jiayi0618li-ctrl/MacBellows](https://github.com/jiayi0618li-ctrl/MacBellows) | MIT | 最初的灵感：Python 版的屏幕风箱 |

## 关于 LinCifeng/lid-accordion

早期原型参考过 [LinCifeng/lid-accordion](https://github.com/LinCifeng/lid-accordion)
的整体思路（换向时给音一个重音）。该项目使用 PolyForm Noncommercial 协议，与 MIT 不兼容。
为避免任何疑问，开源前已把受其影响的测速和方向判断部分换成另一种算法重写
（最小二乘拟合 + 施密特触发），当前代码不含该项目的代码或近似改写。

## 贡献者须知

请不要把 PolyForm Noncommercial、GPL 等与 MIT 不兼容协议项目的代码复制或改写进来。
借鉴别人的思路时，在这里补一行说明。
