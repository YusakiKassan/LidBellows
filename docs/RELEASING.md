# 开源发布清单

## 首次公开（已完成）

- [x] **版权署名**：`YusakiKassan`。
- [x] **GitHub 账号**：`YusakiKassan`，已填入 `README.md` 和 `docs/COMPATIBILITY.md`。
- [x] **bundle id**：`io.github.yusakikassan.lidbellows`（`build.sh`、`docs/TUNING.md`）。
- [x] **git 身份**：本仓库用 `YusakiKassan <50410251+YusakiKassan@users.noreply.github.com>`。
- [x] **首次提交**并推到私有仓库 `YusakiKassan/LidBellows`，CI 通过（GitHub runner 上是 Swift 6.1.2 / macOS 15）。
- [x] **仓库设置**：描述、topics、`compatibility` label 已设好（`bug` 是默认 label）。
- [x] **改成公开**（2026-10-28）。公开前检查过：提交记录只有 noreply 邮箱，文件和历史里没有本机路径、密钥或个人信息，截图元数据只有尺寸。
- [x] **截图**：`docs/screenshot.png`，已放进 README。不做视频。
- [ ] **应用图标**：可选，目前用系统默认图标。

## 发版

1. 更新 `CHANGELOG.md`：把“未发布”改成版本号和日期。
2. 同步 `build.sh` 里的 `CFBundleShortVersionString`。
3. `./test.sh && ./build.sh`，在真机上推拉试一遍。
4. 打包：`ditto -c -k --keepParent build/LidBellows.app LidBellows-<版本>.zip`，
   附上 `shasum -a 256` 校验值。
5. 打 tag `v<版本>`，在 GitHub Release 上传 zip。

## 签名和公证

`build.sh` 只做 ad-hoc 签名。没有 Apple Developer ID 时，下载的 app 会被 Gatekeeper 拦住，
Release 说明里要告诉用户：

```sh
xattr -dr com.apple.quarantine /Applications/LidBellows.app
```

或者在“系统设置 → 隐私与安全性”里点“仍要打开”。也可以只推荐从源码构建。
以后如果加入 Apple Developer Program，可以用 `codesign --options runtime` + `notarytool` 公证。

## 协议检查

- 所有源代码为原创，参考来源和协议见 `ACKNOWLEDGEMENTS.md`。
- 不打包任何音频样本或第三方二进制。
- 依赖只有 Apple 系统框架。
