# 可行性验证记录

验证日期：2026-07-17（Asia/Singapore）

| 环节 | 实际验证 | 结果 |
| --- | --- | --- |
| Swift 核心 | `swift test --disable-sandbox`，覆盖可变网格、矩形帧、ping-pong、行为图、签名、ZIP、菜单栏几何/刘海连续性、动画位移互锁与鼠标静止超时 | 16/16 通过 |
| v2 资源 | 对 Codex 原始 `dingdang-silver-shaded/spritesheet.webp` 运行 `validate_atlas.py --require-v2` | WebP RGBA、1536×2288、8×11、0 errors/0 warnings；SHA-256 `adcd91dd426382d0acbe16d4eb0df6c456f4645bcbbd0c696d08e8007bf456e3` |
| 标准动作 | 生成 contact sheet 并做隔离视觉 QA | 9 行基础动作全部通过，无跨格、错位、裁切或紫色残留 |
| 16 方位 | 生成 direction QA sheet 并检查 22.5° 方向环 | 16/16 连续合理，首尾闭环 |
| Catalog | `dingdang-pet-tool import-codex-v2` 后再次 `validate` | 25 个动画、16 个方向，0 issues |
| Release 内容签名 | 从 GitHub 重新下载 v1.3.0 的 `manifest.json` / `manifest.sig` 后运行 `verify` | Ed25519 valid |
| Release ZIP | 从 GitHub 重新下载、核对 manifest、解压并验证 catalog | 2,082,943 bytes；SHA-256 `b78f712a91a18af180baf6372e038b1860ae0fc0be26ae6e1a5794eca06ee13a`；内含 WebP 与 Codex 原图 hash 完全相同 |
| App 启动更新 | 保留 v1.2.0 后启动正式构建 | 自动抓取、验签、安装并激活 `1.3.0-355553493`；速度、慢动作、随机池与视线超时均来自新 catalog |
| 更新幂等 | 第二次启动并检查 releases 目录 | 仍只有 v1.2.0 与 v1.3.0 两个保留目录，没有重复安装；ETag 与 Release ID `355553493` 已持久化 |
| 菜单栏几何 | 1470×956 带刘海屏，实际菜单栏 33 pt；窗口坐标采样与连续性检查 | 宠物窗口 31×33 pt、脚底对齐菜单栏底边；安全范围 90…1209，整条范围 0…1439；646…825 刘海段坐标连续无瞬移 |
| 动作/位移互锁 | 对移动中的宠物注入一次点击并以 0.1 秒采样窗口 X | 互动动作期间连续 8 个样本原地不动，动作结束后恢复对应方向位移 |
| GUI 视觉 | Computer Use 分别读取菜单栏 31×33 窗口与桌面 144×156 窗口 | 两种模式均显示完整银渐层叮当；菜单栏不再只露顶部残片，桌面鼠标静止后回到正面 idle |
| App 构建 | `scripts/build-app.sh` | release 构建成功 |
| App 签名 | `codesign --verify --deep --strict` | ad-hoc Hardened Runtime 构建验证通过 |
| 开发 DMG | `scripts/package-development-dmg.sh` | 2,723,519 bytes；SHA-256 `a044c717e2e4dea3cf7a290dc9ed879fb920c993bf6643fe1d48fbc22cd57e07` |
| GitHub | public repo、main push、`pets-v1.3.0` Release 与四个资产 | 已发布；Actions run `29566025759` 成功 |
| Developer ID / 公证 | `security find-identity -v -p codesigning` | 当前机器 0 个有效身份；脚本已准备，但无法在没有 Apple 证书的情况下伪造公证结果 |

## GUI 回归

实现阶段已实际操作验证桌面透明窗口、右键菜单、菜单栏模式与隐藏模式；银渐层 v2 资源又通过联系表与方向图视觉 QA。最终构建完成了 v1.2.0 → v1.3.0 的真实启动更新，并针对用户截图中的顶部裁切改成显式精灵中心坐标；Computer Use 回归确认桌面与菜单栏都显示完整形象。彩虹范围预览使用独立透明、忽略鼠标事件的状态栏 panel，覆盖宽度直接复用经过单测的实际移动边界。

## 分发边界

公开 Release 中附带的 development DMG 是 ad-hoc 签名，适合现在发给朋友测试，但朋友首次需要在 Finder 中对 App 右键选择“打开”。购买 Apple Developer Program、安装 `Developer ID Application` 证书并配置 notary profile 后，运行 `scripts/release-macos.sh` 才能生成正常双击、无需绕过 Gatekeeper 的公证 DMG。
