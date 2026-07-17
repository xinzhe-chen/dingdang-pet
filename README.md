# Dingdang Pet

Dingdang Pet 是一个独立运行的原生 macOS 桌面宠物。App 本身是固定的通用运行时；宠物外观、atlas 几何、动画、行为图、菜单栏速度和大部分展示参数都从签名的 GitHub Release 资源加载。

## 已实现

- 桌面透明悬浮、拖动、滚轮/触控板缩放和位置记忆
- 单击、双击、长按、随机 idle 与方向视线互动
- 整条菜单栏漫步、安全范围、刘海避让、左右转向和暂停
- 桌面、菜单栏、隐藏三模式；固定状态栏入口始终可恢复宠物
- 任意行列网格 atlas、命名矩形帧、多 atlas、任意动作名与逐帧时长
- forward/reverse/ping-pong、循环次数、语义 binding 和声明式行为图
- GitHub Latest Release 启动检查、ETag、Ed25519、SHA-256、白名单解压
- staging 验证、原子激活、失败回滚和旧版本保留
- 宠物验证、内容密钥、资源打包、GitHub Release、App 签名与公证工具
- hatch-pet v2 兼容能力和可替换内置宠物目录

## 本地构建

要求 macOS 13+、Xcode 15+ 和 Swift 5.10+。

```bash
swift test --disable-sandbox
scripts/build-app.sh
open "dist/Dingdang Pet.app"
```

构建产物位于 `dist/Dingdang Pet.app`。默认使用 ad-hoc 签名，只适合本机开发。

## 资源验证

```bash
swift run --disable-sandbox dingdang-pet-tool validate \
  Sources/DingdangPetApp/Resources/DefaultCatalog
```

资源协议见 [RESOURCE_FORMAT.md](docs/RESOURCE_FORMAT.md)，完整 JSON Schema 位于 [catalog-v1.schema.json](Schemas/catalog-v1.schema.json)。
本次端到端实测结果见 [VALIDATION.md](docs/VALIDATION.md)。

标准 Codex Pet v2 atlas 可以直接转换成完整 catalog：

```bash
swift run --disable-sandbox dingdang-pet-tool import-codex-v2 \
  spritesheet.webp dingdang '叮当' 1.1.0 output-catalog
```

该命令接受 PNG 或 WebP，要求标准 8×11、192×208 cell 的 v2 atlas，并自动写入 9 行动作、逐帧时长、16 个视线方向和默认互动行为。其他宠物也可以直接使用完全可变的 v1 资源协议。

## 配置 GitHub Release

1. 生成一次内容签名密钥：

   ```bash
   scripts/configure-content-signing.sh
   ```

2. 安全备份 `.content-signing-key`，不要提交。将 `Config/content-public-key.txt` 的内容作为构建时的 `CONTENT_PUBLIC_KEY_BASE64`。
3. App 构建时设置：

   ```bash
   export CONTENT_PUBLIC_KEY_BASE64="$(cat Config/content-public-key.txt)"
   export GITHUB_LATEST_RELEASE_URL="https://api.github.com/repos/xinzhe-chen/dingdang-pet/releases/latest"
   scripts/build-app.sh
   ```

4. 发布宠物资源：

   ```bash
   scripts/publish-pet-release.sh 1.1.0 xinzhe-chen/dingdang-pet
   ```

## 给朋友分发

App 代码不使用自动更新。第一次正式分发使用 Developer ID 和 Apple 公证：

```bash
export DEVELOPER_ID_APPLICATION="Developer ID Application: Your Name (TEAMID)"
export NOTARY_PROFILE="dingdang-notary"
export CONTENT_PUBLIC_KEY_BASE64="$(cat Config/content-public-key.txt)"
export GITHUB_LATEST_RELEASE_URL="https://api.github.com/repos/OWNER/REPO/releases/latest"
scripts/release-macos.sh
```

最终文件为 `dist/Dingdang-Pet.dmg`。详细准备步骤见 [DISTRIBUTION.md](docs/DISTRIBUTION.md)。

没有 Developer ID 时可运行 `scripts/package-development-dmg.sh` 生成 ad-hoc DMG；朋友首次打开需要在 Finder 对 App 右键选择“打开”。这只能作为测试分发，不能替代 Developer ID 公证。

## 安全边界

远程资源只能使用受支持的 JSON、PNG/WebP/JPEG 和音频文件。它不能执行 Swift、JavaScript、Shell、插件或动态库，不能修改 App bundle，也不能更换内置内容公钥。
