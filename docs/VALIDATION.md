# 可行性验证记录

验证日期：2026-07-17（Asia/Singapore）

| 环节 | 实际验证 | 结果 |
| --- | --- | --- |
| Swift 核心 | `swift test --disable-sandbox`，覆盖可变网格、矩形帧、ping-pong、行为图、Ed25519、路径逃逸、ZIP 条目规则 | 9/9 通过 |
| v2 资源 | `validate_atlas.py --require-v2` | 1536×2288、8×11、RGBA、无绿幕残留、0 errors/0 warnings |
| 标准动作 | 逐行动作提取、组件检查、联系表与最终视觉 QA | 9 行全部通过 |
| 16 方位 | 连续性度量、3 名隔离 reviewer 的 14 组盲测、严格多数与隐藏答案核对 | 14/14 通过，0 warnings |
| Catalog | `dingdang-pet-tool import-codex-v2` 后再次 `validate` | 25 个动画、16 个方向，0 issues |
| Release 内容签名 | 从 GitHub 下载 `manifest.json` / `manifest.sig` 后运行 `verify` | Ed25519 valid；篡改 manifest 后退出码 1 |
| Release ZIP | 下载后核对大小、SHA-256、解压并验证 catalog | 2,960,136 bytes；SHA-256 `337ff55917069c314dd34f5011de756d9eb3f648dae21954462b7f22ea17c51d`；0 issues |
| App 启动更新 | 清空 App Support 后启动正式构建 | 自动创建并激活 `1.0.0-355291544` |
| 更新幂等 | 第二次启动并检查 releases 目录 | 仍只有一个版本目录；ETag 与 Release ID 已持久化 |
| App 构建 | `scripts/build-app.sh` | release 构建成功 |
| App 签名 | `codesign --verify --deep --strict` | ad-hoc Hardened Runtime 构建验证通过 |
| 开发 DMG | `scripts/package-development-dmg.sh` | `dist/Dingdang-Pet-development.dmg` 创建成功 |
| GitHub | public repo、main push、`pets-v1.0.0` Release 与四个资产 | 已发布 |
| Developer ID / 公证 | `security find-identity -v -p codesigning` | 当前机器 0 个有效身份；脚本已准备，但无法在没有 Apple 证书的情况下伪造公证结果 |

## GUI 回归

实现阶段已实际操作验证桌面透明窗口、右键菜单、菜单栏模式与隐藏模式；最终 v2 资源又通过联系表、方向图和独立盲测。最终构建在系统锁屏状态下成功启动并完成真实 Release 更新，但桌面自动化无法在锁屏时重新截取最终界面。解锁后应补做一次最终桌面/菜单栏实机截图。

## 分发边界

公开 Release 中附带的 development DMG 是 ad-hoc 签名，适合现在发给朋友测试，但朋友首次需要在 Finder 中对 App 右键选择“打开”。购买 Apple Developer Program、安装 `Developer ID Application` 证书并配置 notary profile 后，运行 `scripts/release-macos.sh` 才能生成正常双击、无需绕过 Gatekeeper 的公证 DMG。
