# 可行性验证记录

验证日期：2026-07-17（Asia/Singapore）

| 环节 | 实际验证 | 结果 |
| --- | --- | --- |
| Swift 核心 | `swift test --disable-sandbox`，覆盖可变网格、矩形帧、ping-pong、行为图、Ed25519、路径逃逸、ZIP 条目规则 | 9/9 通过 |
| v2 资源 | 对 Codex 原始 `dingdang-silver-shaded/spritesheet.webp` 运行 `validate_atlas.py --require-v2` | WebP RGBA、1536×2288、8×11、0 errors/0 warnings；SHA-256 `adcd91dd426382d0acbe16d4eb0df6c456f4645bcbbd0c696d08e8007bf456e3` |
| 标准动作 | 生成 contact sheet 并做隔离视觉 QA | 9 行基础动作全部通过，无跨格、错位、裁切或紫色残留 |
| 16 方位 | 生成 direction QA sheet 并检查 22.5° 方向环 | 16/16 连续合理，首尾闭环 |
| Catalog | `dingdang-pet-tool import-codex-v2` 后再次 `validate` | 25 个动画、16 个方向，0 issues |
| Release 内容签名 | 从 GitHub 重新下载 v1.1.0 的 `manifest.json` / `manifest.sig` 后运行 `verify` | Ed25519 valid |
| Release ZIP | 从 GitHub 重新下载、核对 manifest、解压并验证 catalog | 2,082,886 bytes；SHA-256 `19baa65fbf06f7814400e9fe538400a69212bb8118e8a87ee4f241d5659fdf2c`；0 issues；内含 WebP 与 Codex 原图 hash 完全相同 |
| App 启动更新 | 保留旧版 `1.0.0-355291544` 后启动正式构建 | 自动抓取、验签、安装并激活 `1.1.0-355508308` |
| 更新幂等 | 第二次启动并检查 releases 目录 | 仍只有 v1.0.0 与 v1.1.0 两个保留目录，没有重复安装；ETag 与 Release ID `355508308` 已持久化 |
| App 构建 | `scripts/build-app.sh` | release 构建成功 |
| App 签名 | `codesign --verify --deep --strict` | ad-hoc Hardened Runtime 构建验证通过 |
| 开发 DMG | `scripts/package-development-dmg.sh` | `dist/Dingdang-Pet-development.dmg` 创建成功 |
| GitHub | public repo、main push、`pets-v1.1.0` Release 与四个资产 | 已发布；Actions run `29560138640` 成功 |
| Developer ID / 公证 | `security find-identity -v -p codesigning` | 当前机器 0 个有效身份；脚本已准备，但无法在没有 Apple 证书的情况下伪造公证结果 |

## GUI 回归

实现阶段已实际操作验证桌面透明窗口、右键菜单、菜单栏模式与隐藏模式；银渐层 v2 资源又通过联系表与方向图视觉 QA。最终构建完成了从旧 Release 到 v1.1.0 的真实启动更新，安装后的 WebP 也已成功完整解码为 1536×2288 图像。

## 分发边界

公开 Release 中附带的 development DMG 是 ad-hoc 签名，适合现在发给朋友测试，但朋友首次需要在 Finder 中对 App 右键选择“打开”。购买 Apple Developer Program、安装 `Developer ID Application` 证书并配置 notary profile 后，运行 `scripts/release-macos.sh` 才能生成正常双击、无需绕过 Gatekeeper 的公证 DMG。
