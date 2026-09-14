# ProxyBird（xiaoli-Proxy）

[English](README.md) | 中文

> 基于 Flutter 的开源免费跨平台 HTTP(S) 抓包调试工具，支持 Windows、Mac、Android、iOS、Linux 全平台。
> 本仓库为 ProxyPin / ProxyBird 的定制分支，Android 端 UI 已全面重构为 iOS 26 风格的**液态玻璃（Liquid Glass）**效果，原有功能保持不变。

你可以使用它拦截、检查并重写 HTTP(S) 流量，支持抓取 Flutter 应用流量。应用基于 Flutter 开发，UI 美观易用，桌面端与移动端共享同一套代理内核。

## 核心特性

- **手机扫码连接**：无需手动配置 WiFi 代理，支持配置同步，所有终端可互相扫码连接并转发流量。
- **域名过滤**：只拦截你需要的流量，不干扰其他应用。
- **搜索**：根据关键词、响应类型等多种条件搜索请求。
- **脚本**：支持编写 JavaScript 脚本处理请求或响应。
- **请求重写**：支持重定向、替换请求或响应报文，也可按规则增删改请求或响应。
- **请求映射**：不请求远程服务，使用本地配置或脚本直接响应。
- **请求解密**：配置 AES 解密密钥，自动解密 HTTP 消息体。
- **请求屏蔽**：支持根据 URL 屏蔽请求，不将请求发送到服务器。
- **断点调试**：支持对请求/响应设置断点，拦截后手动修改再放行。
- **历史记录**：自动保存抓包流量数据，方便回溯查看，支持 HAR 格式导出与导入。
- **工具箱**：收藏、常用编码工具、二维码、正则表达式、时间戳、AES、JSON/XML 格式化等。

## 液态玻璃 UI（Android）

Android 端已基于 [liquid_glass_widgets](https://pub.dev/packages/liquid_glass_widgets) 实现 iOS 26 风格液态玻璃效果：

- 全局玻璃主题（模糊、厚度、高光、饱和度等参数可调）
- 首页、侧边抽屉、设置页、请求列表等页面全面玻璃化
- 仅改动 UI 层，功能与代理内核保持原有行为

## 下载

- GitHub Releases：<https://github.com/HZY-520/xiaoli-Proxy/releases>
  - 液态玻璃版 APK：<https://github.com/HZY-520/xiaoli-Proxy/releases/download/v1.0.0-liquid-glass/proxypin-liquid-glass-debug.apk>

## 从源码构建

环境要求：Flutter SDK（Dart SDK >= 3.0.2）、Android SDK / Xcode / Visual Studio（按目标平台）。

```bash
# 安装依赖
flutter pub get

# 运行
flutter run -d android|ios|macos|windows|linux

# 打包 Android APK
flutter build apk --debug

# 运行测试
flutter test
```

> Mac 首次打开会提示"不受信任的开发者"，需到 系统偏好设置 → 安全性与隐私 → 允许任何来源。

## 技术架构

- **入口**：`lib/main.dart` 按平台选择桌面 / 移动端壳，移动端初始化液态玻璃主题。
- **代理内核**：`ProxyServer` 管理代理生命周期与系统代理（`lib/network/bin/server.dart`）。
- **流量管线**：Socket/Channel 管线与 TLS 中间人握手、中继回退（`lib/network/channel/network.dart`）。
- **请求路由**：`HttpProxyChannelHandler` / `HttpResponseProxyHandler` 集中处理 HTTP 请求/响应（`lib/network/handle/http_proxy_handle.dart`）。
- **拦截器模型**：所有流量改动通过 `Interceptor` 钩子（`preConnect`/`onRequest`/`execute`/`onResponse`/`onError`）实现，按优先级排序（`lib/network/components/interceptor.dart`）。
- **持久化**：抓包数据以 HAR 格式记录存储（`lib/storage/histories.dart`、`lib/utils/har.dart`）。

## 目录结构

```
lib/
├── main.dart                 # 应用入口（桌面/移动端分流 + 液态玻璃初始化）
├── network/                  # 代理内核（共享逻辑）
│   ├── bin/                  # 服务生命周期、配置、监听
│   ├── channel/              # Socket/Channel 管线、TLS
│   ├── components/           # 拦截器链（hosts/rewrite/map/script/block...）
│   ├── handle/               # HTTP/WebSocket/SSE 请求处理
│   ├── http/                 # HTTP 编解码、WebSocket、SSE
│   ├── mcp/                  # MCP Server
│   └── socks/                # SOCKS5
├── storage/                  # 历史记录、收藏持久化
├── ui/
│   ├── desktop/              # 桌面端 UI
│   ├── mobile/               # 移动端 UI（含 liquid_glass.dart）
│   ├── component/            # 通用组件
│   └── toolbox/              # 工具箱页面
└── utils/                    # 工具函数（HAR、格式化、加解密等）
```

## 开源协议

本项目基于 [Apache License 2.0](LICENSE) 开源。

## 致谢

- 上游项目 [ProxyPin](https://github.com/wanghongenpin/proxypin) 及其 ProxyBird 源码
- [liquid_glass_widgets](https://pub.dev/packages/liquid_glass_widgets) 液态玻璃组件库
- 所有为开源生态做出贡献的开发者

[![JetBrains logo.](https://resources.jetbrains.com/storage/products/company/brand/logos/jetbrains.svg)](https://jb.gg/OpenSource)
