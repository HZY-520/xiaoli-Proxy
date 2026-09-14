/*
 * Copyright 2023 Hongen Wang All rights reserved.
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *      https://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lico_proxy/l10n/app_localizations.dart';
import 'package:flutter_toastr/flutter_toastr.dart';
import 'package:lico_proxy/native/app_lifecycle.dart';
import 'package:lico_proxy/native/floating_window.dart';
import 'package:lico_proxy/native/pip.dart';
import 'package:lico_proxy/native/vpn.dart';
import 'package:lico_proxy/network/bin/configuration.dart';
import 'package:lico_proxy/network/bin/listener.dart';
import 'package:lico_proxy/network/bin/server.dart';
import 'package:lico_proxy/network/channel/channel.dart';
import 'package:lico_proxy/network/channel/channel_context.dart';
import 'package:lico_proxy/network/http/http.dart';
import 'package:lico_proxy/network/http/websocket.dart';
import 'package:lico_proxy/network/http/http_client.dart';
import 'package:lico_proxy/network/mcp/mcp_server.dart';
import 'package:lico_proxy/storage/histories.dart';
import 'package:lico_proxy/ui/component/memory_cleanup.dart';
import 'package:lico_proxy/ui/component/multi_select_controller.dart';
import 'package:lico_proxy/ui/toolbox/toolbox.dart';
import 'package:lico_proxy/ui/configuration.dart';
import 'package:lico_proxy/ui/content/panel.dart';
import 'package:lico_proxy/ui/launch/launch.dart';
import 'package:lico_proxy/ui/mobile/liquid_glass.dart';
import 'package:shadcn_ui/shadcn_ui.dart';
import 'package:lico_proxy/ui/mobile/menu/drawer.dart';
import 'package:lico_proxy/ui/mobile/menu/bottom_navigation.dart';
import 'package:lico_proxy/ui/mobile/menu/menu.dart';
import 'package:lico_proxy/ui/mobile/request/history.dart';
import 'package:lico_proxy/ui/mobile/request/list.dart';
import 'package:lico_proxy/ui/mobile/request/search.dart';
import 'package:lico_proxy/ui/mobile/widgets/pip.dart';
import 'package:lico_proxy/ui/mobile/widgets/remote_device.dart';
import 'package:lico_proxy/utils/ip.dart';
import 'package:lico_proxy/utils/lang.dart';
import 'package:lico_proxy/utils/listenable_list.dart';
import 'package:lico_proxy/utils/navigator.dart';

import '../app_update/app_update_repository.dart';
import 'package:lico_proxy/ui/component/multi_window.dart';
import 'package:lico_proxy/ui/mobile/debug/breakpoint_executor.dart';
import 'package:lico_proxy/ui/mobile/shad/shad_design.dart';

///移动端首页
///@author wanghongen
class MobileHomePage extends StatefulWidget {
  final Configuration configuration;
  final AppConfiguration appConfiguration;

  const MobileHomePage(this.configuration, this.appConfiguration, {super.key});

  @override
  State<StatefulWidget> createState() {
    return MobileHomeState();
  }
}

class MobileApp {
  ///请求列表key
  static final GlobalKey<RequestListState> requestStateKey = GlobalKey<RequestListState>();

  ///搜索key
  static final GlobalKey<MobileSearchState> searchStateKey = GlobalKey<MobileSearchState>();

  ///请求列表容器
  static final container = ListenableList<HttpRequest>();

  static final multiSelectController = MultiSelectController();
}

class MobileHomeState extends State<MobileHomePage> implements EventListener, LifecycleListener {
  /// 选择索引
  final ValueNotifier<int> _selectIndex = ValueNotifier(0);

  StreamSubscription<HistoryItem>? _remoteHistorySubscription;

  late ProxyServer proxyServer;

  AppLocalizations get localizations => AppLocalizations.of(context)!;

  @override
  void onRequest(Channel channel, HttpRequest request) {
    MobileApp.requestStateKey.currentState!.add(channel, request);
    PictureInPicture.addData(request.requestUrl);

    //监控内存 到达阈值清理
    MemoryCleanupMonitor.onMonitor(onCleanup: () {
      MobileApp.requestStateKey.currentState?.cleanupEarlyData(32);
    });
  }

  @override
  void onResponse(ChannelContext channelContext, HttpResponse response) {
    MobileApp.requestStateKey.currentState!.addResponse(channelContext, response);
  }

  @override
  void onMessage(Channel channel, HttpMessage message, WebSocketFrame frame) {
    var panel = NetworkTabController.current;
    if (panel?.request.get() == message || panel?.response.get() == message) {
      panel?.changeState();
    }
  }

  @override
  void initState() {
    super.initState();

    AppLifecycleBinding.instance.addListener(this);
    proxyServer = ProxyServer(widget.configuration);
    proxyServer.addListener(this);
    proxyServer.start();
    // 绑定抓包数据容器并自动启动 MCP Server（若用户开启）
    McpServer.instance.bindRequestContainer(MobileApp.container);
    unawaited(McpServer.instance.autoStartIfEnabled());
    _remoteHistorySubscription = HistoryStorage.onRemoteImported.listen((item) => _openHistoryPage(item));

    if (widget.appConfiguration.upgradeNoticeV30) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        showUpgradeNotice();
      });
    } else if (Platform.isAndroid) {
      AppUpdateRepository.checkUpdate(context);
    }

    // Handle breakpoint window on mobile
    MultiWindow.onOpenWindow = (widgetName, args) async {
      if (widgetName == 'BreakpointExecutor' && args != null) {
        if (!mounted) return;
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => BreakpointExecutor(
              requestId: args['requestId'],
              request: HttpRequest.fromJson(jsonDecode(jsonEncode(args['request']))),
              response:
                  args['response'] == null ? null : HttpResponse.fromJson(jsonDecode(jsonEncode(args['response']))),
              isResponse: args['type'] == 'response',
            ),
          ),
        );
      }
    };
  }

  @override
  void dispose() {
    AppLifecycleBinding.instance.removeListener(this);
    _remoteHistorySubscription?.cancel();
    super.dispose();
  }

  void toRequestsView(HistoryItem item, HistoryStorage storage) {}

  void _openHistoryPage(HistoryItem item) {
    _selectIndex.value = 2;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }

      Navigator.of(context)
          .push(MaterialPageRoute(
              builder: (BuildContext context) => HistoryRecord(history: item, proxyServer: proxyServer)))
          .then((value) async {
        Future.delayed(const Duration(seconds: 60), () => item.requests = null);
      });
    });
  }

  int exitTime = 0;

  var requestPageNavigatorKey = GlobalKey<NavigatorState>();
  var toolboxNavigatorKey = GlobalKey<NavigatorState>();
  var configNavigatorKey = GlobalKey<NavigatorState>();
  var settingNavigatorKey = GlobalKey<NavigatorState>();

  @override
  Widget build(BuildContext context) {
    var navigationView = [
      NavigatorPage(
          navigatorKey: requestPageNavigatorKey,
          child: RequestPage(proxyServer: proxyServer, appConfiguration: widget.appConfiguration)),
      NavigatorPage(
          navigatorKey: toolboxNavigatorKey,
          child: Scaffold(
              appBar: PreferredSize(
                  preferredSize: const Size.fromHeight(42), child: ShadHeader(title: localizations.toolbox)),
              body: Toolbox(proxyServer: proxyServer))),
      NavigatorPage(navigatorKey: configNavigatorKey, child: ConfigPage(proxyServer: proxyServer)),
      NavigatorPage(
          navigatorKey: settingNavigatorKey,
          child: SettingPage(proxyServer: proxyServer, appConfiguration: widget.appConfiguration)),
    ];

    _selectIndex.value = 0;

    return PopScope(
        canPop: false,
        onPopInvokedWithResult: (didPop, result) async {
          if (didPop) {
            return;
          }

          if (navigationView[_selectIndex.value].onPopInvoked()) {
            return;
          }

          if (await enterPictureInPicture()) {
            return;
          }

          if (DateTime.now().millisecondsSinceEpoch - exitTime > 1500) {
            exitTime = DateTime.now().millisecondsSinceEpoch;
            if (mounted) {
              FlutterToastr.show(localizations.appExitTips, this.context,
                  rootNavigator: true, duration: FlutterToastr.lengthLong);
            }
            return;
          }
          //退出程序
          SystemNavigator.pop();
        },
        child: ValueListenableBuilder<int>(
            valueListenable: _selectIndex,
            builder: (context, index, child) => Scaffold(
                  body: IndexedStack(index: index, children: navigationView),
                )));
  }

  @override
  void onUserLeaveHint() {
    enterPictureInPicture();
  }

  Future<bool> enterPictureInPicture() async {
    if (Vpn.isVpnStarted) {
      if (!Platform.isAndroid || !(await (AppConfiguration.instance)).pipEnabled.value) {
        return false;
      }

      List<String>? appList =
          proxyServer.configuration.appWhitelistEnabled ? proxyServer.configuration.appWhitelist : [];
      List<String>? disallowApps;
      if (appList.isEmpty) {
        disallowApps = proxyServer.configuration.appBlacklist ?? [];
      }

      return PictureInPicture.enterPictureInPictureMode(
          Platform.isAndroid ? await localIp() : "127.0.0.1", proxyServer.port,
          appList: appList, disallowApps: disallowApps);
    }
    return false;
  }

  @override
  onPictureInPictureModeChanged(bool isInPictureInPictureMode) async {
    if (isInPictureInPictureMode) {
      Navigator.push(
          context,
          PageRouteBuilder(
              transitionDuration: Duration.zero,
              reverseTransitionDuration: Duration.zero,
              pageBuilder: (context, animation, secondaryAnimation) {
                return PictureInPictureWindow(MobileApp.container);
              }));
      return;
    }

    if (!isInPictureInPictureMode) {
      Navigator.maybePop(context);
      Vpn.isRunning().then((value) {
        Vpn.isVpnStarted = value;
        SocketLaunch.startStatus.value = ValueWrap.of(value);
      });
    }
  }

  void showUpgradeNotice() {
    bool isCN = Localizations.localeOf(context) == const Locale.fromSubtags(languageCode: 'zh');

    String content = isCN
        ? '提示：默认不会开启HTTPS抓包，请安装证书后再开启HTTPS抓包。\n\n'
            '1. 新增弱网模拟功能，支持自定义延迟、丢包、带宽限制等网络条件；\n'
            '2. 新增环境变量高亮，URL 和 Headers 支持环境变量渲染与颜色区分；\n'
            '3. 新增 GraphQL 操作名称识别与展示；\n'
            '4. 新增请求重写规则检测，Body 视图中标识匹配的重写规则；\n'
            '5. 增强 HTTP/2：实现大体积 Body 流式传输，优化 Header 编解码，新增分块传输解码与统一 Body 读取逻辑；\n'
            '6. 增强 cURL 生成：改进 multipart/form-data 和二进制 Body 的导出；\n'
            '7. 修复：Android VPN 网络切换导致抓包中断、WebSocket 多帧合并丢失、Socket 连接异常关闭、裸域名请求 URI 为空等问题。\n'
        : 'Note: HTTPS capture is disabled by default — please install the certificate before enabling HTTPS capture.\n\n'
            '1. Added weak network simulation with customizable latency, packet loss, and bandwidth throttling;\n'
            '2. Added environment variable highlighting with color-coded variable rendering in URLs and headers;\n'
            '3. Added GraphQL operation name recognition and display;\n'
            '4. Added request rewrite rule detection with rule matching indicators in the Body view;\n'
            '5. Enhanced HTTP/2: streaming for large bodies, improved header handling, chunked transfer decoding and unified body reading;\n'
            '6. Enhanced cURL generation: better multipart/form-data and binary body export;\n'
            '7. Fixed: Android VPN capture interruption on network switch, WebSocket frame merging loss, socket hang-up, empty URI for bare domains, and more.\n';
    showAlertDialog(isCN ? '更新内容V${AppConfiguration.version}' : "What's new in V${AppConfiguration.version}", content,
        () {
      widget.appConfiguration.upgradeNoticeV30 = false;
      widget.appConfiguration.flushConfig();
    });
  }

  void showAlertDialog(String title, String content, Function onClose) {
    showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) {
          return ShadDialog(
            actions: [
              ShadButton.ghost(
                onPressed: () {
                  onClose.call();
                  Navigator.pop(context);
                },
                child: Text(localizations.close),
              )
            ],
            title: Text(title, style: const TextStyle(fontSize: 18)),
            child: SelectableText(content),
          );
        });
  }
}

class RequestPage extends StatefulWidget {
  final ProxyServer proxyServer;
  final AppConfiguration appConfiguration;

  const RequestPage({super.key, required this.proxyServer, required this.appConfiguration});

  @override
  State<RequestPage> createState() => RequestPageState();
}

class RequestPageState extends State<RequestPage> {
  /// 远程连接
  final ValueNotifier<RemoteModel> remoteDevice = ValueNotifier(RemoteModel(connect: false));

  /// 侧边栏打开状态（用于让 AppBar 顶栏在抽屉滑出时变透明，避免顶栏黄带外露）
  bool _drawerOpen = false;

  late ProxyServer proxyServer;

  AppLocalizations get localizations => AppLocalizations.of(context)!;

  @override
  void initState() {
    super.initState();
    proxyServer = widget.proxyServer;

    //远程连接
    remoteDevice.addListener(() {
      if (remoteDevice.value.connect) {
        proxyServer.configuration.remoteHost = "http://${remoteDevice.value.host}:${remoteDevice.value.port}";
        checkConnectTask(context);
      } else {
        proxyServer.configuration.remoteHost = null;
      }
    });
  }

  @override
  void dispose() {
    remoteDevice.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(children: [
      Scaffold(
        appBar: _MobileAppBar(
          widget.appConfiguration,
          proxyServer,
          remoteDevice: remoteDevice,
          drawerOpen: _drawerOpen,
        ),
        drawer: DrawerWidget(proxyServer: proxyServer, container: MobileApp.container),
        onDrawerChanged: (isOpen) {
          if (_drawerOpen != isOpen) {
            setState(() => _drawerOpen = isOpen);
          }
        },
        floatingActionButton: _launchActionButton(),
        body: ValueListenableBuilder(
            valueListenable: remoteDevice,
            builder: (context, value, _) {
              return Column(children: [
                value.connect ? remoteConnect(value) : const SizedBox(),
                Expanded(
                    child: RequestListWidget(
                        key: MobileApp.requestStateKey,
                        proxyServer: proxyServer,
                        list: MobileApp.container,
                        selectionController: MobileApp.multiSelectController))
              ]);
            }),
      ),
      PictureInPictureIcon(proxyServer),
    ]);
  }

  Widget _launchActionButton() {
    return Theme(
        data: ThemeData.from(
            colorScheme: Theme.of(context).colorScheme, textTheme: Theme.of(context).textTheme, useMaterial3: true),
        child: SocketLaunch(
            proxyServer: proxyServer,
            size: 64,
            padding: EdgeInsets.zero,
            startup: proxyServer.configuration.startup,
            serverLaunch: false,
            onStart: () async {
              String host = Platform.isAndroid ? await localIp(readCache: false) : "127.0.0.1";
              int port = proxyServer.port;
              if (Platform.isIOS) {
                await proxyServer.retryBind();
              }

              if (remoteDevice.value.ipProxy == true) {
                host = remoteDevice.value.host!;
                port = remoteDevice.value.port!;
              }

              Vpn.startVpn(host, port, proxyServer.configuration, ipProxy: remoteDevice.value.ipProxy);
            },
            onStop: () => Vpn.stopVpn()));
  }

  /// 远程连接
  Widget remoteConnect(RemoteModel value) {
    return Container(
        margin: const EdgeInsets.only(top: 5, bottom: 5),
        height: 56,
        width: double.infinity,
        child: ShadButton(
          onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (BuildContext context) {
            return RemoteDevicePage(remoteDevice: remoteDevice, proxyServer: proxyServer);
          })),
          child: Text(localizations.remoteConnected(remoteDevice.value.os ?? ', ${remoteDevice.value.hostname}'),
              style: Theme.of(context).textTheme.titleMedium),
        ));
  }

  /// 检查远程连接
  Future<void> checkConnectTask(BuildContext context) async {
    int retry = 0;
    Timer.periodic(const Duration(milliseconds: 15000), (timer) async {
      if (remoteDevice.value.connect == false) {
        timer.cancel();
        return;
      }

      try {
        var response = await HttpClients.get("http://${remoteDevice.value.host}:${remoteDevice.value.port}/ping")
            .timeout(const Duration(seconds: 3));
        if (response.bodyAsString == "pong") {
          retry = 0;
          return;
        }
      } catch (e) {
        retry++;
      }

      if (retry > 3) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).removeCurrentSnackBar();

          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
              content: Text(localizations.remoteConnectDisconnect),
              action: SnackBarAction(
                  label: localizations.disconnect,
                  onPressed: () {
                    timer.cancel();
                    remoteDevice.value = RemoteModel(connect: false);
                  })));
        }
      }
    });
  }
}

/// 移动端AppBar
class _MobileAppBar extends StatefulWidget implements PreferredSizeWidget {
  final AppConfiguration appConfiguration;
  final ProxyServer proxyServer;
  final ValueNotifier<RemoteModel> remoteDevice;
  final bool drawerOpen;

  const _MobileAppBar(
    this.appConfiguration,
    this.proxyServer, {
    required this.remoteDevice,
    this.drawerOpen = false,
  });

  @override
  State<_MobileAppBar> createState() => _MobileAppBarState();

  @override
  Size get preferredSize => const Size.fromHeight(56);
}

class _MobileAppBarState extends State<_MobileAppBar> {
  late OnchangeListEvent<HttpRequest> _listEvent;
  bool _floatingActive = false;

  @override
  void initState() {
    super.initState();
    _listEvent = OnchangeListEvent<HttpRequest>(() {
      if (mounted) setState(() {});
    });
    MobileApp.container.addListener(_listEvent);
    SocketLaunch.startStatus.addListener(_onCaptureStateChanged);
    _syncFloatingState();
  }

  @override
  void dispose() {
    MobileApp.container.removeListener(_listEvent);
    SocketLaunch.startStatus.removeListener(_onCaptureStateChanged);
    super.dispose();
  }

  /// 抓包状态变化时同步到悬浮窗图标
  void _onCaptureStateChanged() {
    final running = SocketLaunch.startStatus.value.get() ?? false;
    FloatingWindow.updateState(running);
  }

  /// 初始化时查询悬浮窗是否已在显示（比如服务被系统重启后）
  Future<void> _syncFloatingState() async {
    final showing = await FloatingWindow.isShowing();
    if (mounted) setState(() => _floatingActive = showing);
  }

  /// 点击顶栏悬浮窗按钮：权限检查 + 启停
  Future<void> _toggleFloatingWindow() async {
    if (_floatingActive) {
      await FloatingWindow.stop();
      setState(() => _floatingActive = false);
      return;
    }

    final granted = await FloatingWindow.canDrawOverlays();
    if (!granted) {
      if (mounted) {
        FlutterToastr.show('需要悬浮窗权限才能显示', context, rootNavigator: true);
      }
      await FloatingWindow.openOverlaySettings();
      return;
    }

    final running = SocketLaunch.startStatus.value.get() ?? false;
    final success = await FloatingWindow.start(isRunning: running);
    setState(() => _floatingActive = success);
    if (!success && mounted) {
      FlutterToastr.show('悬浮窗启动失败，请检查权限', context, rootNavigator: true);
    }
  }

  Future<void> _onClear(BuildContext context, AppLocalizations localizations) async {
    // HttpCanary 风格：清空抓包记录前始终二次确认
    bool? shouldClear = await showDialog<bool>(
      context: context,
      builder: (ctx) => ShadDialog(
        title: const Text('确定要清除当前的抓包记录吗？', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        actions: [
          ShadButton.ghost(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('取消'),
          ),
          ShadButton.ghost(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('清除'),
          ),
        ],
      ),
    );

    if (shouldClear == true) {
      MobileApp.requestStateKey.currentState?.clean();
    }
  }

  void _openSearch(BuildContext context) {
    Navigator.of(context).push(MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) => Scaffold(
              appBar: PreferredSize(
                preferredSize: const Size.fromHeight(kToolbarHeight),
                child: Container(
                  height: kToolbarHeight,
                  decoration: BoxDecoration(
                    color: ShadTheme.of(context).colorScheme.background,
                    border: Border(
                      bottom: BorderSide(
                          color: ShadTheme.of(context).colorScheme.border.withValues(alpha: 0.5), width: 0.5),
                    ),
                  ),
                  child: Row(
                    children: [
                      ShadIconButton.ghost(
                        icon: const Icon(LucideIcons.chevronLeft, size: 20),
                        onPressed: () => Navigator.of(context).pop(),
                      ),
                      Expanded(
                        child: MobileSearch(
                            key: MobileApp.searchStateKey,
                            onSearch: (val) {
                              MobileApp.requestStateKey.currentState?.search(val);
                              Navigator.of(context).pop();
                            }),
                      ),
                    ],
                  ),
                ),
              ),
              body: const SizedBox.shrink(),
            )));
  }

  @override
  Widget build(BuildContext context) {
    AppLocalizations localizations = AppLocalizations.of(context)!;

    final Color iconColor = glassIconColor(context);
    final Color titleColor = glassTextColor(context);

    return Container(
      height: 58,
      decoration: BoxDecoration(
        color: ShadTheme.of(context).colorScheme.background,
        border: Border(
          bottom: BorderSide(
            color: ShadTheme.of(context).colorScheme.border.withValues(alpha: 0.5),
            width: 0.5,
          ),
        ),
      ),
      child: Row(
        children: [
          const SizedBox(width: 4),
          Builder(
            builder: (ctx) => ShadIconButton.ghost(
              icon: Icon(LucideIcons.menu, color: iconColor, size: 22),
              width: 40,
              height: 40,
              onPressed: () => Scaffold.of(ctx).openDrawer(),
            ),
          ),
          // 品牌区
          ClipRRect(
            borderRadius: BorderRadius.circular(7),
            child: Image.asset('assets/icon.png', width: 26, height: 26, fit: BoxFit.cover),
          ),
          const SizedBox(width: 9),
          Text('小离Proxy',
              style: TextStyle(
                color: titleColor,
                fontSize: 19,
                fontWeight: FontWeight.w700,
                height: 1.2,
              )),
          const Spacer(),
          ShadIconButton.ghost(
              icon: Icon(LucideIcons.search, color: iconColor, size: 20),
              width: 38,
              height: 38,
              onPressed: () => _openSearch(context)),
          ShadIconButton.ghost(
              icon: Icon(LucideIcons.eraser, color: iconColor, size: 20),
              width: 38,
              height: 38,
              onPressed: () => _onClear(context, localizations)),
          ShadIconButton.ghost(
              icon: Icon(
                LucideIcons.pictureInPicture2,
                size: 20,
                color: _floatingActive ? iconColor : iconColor.withValues(alpha: 0.55),
              ),
              width: 38,
              height: 38,
              onPressed: _toggleFloatingWindow),
          MoreMenu(proxyServer: widget.proxyServer, remoteDevice: widget.remoteDevice),
          const SizedBox(width: 4),
        ],
      ),
    );
  }
}
