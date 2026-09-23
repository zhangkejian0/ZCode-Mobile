# ZCode Mobile (HarmonyOS)

ZCode Desktop 的非官方鸿蒙（HarmonyOS NEXT）远程控制客户端。与 [Android 版](../main) 功能对应，代码独立实现。

## 架构

与 Android 版相同的核心理念：**不逆向、不伪造私有协议**。App 内嵌官方 Remote 页面（ArkWeb Web 组件），任务和状态由注入的 MutationObserver 从页面可见 DOM 中识别。

```text
鸿蒙手机 (ArkTS/ArkUI)                 电脑
+------------------------------+       +--------------------+
| Index 页: 连接/输入框/任务列表 |       | ZCode Desktop      |
| Remote 页: ArkWeb + JS 桥     | ----> | 移动端远程控制页面   |
|   window.ZCodeAndroidBridge  | <---- | Agent/终端/Git/MCP |
|   zcode-observer.js 注入      |       |                    |
+------------------------------+       +--------------------+
```

- **Web 桥**：`javaScriptProxy` 注入 `ZCodeAndroidBridge`（observer.js 的既有约定，JS 零改动复用）；回调经线程安全的 `emitter` 转回 UI 线程
- **加密存储**：Asset Store Kit（AES256-GCM，密钥在 TEE），保存 Remote 链接
- **URL 安全**：`http://` 仅接受局域网/回环/.local/CGNAT 地址，公网必须 `https://`
- **任务识别**：`zcode-observer.js` + `zcode-selectors.json`（rawfile），与 Android 版同源

## 状态（P0，v0.1.0）

- [x] 连接流：粘贴链接 → 加密保存 → 打开 Remote 页
- [x] ArkWeb 加载 Remote 页面 + observer 注入 + 任务列表（等待确认/进行中/最近）
- [x] 首页输入框 → 填入 Remote 页面 composer 并发送
- [x] 会话过期/错误识别与重试
- [ ] 扫码连接（Scan Kit）
- [ ] 多设备管理（对齐 Android v0.3.0）
- [ ] 通知、产物预览

## 构建

DevEco Studio 26.0 / HarmonyOS SDK 26.0.0 (API 26)：

```bash
node <DevEco>/tools/hvigor/bin/hvigorw.js assembleHap --mode module \
  -p module=entry@default -p buildMode=debug --no-daemon
```

安装到模拟器/真机需先在 IDE 配置自动签名（华为账号）。

## 免责声明

非官方社区项目。ZCode 及相关商标归其所有者所有。
