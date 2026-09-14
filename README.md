# ProxyBird (xiaoli-Proxy)

[English](README.md) | [中文](README_CN.md)

> A free, open-source, cross-platform HTTP(S) packet capture & debugging tool built with Flutter. Supports Windows, Mac, Android, iOS, and Linux.
> This repository is a customized fork of ProxyPin / ProxyBird. The Android UI has been fully reworked with an iOS 26 style **Liquid Glass** effect, while all original functionality remains unchanged.

Use it to intercept, inspect, and rewrite HTTP(S) traffic, including traffic from Flutter apps. Built with Flutter, it offers a beautiful, easy-to-use UI with desktop and mobile clients sharing the same proxy engine.

## Features

- **Scan-to-connect (mobile)**: No need to manually configure the WiFi proxy, with configuration sync. All devices can connect to each other by scanning a QR code and forwarding traffic.
- **Domain filtering**: Only intercept the traffic you need, without interfering with other apps.
- **Search**: Search requests by keyword, response type, and other conditions.
- **Scripts**: Write JavaScript scripts to process requests or responses.
- **Request rewrite**: Supports redirects, replacing request/response messages, and rule-based add/remove/modify of requests or responses.
- **Request mapping**: Respond from local configuration or scripts without hitting the remote service.
- **Request decryption**: Configure an AES decryption key to automatically decrypt HTTP message bodies.
- **Request blocking**: Block requests by URL so they are never sent to the server.
- **Breakpoints**: Set breakpoints on requests/responses, edit them manually, then release.
- **History**: Captured traffic is saved automatically for later review, with HAR export and import support.
- **Toolbox**: Favorites, common encoding tools, QR codes, regular expressions, timestamps, AES, JSON/XML formatters, and more.

## Liquid Glass UI (Android)

The Android UI is built on [liquid_glass_widgets](https://pub.dev/packages/liquid_glass_widgets) for an iOS 26 style liquid glass look:

- Global glass theme with tunable blur, thickness, highlight, and saturation.
- Home page, side drawer, settings pages, request list, and more are fully glassified.
- Only the UI layer was changed; the proxy core and all functionality keep their original behavior.

## Downloads

- GitHub Releases: <https://github.com/HZY-520/xiaoli-Proxy/releases>
  - Liquid Glass APK: <https://github.com/HZY-520/xiaoli-Proxy/releases/download/v1.0.0-liquid-glass/proxypin-liquid-glass-debug.apk>

## Building from Source

Requirements: Flutter SDK (Dart SDK >= 3.0.2) plus Android SDK / Xcode / Visual Studio depending on the target platform.

```bash
# Install dependencies
flutter pub get

# Run
flutter run -d android|ios|macos|windows|linux

# Build Android APK
flutter build apk --debug

# Run tests
flutter test
```

> On macOS, the first launch may warn about an untrusted developer. Go to System Settings → Privacy & Security and allow it to run.

## Architecture

- **Entry point**: `lib/main.dart` picks the desktop or mobile shell by platform and initializes the liquid glass theme on mobile.
- **Proxy server**: `ProxyServer` owns the proxy lifecycle and system proxy toggling (`lib/network/bin/server.dart`).
- **Traffic pipeline**: Socket/channel pipeline, TLS MITM handshake, and relay fallbacks (`lib/network/channel/network.dart`).
- **Request routing**: HTTP request/response handling is centralized in `HttpProxyChannelHandler` / `HttpResponseProxyHandler` (`lib/network/handle/http_proxy_handle.dart`).
- **Interceptor model**: All traffic mutations go through `Interceptor` hooks (`preConnect`/`onRequest`/`execute`/`onResponse`/`onError`), sorted by priority (`lib/network/components/interceptor.dart`).
- **Persistence**: Captured traffic is stored as HAR-like records (`lib/storage/histories.dart`, `lib/utils/har.dart`).

## Project Layout

```
lib/
├── main.dart                 # App entry (desktop/mobile split + liquid glass init)
├── network/                  # Proxy core (shared logic)
│   ├── bin/                  # Server lifecycle, configuration, listeners
│   ├── channel/              # Socket/channel pipeline, TLS
│   ├── components/           # Interceptor chain (hosts/rewrite/map/script/block...)
│   ├── handle/               # HTTP/WebSocket/SSE request handlers
│   ├── http/                 # HTTP codec, WebSocket, SSE
│   ├── mcp/                  # MCP Server
│   └── socks/                # SOCKS5
├── storage/                  # History & favorites persistence
├── ui/
│   ├── desktop/              # Desktop UI
│   ├── mobile/               # Mobile UI (incl. liquid_glass.dart)
│   ├── component/            # Shared widgets
│   └── toolbox/              # Toolbox pages
└── utils/                    # Utilities (HAR, formatters, crypto, etc.)
```

## License

Licensed under the [Apache License 2.0](LICENSE).

## Acknowledgements

- Upstream project [ProxyPin](https://github.com/wanghongenpin/proxypin) and its ProxyBird source code
- [liquid_glass_widgets](https://pub.dev/packages/liquid_glass_widgets) liquid glass widget library
- All developers contributing to the open-source ecosystem

[![JetBrains logo.](https://resources.jetbrains.com/storage/products/company/brand/logos/jetbrains.svg)](https://jb.gg/OpenSource)
