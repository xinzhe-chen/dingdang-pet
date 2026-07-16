# macOS 签名与公证

目标是让朋友下载 DMG、拖入 Applications、双击后只看到 macOS 正常的首次打开确认，不需要右键打开或修改“隐私与安全”。

## 一次性准备

1. 加入 Apple Developer Program。
2. 在 Xcode 的 Accounts 中登录并创建 `Developer ID Application` 证书。
3. 创建 notarytool Keychain profile：

   ```bash
   xcrun notarytool store-credentials dingdang-notary \
     --apple-id "YOUR_APPLE_ID" \
     --team-id "YOUR_TEAM_ID" \
     --password "APP_SPECIFIC_PASSWORD"
   ```

4. 生成内容签名密钥并备份私钥：

   ```bash
   scripts/configure-content-signing.sh
   ```

## 正式构建

```bash
export DEVELOPER_ID_APPLICATION="Developer ID Application: Your Name (TEAMID)"
export NOTARY_PROFILE="dingdang-notary"
export CONTENT_PUBLIC_KEY_BASE64="$(cat Config/content-public-key.txt)"
export GITHUB_LATEST_RELEASE_URL="https://api.github.com/repos/OWNER/REPO/releases/latest"
scripts/release-macos.sh
```

脚本会：

1. release 构建 App
2. 开启 Hardened Runtime 并签署
3. 验证嵌套签名
4. 上传 App ZIP 公证并 staple App
5. 制作带 Applications 快捷方式的 DMG
6. 签署、公证并 staple DMG
7. 用 `spctl` 做 Gatekeeper 验收

宠物资源更新不需要重新签署或公证 App。

## 干净机器验收

- 使用一台没有 Xcode、没有你的开发证书、没有登录你的 Apple ID 的 Mac
- 从浏览器下载 DMG
- 拖入 Applications
- 双击打开
- 切换桌面、菜单栏、隐藏模式
- 断网重启仍能显示内置或最后有效宠物
- 发布测试资源 Release，确认自动下载、切换与回滚
