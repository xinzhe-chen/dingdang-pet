# 可行性验证记录

验证日期：2026-07-17（Asia/Singapore）

| 环节 | 实际验证 | 结果 |
| --- | --- | --- |
| Swift 核心 | `swift test --disable-sandbox`，覆盖可变网格、矩形帧、ping-pong、行为图、签名、ZIP、菜单栏几何/刘海连续性、动画位移互锁与鼠标静止超时 | 16/16 通过 |
| v2 资源 | 对 Codex 原始 `dingdang-silver-shaded/spritesheet.webp` 运行 `validate_atlas.py --require-v2` | WebP RGBA、1536×2288、8×11、0 errors/0 warnings；SHA-256 `adcd91dd426382d0acbe16d4eb0df6c456f4645bcbbd0c696d08e8007bf456e3` |
| 标准动作 | 生成 contact sheet 并做隔离视觉 QA | 9 行基础动作全部通过，无跨格、错位、裁切或紫色残留 |
| 16 方位 | 生成 direction QA sheet 并检查 22.5° 方向环 | 16/16 连续合理，首尾闭环 |
| Catalog | `dingdang-pet-tool import-codex-v2` 加载主图集和独立翻肚皮图集后再次 `validate` | 26 个动画、16 个方向、2 个 atlas，0 issues；悬停绑定 `waving`，单击绑定 `belly-rub` |
| 翻肚皮资源 | 8 帧透明图集做连通域、绿边、裁切、动作连续性与独立风格对照 QA | `style_match=PASS`、`visual_qa=PASS`；1536×208 RGBA；SHA-256 `e6f7bdba3d045ee4203302f1a9a9b0e142199b0a5ad3dcce8411a977d5f2bd97` |
| Release 内容签名 | 从 GitHub 重新下载 v1.4.1 的 `manifest.json` / `manifest.sig` 后运行 `verify` | Ed25519 valid |
| Release ZIP | 从 GitHub 重新下载、核对 manifest、解压并验证 catalog | 2,254,313 bytes；SHA-256 `90fb6234bf97951fd4da8f60ca69b49fe2e9d148a9edae55eac598fc43f214b8`；主图集保持 Codex 原图 hash，翻肚皮图集 hash 与本地一致 |
| App 启动更新 | 保留 v1.4.0 后启动正式构建 | 自动抓取、验签、安装并激活 `1.4.1-355579056`；旧 v1.4.0 保留用于回退 |
| 更新幂等 | 检查 releases 目录与活动指针 | 活动指针、ETag 与 Release ID `355579056` 已持久化；最多保留两个资源版本 |
| 菜单栏几何 | 1470×956 带刘海屏，实际菜单栏 33 pt；窗口坐标采样与连续性检查 | 宠物窗口 31×33 pt、脚底对齐菜单栏底边；安全范围 90…1209，整条范围 0…1439；646…825 刘海段坐标连续无瞬移 |
| 动作/位移互锁 | 对移动中的宠物注入一次点击并以 0.1 秒采样窗口 X | 互动动作期间连续 8 个样本原地不动，动作结束后恢复对应方向位移 |
| GUI 视觉 | Computer Use 分别读取菜单栏 31×33 窗口与桌面 144×156 窗口 | 两种模式均显示完整银渐层叮当；菜单栏不再只露顶部残片，桌面鼠标静止后回到正面 idle |
| App 图标 | 1024×1024 白底银渐层叮当主图，经 `scripts/generate-app-icon.sh` 生成 10 档 `.icns` 并检查 16/32/128 px | 小尺寸仍可辨认圆脸、绿眼和银灰纹理；圆角外侧为真实透明，App 使用 `CFBundleIconFile=AppIcon.icns` |
| DMG 卷图标 | 在可写镜像中放置 `.VolumeIcon.icns` 并对卷根目录设置自定义图标属性后再压缩 | 只读挂载后 `GetFileInfo -a` 返回大写 `C`；卷图标与 App 图标逐字节一致 |
| App 构建 | `scripts/build-app.sh` | `1.3.2 (build 7)` release 构建成功 |
| App 签名 | `codesign --verify --deep --strict` | ad-hoc Hardened Runtime 构建验证通过 |
| 开发 DMG | `scripts/package-development-dmg.sh` 后执行 `hdiutil verify`、只读挂载、版本/资源/签名检查 | 7,594,677 bytes；SHA-256 `252444ea50fa4007273464960a53bef34d435794980c7bf0b47544ba7037ba79`；DMG 内 App/catalog/图集与白底图标均为最新版 |
| 远端 DMG | 上传 GitHub 后重新下载并与本地 `cmp` | 逐字节一致；Release asset digest 与本地 SHA-256 一致 |
| GitHub | public repo、main push、`pets-v1.4.1` Release 与四个资产 | 已发布；Actions run `29569366788` 成功 |
| Developer ID / 公证 | `security find-identity -v -p codesigning` | 当前机器 0 个有效身份；脚本已准备，但无法在没有 Apple 证书的情况下伪造公证结果 |

## GUI 回归

实现阶段已实际操作验证桌面透明窗口、右键菜单、菜单栏模式与隐藏模式；银渐层 v2 资源通过联系表和方向图视觉 QA，新增翻肚皮图集另行通过同画风、无碎片、无绿边和动作连续性 QA。最终构建完成了 v1.4.0 → v1.4.1 的真实启动更新，并针对用户截图中的顶部裁切改成显式精灵中心坐标；Computer Use 回归确认桌面与菜单栏都显示完整形象。彩虹范围预览使用独立透明、忽略鼠标事件的状态栏 panel，覆盖宽度直接复用经过单测的实际移动边界。

## 分发边界

公开 Release 中附带的 development DMG 是 ad-hoc 签名，适合现在发给朋友测试，但朋友首次需要在 Finder 中对 App 右键选择“打开”。购买 Apple Developer Program、安装 `Developer ID Application` 证书并配置 notary profile 后，运行 `scripts/release-macos.sh` 才能生成正常双击、无需绕过 Gatekeeper 的公证 DMG。
