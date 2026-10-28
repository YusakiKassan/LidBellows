# 开源发布清单

## 首次公开前（待办）

- [x] **版权署名**：`YusakiKassan`。
- [x] **GitHub 账号**：`YusakiKassan`，已填入 `README.md` 和 `docs/COMPATIBILITY.md`。
- [x] **bundle id**：`io.github.yusakikassan.lidbellows`（`build.sh`、`docs/TUNING.md`）。
- [x] **git 身份**：本仓库用 `YusakiKassan <50410251+YusakiKassan@users.noreply.github.com>`。
- [ ] **首次提交**，推到 GitHub，确认 CI（`.github/workflows/ci.yml`）通过。
      CI 只在本地用 Command Line Tools 验证过同样的命令，还没在 GitHub 的 runner 上跑过。
- [ ] **仓库设置**：描述、topics（`macos` `swift` `accordion` `lid-angle-sensor` `synthesizer`）、
      创建 `compatibility` 和 `bug` 两个 label（issue 模板会用到）。
- [ ] **截图**：README 加一张窗口截图（放 `docs/screenshot.png`），最好再录一段带声音的短视频。
- [ ] **应用图标**：目前没有，用的是系统默认图标。

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
