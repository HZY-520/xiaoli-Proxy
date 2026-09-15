# 小离Proxy 安卓版发布包

## v1.0.1（UI 修复版）

| 项目 | 值 |
| --- | --- |
| 文件名 | `xiaoli-proxy-v1.0.1.apk` |
| 应用名 | 小离Proxy |
| 包名 | `com.lico.proxy` |
| 版本 | `1.0.1`（versionCode 2） |
| 大小 | 约 44 MB |
| 支持 ABI | `arm64-v8a`、`armeabi-v7a`、`x86_64` |
| minSdk / targetSdk | 24 / 36 |
| 签名 | 调试签名（正式签名密钥随构建环境丢失，升级安装需先卸载旧版） |

SHA-256：

```
d1a47b64bc2f8c307bdbbe62571a6425796c72fdbc60d7a1fa0c4050b50cadd2
```

### 主要变更

- **修复状态栏重叠**：顶栏增加状态栏安全区适配（首页、历史详情、应用过滤、映射、重写、工具箱等页面），菜单按钮可正常点击。
- **统一悬浮窗图标**：Android 悬浮窗、通知及画中画按钮更换为全新应用图标（透明背景、多密度适配）。
- **修复更新检查误报**：版本相同时不再弹出更新提示（版本比较逻辑缺陷修复）。
- 版本号更新为 `1.0.1`。

## v1.0.0（首个版本）

| 项目 | 值 |
| --- | --- |
| 文件名 | `xiaoli-proxy-v1.0.0.apk` |
| 应用名 | 小离Proxy |
| 包名 | `com.lico.proxy` |
| 版本 | `1.0.0`（versionCode 1） |
| 大小 | 约 44 MB |
| 支持 ABI | `arm64-v8a`、`armeabi-v7a`、`x86_64` |
| minSdk / targetSdk | 24 / 36 |
| 签名 | 正式签名（CN=Lico） |

SHA-256：

```
3ff83a7af7b3c1c1992caf9ee95188fc5cf6dca2b6aa3d802c41255e49e1eb69
```

### 主要变更

- **品牌化**：应用名改为「小离Proxy」，包名 `com.lico.proxy`，版本从 `1.0.0` 起，全新应用图标与侧边栏图标，关于页作者「离愁Lico」并补充开源声明。
- **shadcn UI 全量重构**（仅 Android 端）：基于 [flutter-shadcn-ui](https://github.com/nank1ro/flutter-shadcn-ui)，统一 zinc 色板 + 12px 圆角设计系统，重写全部移动端页面的顶栏、列表、按钮、弹窗与底部弹层。
- **业务逻辑零改动**，`flutter analyze` 为 0 error / 0 warning。

### 安装

下载 APK 后在安卓设备上安装即可（首次安装需允许「安装未知来源应用」）。

### 开源

- 上游项目：[ProxyPin](https://github.com/wanghongenpin/proxypin)
- 开源协议：Apache License 2.0
