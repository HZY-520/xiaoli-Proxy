/*
 * 小离Proxy - 侧边抽屉（shadcn 重构版）
 *
 * 视觉层完全改用 shadcn_ui 组件（ShadCard / ShadTile / ShadButton），
 * 移除了原先的液态玻璃容器与 HttpCanary 矢量图标资源依赖。
 * 所有导航目标、功能入口与业务逻辑保持与原实现一致。
 */
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:shadcn_ui/shadcn_ui.dart';
import 'package:flutter_toastr/flutter_toastr.dart';
import 'package:lico_proxy/l10n/app_localizations.dart';
import 'package:lico_proxy/network/bin/server.dart';
import 'package:lico_proxy/network/components/host_filter.dart';
import 'package:lico_proxy/network/components/manager/request_rewrite_manager.dart';
import 'package:lico_proxy/network/http/http.dart';
import 'package:lico_proxy/network/util/system_proxy.dart';
import 'package:lico_proxy/storage/histories.dart';
import 'package:lico_proxy/ui/toolbox/toolbox.dart';
import 'package:lico_proxy/ui/toolbox/json_viewer.dart';
import 'package:lico_proxy/ui/toolbox/js_run.dart';
import 'package:lico_proxy/ui/component/utils.dart';
import 'package:lico_proxy/ui/configuration.dart';
import 'package:lico_proxy/ui/mobile/shad/shad_design.dart';
import 'package:lico_proxy/ui/mobile/setting/preference.dart';
import 'package:lico_proxy/ui/mobile/request/favorite.dart';
import 'package:lico_proxy/ui/mobile/request/history.dart';
import 'package:lico_proxy/ui/mobile/setting/app_filter.dart';
import 'package:lico_proxy/ui/mobile/setting/filter.dart';
import 'package:lico_proxy/ui/mobile/setting/target_app.dart';
import 'package:lico_proxy/ui/mobile/setting/request_rewrite.dart';
import 'package:lico_proxy/ui/mobile/setting/ssl.dart';
import 'package:lico_proxy/ui/mobile/widgets/about.dart';
import 'package:lico_proxy/network/mcp/mcp_server.dart';
import 'package:lico_proxy/ui/mobile/setting/mcp_server_page.dart';
import 'package:lico_proxy/utils/listenable_list.dart';

import '../../component/proxy_port_setting.dart';
import '../../component/widgets.dart';
import '../../desktop/setting/external_proxy.dart';

/// 侧边栏头部：应用图标 + 应用名 + 版本号
Widget _drawerHeader(BuildContext context) {
  final scheme = ShadTheme.of(context).colorScheme;
  return Container(
    height: 172,
    width: double.infinity,
    decoration: BoxDecoration(
      color: scheme.card,
      border: Border(bottom: BorderSide(color: scheme.border.withValues(alpha: 0.6), width: 0.5)),
    ),
    child: Stack(
      children: [
        // 居中应用图标
        Center(
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.08),
                  blurRadius: 14,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(20),
              child: Image.asset('assets/icon.png', width: 76, height: 76, fit: BoxFit.cover),
            ),
          ),
        ),
        // 左下：应用名 + 版本
        Positioned(
          left: 16,
          bottom: 14,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('小离Proxy', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, height: 1.2)),
              const SizedBox(height: 2),
              Text('v${AppConfiguration.version}',
                  style: TextStyle(fontSize: 12, color: scheme.mutedForeground, height: 1.2)),
            ],
          ),
        ),
      ],
    ),
  );
}

/// 侧边栏菜单行（shadcn ShadTile 封装）
Widget _menuRow(
  BuildContext context, {
  required IconData icon,
  required String label,
  VoidCallback? onTap,
  Widget? trailing,
  bool showDivider = true,
}) {
  return ShadTile(
    icon: icon,
    title: label,
    onTap: onTap,
    trailing: trailing ?? const Icon(LucideIcons.chevronRight, size: 16),
    showDivider: showDivider,
  );
}

/// MCP Server 行：带 Switch 开关，点击进入管理页
Widget _mcpRow(BuildContext ctx) {
  final McpServer mcp = McpServer.instance;
  return StatefulBuilder(
    builder: (BuildContext context, StateSetter setSb) {
      return ShadTile(
        icon: LucideIcons.network,
        title: 'MCP Server',
        showDivider: true,
        trailing: ShadSwitch(
          value: mcp.isRunning,
          onChanged: (v) async {
            try {
              if (v) {
                await mcp.start();
              } else {
                await mcp.stop();
              }
            } catch (e) {
              if (ctx.mounted) FlutterToastr.show('MCP 启动失败: $e', ctx);
            }
            setSb(() {});
          },
        ),
        onTap: () => navigator(ctx, const McpServerPage()),
      );
    },
  );
}

/// 打开工具箱
void _openToolbox(BuildContext ctx, ProxyServer proxyServer) {
  Navigator.of(ctx).push(MaterialPageRoute(
      builder: (_) => Scaffold(appBar: ShadHeader(title: '工具箱'), body: Toolbox(proxyServer: proxyServer))));
}

/// 打开设置
void _openSetting(BuildContext ctx, ProxyServer proxyServer) {
  navigator(
      ctx,
      futureWidget(AppConfiguration.instance,
          (appConfiguration) => _SettingPage(proxyServer: proxyServer, appConfiguration: appConfiguration)));
}

/// 左侧抽屉
class DrawerWidget extends StatelessWidget {
  final ProxyServer proxyServer;
  final ListenableList<HttpRequest> container;
  final HistoryTask historyTask;

  DrawerWidget({super.key, required this.proxyServer, required this.container})
      : historyTask = HistoryTask.ensureInstance(proxyServer.configuration, container);

  @override
  Widget build(BuildContext context) {
    final scheme = ShadTheme.of(context).colorScheme;
    return Drawer(
        width: MediaQuery.of(context).size.width * 0.86,
        backgroundColor: scheme.background,
        shape: const RoundedRectangleBorder(),
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            _drawerHeader(context),
            const SizedBox(height: 8),
            // ===== 主要功能入口 =====
            ShadSection(
              margin: const EdgeInsets.symmetric(horizontal: 12),
              children: [
                _menuRow(context,
                    icon: LucideIcons.star,
                    label: '收藏',
                    onTap: () => navigator(context, MobileFavorites(proxyServer: proxyServer))),
                _menuRow(context,
                    icon: LucideIcons.history,
                    label: '历史记录',
                    onTap: () => navigator(context,
                        MobileHistory(proxyServer: proxyServer, container: container, historyTask: historyTask))),
                _menuRow(context, icon: LucideIcons.squarePen, label: '请求重写', showDivider: false, onTap: () async {
                  var m = await RequestRewriteManager.instance;
                  if (!context.mounted) return;
                  navigator(context, MobileRequestRewrite(requestRewrites: m));
                }),
              ],
            ),
            // ===== 抓包与转发 =====
            ShadSection(
              margin: const EdgeInsets.only(left: 12, right: 12, bottom: 14),
              children: [
                _menuRow(context,
                    icon: LucideIcons.appWindow,
                    label: '目标应用',
                    onTap: () => navigator(context, TargetAppPage(proxyServer: proxyServer))),
                _menuRow(context,
                    icon: LucideIcons.shieldCheck,
                    label: '黑白名单',
                    onTap: () => navigator(context, FilterMenu(proxyServer: proxyServer))),
                _mcpRow(context),
                _menuRow(context,
                    icon: LucideIcons.wrench, label: '工具箱', onTap: () => _openToolbox(context, proxyServer)),
                _menuRow(context,
                    icon: LucideIcons.braces, label: 'JSON', onTap: () => navigator(context, const JsonViewerPage())),
                _menuRow(context,
                    icon: LucideIcons.fileCode2,
                    label: 'JavaScript',
                    showDivider: false,
                    onTap: () => navigator(context, const JavaScript())),
              ],
            ),
            // ===== 设置 =====
            ShadSection(
              margin: const EdgeInsets.only(left: 12, right: 12, bottom: 20),
              children: [
                _menuRow(context,
                    icon: LucideIcons.settings,
                    label: '设置',
                    showDivider: false,
                    onTap: () => _openSetting(context, proxyServer)),
              ],
            ),
          ],
        ));
  }
}

/// 跳转页面
void navigator(BuildContext context, Widget widget) {
  Navigator.of(context).push(
    MaterialPageRoute(builder: (BuildContext context) {
      return widget;
    }),
  );
}

class _SettingPage extends StatelessWidget {
  final ProxyServer proxyServer;
  final AppConfiguration appConfiguration;

  const _SettingPage({required this.proxyServer, required this.appConfiguration});

  @override
  Widget build(BuildContext context) {
    final configuration = proxyServer.configuration;
    var textEditingController = TextEditingController(text: configuration.proxyPassDomains);

    AppLocalizations localizations = AppLocalizations.of(context)!;
    bool isCN = Localizations.localeOf(context) == const Locale.fromSubtags(languageCode: 'zh');

    return Scaffold(
        appBar: ShadHeader(title: localizations.setting),
        body: ListView(padding: const EdgeInsets.all(12), children: [
          // 端口与开关
          ShadSection(children: [
            PortWidget(
                proxyServer: proxyServer,
                title: '${localizations.proxy}${isCN ? '' : ' '}${localizations.port}',
                textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500)),
            if (Platform.isAndroid)
              ShadTile(
                title: localizations.systemProxy,
                trailing: SwitchWidget(
                    value: configuration.enableSystemProxy,
                    scale: 0.8,
                    onChanged: (value) {
                      configuration.enableSystemProxy = value;
                      proxyServer.configuration.flushConfig();
                    }),
              ),
            ShadTile(
              title: 'SOCKS5',
              trailing: SwitchWidget(
                  value: configuration.enableSocks5,
                  scale: 0.8,
                  onChanged: (value) {
                    configuration.enableSocks5 = value;
                    proxyServer.configuration.flushConfig();
                  }),
            ),
            ShadTile(
              title: localizations.enabledHTTP2,
              trailing: SwitchWidget(
                  value: configuration.enabledHttp2,
                  scale: 0.8,
                  onChanged: (value) {
                    configuration.enabledHttp2 = value;
                    proxyServer.configuration.flushConfig();
                  }),
            ),
            ShadTile(
              title: localizations.externalProxy,
              onTap: () {
                showDialog(
                    context: context, builder: (_) => ExternalProxyDialog(configuration: proxyServer.configuration));
              },
            ),
            // 忽略代理的域名
            Padding(
                padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
                child: Row(children: [
                  Expanded(
                      child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(localizations.proxyIgnoreDomain, style: const TextStyle(fontSize: 14)),
                      const SizedBox(height: 3),
                      Text(isCN ? "多个使用;分割" : "Use ';' to separate multiple entries",
                          style: TextStyle(fontSize: 11, color: ShadTheme.of(context).colorScheme.mutedForeground)),
                    ],
                  )),
                  ShadButton.ghost(
                    size: ShadButtonSize.sm,
                    onPressed: () {
                      textEditingController.text = SystemProxy.proxyPassDomains;
                    },
                    child: Text(localizations.reset),
                  ),
                ])),
            Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 14),
                child: TextField(
                    textInputAction: TextInputAction.done,
                    style: const TextStyle(fontSize: 13),
                    controller: textEditingController,
                    onSubmitted: (_) {
                      configuration.proxyPassDomains = textEditingController.text;
                      proxyServer.configuration.flushConfig();
                    },
                    decoration: const InputDecoration(contentPadding: EdgeInsets.all(10), border: OutlineInputBorder()),
                    maxLines: 5,
                    minLines: 1)),
          ]),
          ShadSection(children: [
            ShadTile(
                title: localizations.preference,
                onTap: () =>
                    navigator(context, Preference(proxyServer: proxyServer, appConfiguration: appConfiguration))),
            ShadTile(title: localizations.about, onTap: () => navigator(context, const About())),
          ]),
          // HTTPS 代理（从工具箱搬入设置）
          ShadSection(children: [
            ShadTile(
              icon: LucideIcons.lock,
              title: 'HTTPS代理',
              onTap: () => navigator(context, MobileSslWidget(proxyServer: proxyServer)),
              showDivider: false,
            ),
          ]),
          const SizedBox(height: 8),
        ]));
  }
}

/// 抓包过滤菜单
class FilterMenu extends StatelessWidget {
  final ProxyServer proxyServer;

  const FilterMenu({super.key, required this.proxyServer});

  @override
  Widget build(BuildContext context) {
    AppLocalizations localizations = AppLocalizations.of(context)!;

    return Scaffold(
        appBar: ShadHeader(title: localizations.filter),
        body: ListView(padding: const EdgeInsets.all(12), children: [
          ShadSection(margin: EdgeInsets.zero, children: [
            ShadTile(
                title: localizations.domainWhitelist,
                onTap: () => navigator(context,
                    MobileFilterWidget(configuration: proxyServer.configuration, hostList: HostFilter.whitelist))),
            ShadTile(
                title: localizations.domainBlacklist,
                onTap: () => navigator(context,
                    MobileFilterWidget(configuration: proxyServer.configuration, hostList: HostFilter.blacklist))),
            if (!Platform.isIOS)
              ShadTile(
                  title: localizations.appWhitelist,
                  onTap: () => navigator(context, AppWhitelist(proxyServer: proxyServer))),
            if (!Platform.isIOS)
              ShadTile(
                  title: localizations.appBlacklist,
                  showDivider: false,
                  onTap: () => navigator(context, AppBlacklist(proxyServer: proxyServer))),
          ]),
        ]));
  }
}
