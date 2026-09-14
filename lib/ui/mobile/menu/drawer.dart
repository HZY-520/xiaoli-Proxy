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
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_toastr/flutter_toastr.dart';
import 'package:proxypin/l10n/app_localizations.dart';
import 'package:proxypin/network/bin/server.dart';
import 'package:proxypin/network/components/host_filter.dart';
import 'package:proxypin/network/components/manager/request_rewrite_manager.dart';
import 'package:proxypin/network/http/http.dart';
import 'package:proxypin/network/util/system_proxy.dart';
import 'package:proxypin/storage/histories.dart';
import 'package:proxypin/ui/toolbox/toolbox.dart';
import 'package:proxypin/ui/toolbox/json_viewer.dart';
import 'package:proxypin/ui/toolbox/js_run.dart';
import 'package:proxypin/ui/component/utils.dart';
import 'package:proxypin/ui/configuration.dart';
import 'package:proxypin/ui/mobile/setting/preference.dart';
import 'package:proxypin/ui/mobile/request/favorite.dart';
import 'package:proxypin/ui/mobile/request/history.dart';
import 'package:proxypin/ui/mobile/setting/app_filter.dart';
import 'package:proxypin/ui/mobile/setting/filter.dart';
import 'package:proxypin/ui/mobile/setting/target_app.dart';
import 'package:proxypin/ui/mobile/setting/request_rewrite.dart';
import 'package:proxypin/ui/mobile/setting/ssl.dart';
import 'package:proxypin/ui/mobile/widgets/about.dart';
import 'package:proxypin/network/mcp/mcp_server.dart';
import 'package:proxypin/ui/mobile/setting/mcp_server_page.dart';
import 'package:proxypin/utils/listenable_list.dart';

import '../../component/proxy_port_setting.dart';
import '../../component/widgets.dart';
import '../../desktop/setting/external_proxy.dart';

/// HttpCanary 复刻：侧边栏配色与图标
const Color _hcMenuText = Color(0xFF333333);
const Color _hcMenuIcon = Color(0xFF757575);
const String _hcLogo = 'assets/hc_icons/APKTOOL_RENAMED_0x7f08016e.svg';
const String _hcFavorites = 'assets/hc_icons/APKTOOL_RENAMED_0x7f080159.svg'; // 收藏
const String _hcHistory = 'assets/hc_icons/APKTOOL_RENAMED_0x7f08015c.svg'; // 历史记录
const String _hcTargetApp = 'assets/hc_icons/APKTOOL_RENAMED_0x7f080167.svg'; // 目标应用
const String _hcBlackWhite = 'assets/hc_icons/APKTOOL_RENAMED_0x7f080168.svg'; // 黑白名单
const String _hcToolbox = 'assets/hc_icons/APKTOOL_RENAMED_0x7f080169.svg'; // 工具箱
const String _hcSetting = 'assets/hc_icons/APKTOOL_RENAMED_0x7f080164.svg'; // 设置
// 样式 0x7f1200e6：15sp / #333333 / padding 20dp；分割线 #f3f3f3；图标灰 #757575
const Color _hcDivider = Color(0xFFF3F3F3);

/// HttpCanary 矢量图标（统一灰色调）
Widget _hcSvg(String asset, {double size = 24}) => SvgPicture.asset(asset,
    width: size,
    height: size,
    colorFilter: ColorFilter.mode(_hcMenuIcon, BlendMode.srcIn),
    fit: BoxFit.contain);

/// HttpCanary 风格侧边栏头部：header_bg 背景 + 居中白色纸飞机 logo + 免费版/版本号
Widget _hcDrawerHeader() {
  return Container(
    height: 180,
    decoration: const BoxDecoration(
      image: DecorationImage(
        image: AssetImage('assets/header_bg.png'),
        fit: BoxFit.cover,
      ),
    ),
    child: Stack(
      children: [
        Center(
          child: SvgPicture.asset(_hcLogo, width: 72, height: 72,
              colorFilter: ColorFilter.mode(Colors.white, BlendMode.srcIn)),
        ),
        Positioned(
          left: 16,
          bottom: 14,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('免费版',
                  style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold)),
              const SizedBox(height: 2),
              const Text('v3.3.6',
                  style: TextStyle(color: Colors.white, fontSize: 13)),
            ],
          ),
        ),
      ],
    ),
  );
}

/// 原版分割线：1dp 高 #f3f3f3，上下各 2dp 间距（参考图2紧凑样式）
Widget _hcDividerWidget() => const Padding(
      padding: EdgeInsets.symmetric(vertical: 2),
      child: Divider(thickness: 1, height: 1, color: _hcDivider),
    );

/// HttpCanary 菜单行：灰色图标 + 文字（样式 0x7f1200e6：15sp #333333 / padding 20dp / 图标间距 20dp）
Widget _hcRow(String icon, String label, {VoidCallback? onTap, Widget? trailing}) {
  return ListTile(
    leading: _hcSvg(icon),
    title: Text(label),
    trailing: trailing,
    onTap: onTap,
    contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
    horizontalTitleGap: 20,
    minLeadingWidth: 24,
    visualDensity: VisualDensity.compact,
  );
}

/// HttpCanary 风格 MCP Server 行：带 Switch 开关，点击进入管理页
Widget _hcMcpRow(BuildContext ctx) {
  final McpServer mcp = McpServer.instance;
  return StatefulBuilder(
    builder: (BuildContext context, StateSetter setSb) {
      return ListTile(
        leading: Icon(Icons.hub_outlined, color: _hcMenuIcon, size: 24),
        title: const Text('MCP Server'),
        trailing: Switch(
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
        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
        horizontalTitleGap: 20,
        minLeadingWidth: 24,
        visualDensity: VisualDensity.compact,
      );
    },
  );
}

/// 打开工具箱
void _hcOpenToolbox(BuildContext ctx, ProxyServer proxyServer) {
  Navigator.of(ctx).push(MaterialPageRoute(
      builder: (_) => Scaffold(
          appBar: AppBar(
            title: const Text('工具箱'),
            centerTitle: true,
            backgroundColor: const Color(0xFFFF9E05),
            foregroundColor: Colors.white,
            elevation: 0,
          ),
          body: Toolbox(proxyServer: proxyServer))));
}

/// 打开设置
void _hcOpenSetting(BuildContext ctx, ProxyServer proxyServer) {
  navigator(ctx, futureWidget(AppConfiguration.instance,
      (appConfiguration) => _SettingPage(proxyServer: proxyServer, appConfiguration: appConfiguration)));
}

///左侧抽屉
class DrawerWidget extends StatelessWidget {
  final ProxyServer proxyServer;
  final ListenableList<HttpRequest> container;
  final HistoryTask historyTask;

  DrawerWidget({super.key, required this.proxyServer, required this.container})
      : historyTask = HistoryTask.ensureInstance(proxyServer.configuration, container);

  @override
  Widget build(BuildContext context) {
    return Drawer(
        width: MediaQuery.of(context).size.width * 0.92,
        backgroundColor: Theme.of(context).cardColor,
        child: DefaultTextStyle(
          style: TextStyle(color: _hcMenuText, fontSize: 15),
          child: ListTileTheme(
            iconColor: _hcMenuIcon,
            child: ListView(
              padding: EdgeInsets.zero,
              children: [
                _hcDrawerHeader(),
            // ===== 保留 9 项（用户要求去掉高级版/使用教程/去评分/分享应用/用户许可协议）=====
            _hcRow(_hcFavorites, '收藏', onTap: () => navigator(context, MobileFavorites(proxyServer: proxyServer))),
            _hcRow(_hcHistory, '历史记录',
                onTap: () => navigator(context,
                    MobileHistory(proxyServer: proxyServer, container: container, historyTask: historyTask))),
            // 插件管理 → 替换为「请求重写」（功能从工具箱搬出到侧边栏）
            ListTile(
              leading: Icon(Icons.edit_outlined, color: _hcMenuIcon, size: 24),
              title: const Text('请求重写'),
              onTap: () async {
                var m = await RequestRewriteManager.instance;
                if (!context.mounted) return;
                navigator(context, MobileRequestRewrite(requestRewrites: m));
              },
              contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
              horizontalTitleGap: 20,
              minLeadingWidth: 24,
              visualDensity: VisualDensity.compact,
            ),
            _hcDividerWidget(),
            _hcRow(_hcTargetApp, '目标应用', onTap: () => navigator(context, TargetAppPage(proxyServer: proxyServer))),
            _hcRow(_hcBlackWhite, '黑白名单', onTap: () => navigator(context, FilterMenu(proxyServer: proxyServer))),
            _hcMcpRow(context),
            _hcRow(_hcToolbox, '工具箱', onTap: () => _hcOpenToolbox(context, proxyServer)),
            // 工具箱下：JSON / JavaScript（从工具箱搬出）
            ListTile(
              leading: Icon(Icons.data_object, color: _hcMenuIcon, size: 24),
              title: const Text('JSON'),
              onTap: () => navigator(context, const JsonViewerPage()),
              contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
              horizontalTitleGap: 20,
              minLeadingWidth: 24,
              visualDensity: VisualDensity.compact,
            ),
            ListTile(
              leading: Icon(Icons.javascript, color: _hcMenuIcon, size: 24),
              title: const Text('JavaScript'),
              onTap: () => navigator(context, const JavaScript()),
              contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
              horizontalTitleGap: 20,
              minLeadingWidth: 24,
              visualDensity: VisualDensity.compact,
            ),
            _hcRow(_hcSetting, '设置', onTap: () => _hcOpenSetting(context, proxyServer)),
            const SizedBox(height: 20)
          ],
        )),
      ),
    );
  }
}

///跳转页面
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

    Widget section(List<Widget> tiles) => Card(
          color: Colors.transparent,
          elevation: 0,
          shape: RoundedRectangleBorder(
              side: BorderSide(color: Theme.of(context).dividerColor.withValues(alpha: 0.13)),
              borderRadius: BorderRadius.circular(10)),
          child: Column(children: tiles),
        );

    return Scaffold(
        appBar: PreferredSize(
            preferredSize: const Size.fromHeight(42),
            child: AppBar(
              title: Text(localizations.setting, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w400)),
              centerTitle: true,
            )),
        body: ListView(padding: const EdgeInsets.all(12), children: [
          // Port and switches
          Card(
              color: Colors.transparent,
              elevation: 0,
              shape: RoundedRectangleBorder(
                  side: BorderSide(color: Theme.of(context).dividerColor.withValues(alpha: 0.13)),
                  borderRadius: BorderRadius.circular(10)),
              child: Column(children: [
                PortWidget(
                    proxyServer: proxyServer,
                    title: '${localizations.proxy}${isCN ? '' : ' '}${localizations.port}',
                    textStyle: const TextStyle(fontSize: 16)),
                Divider(height: 0, thickness: 0.3, color: Theme.of(context).dividerColor.withValues(alpha: 0.22)),
                if (Platform.isAndroid)
                  ListTile(
                      title: Text(localizations.systemProxy),
                      trailing: SwitchWidget(
                          value: configuration.enableSystemProxy,
                          scale: 0.8,
                          onChanged: (value) {
                            configuration.enableSystemProxy = value;
                            proxyServer.configuration.flushConfig();
                          })),
                if (Platform.isAndroid)
                  Divider(height: 0, thickness: 0.3, color: Theme.of(context).dividerColor.withValues(alpha: 0.22)),
                ListTile(
                    title: const Text("SOCKS5"),
                    trailing: SwitchWidget(
                        value: configuration.enableSocks5,
                        scale: 0.8,
                        onChanged: (value) {
                          configuration.enableSocks5 = value;
                          proxyServer.configuration.flushConfig();
                        })),
                Divider(height: 0, thickness: 0.3, color: Theme.of(context).dividerColor.withValues(alpha: 0.22)),
                ListTile(
                    title: Text(localizations.enabledHTTP2),
                    trailing: SwitchWidget(
                        value: configuration.enabledHttp2,
                        scale: 0.8,
                        onChanged: (value) {
                          configuration.enabledHttp2 = value;
                          proxyServer.configuration.flushConfig();
                        })),
                Divider(height: 0, thickness: 0.3, color: Theme.of(context).dividerColor.withValues(alpha: 0.22)),
                ListTile(
                    title: Text(localizations.externalProxy),
                    trailing: const Icon(Icons.keyboard_arrow_right),
                    onTap: () {
                      showDialog(
                          context: context,
                          builder: (_) => ExternalProxyDialog(configuration: proxyServer.configuration));
                    }),
                Divider(height: 0, thickness: 0.3, color: Theme.of(context).dividerColor.withValues(alpha: 0.22)),
                Padding(
                    padding: const EdgeInsets.only(left: 15),
                    child: Row(children: [
                      Expanded(
                          child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(localizations.proxyIgnoreDomain, style: const TextStyle(fontSize: 14)),
                          const SizedBox(height: 3),
                          Text(isCN ? "多个使用;分割" : "Use ';' to separate multiple entries",
                              style: TextStyle(fontSize: 11, color: Colors.grey.shade600)),
                        ],
                      )),
                      Padding(
                          padding: const EdgeInsets.only(left: 35),
                          child: TextButton(
                            child: Text(localizations.reset),
                            onPressed: () {
                              textEditingController.text = SystemProxy.proxyPassDomains;
                            },
                          ))
                    ])),
                const SizedBox(height: 5),
                Padding(
                    padding: const EdgeInsets.only(left: 15, right: 5),
                    child: TextField(
                        textInputAction: TextInputAction.done,
                        style: const TextStyle(fontSize: 13),
                        controller: textEditingController,
                        onSubmitted: (_) {
                          configuration.proxyPassDomains = textEditingController.text;
                          proxyServer.configuration.flushConfig();
                        },
                        decoration:
                            const InputDecoration(contentPadding: EdgeInsets.all(10), border: OutlineInputBorder()),
                        maxLines: 5,
                        minLines: 1)),
                const SizedBox(height: 10),
              ])),
          const SizedBox(height: 12),
          section([
            ListTile(
                title: Text(localizations.preference),
                trailing: const Icon(Icons.keyboard_arrow_right),
                onTap: () =>
                    navigator(context, Preference(proxyServer: proxyServer, appConfiguration: appConfiguration))),
            Divider(height: 0, thickness: 0.3, color: Theme.of(context).dividerColor.withValues(alpha: 0.22)),
            ListTile(
                title: Text(localizations.about),
                trailing: const Icon(Icons.keyboard_arrow_right),
                onTap: () => navigator(context, const About())),
          ]),
          const SizedBox(height: 12),
          // HTTPS 代理（从工具箱搬入设置）
          section([
            ListTile(
              leading: const Icon(Icons.lock_outline, color: _hcMenuIcon, size: 24),
              title: const Text('HTTPS代理'),
              trailing: const Icon(Icons.keyboard_arrow_right),
              onTap: () => navigator(context, MobileSslWidget(proxyServer: proxyServer)),
            ),
          ]),
          const SizedBox(height: 8),
        ]));
  }
}

///抓包过滤菜单
class FilterMenu extends StatelessWidget {
  final ProxyServer proxyServer;

  const FilterMenu({super.key, required this.proxyServer});

  @override
  Widget build(BuildContext context) {
    AppLocalizations localizations = AppLocalizations.of(context)!;

    return Scaffold(
        appBar: AppBar(title: Text(localizations.filter, style: const TextStyle(fontSize: 16)), centerTitle: true),
        body: Padding(
            padding: const EdgeInsets.all(12),
            child: Card(
                color: Colors.transparent,
                elevation: 0,
                shape: RoundedRectangleBorder(
                    side: BorderSide(color: Theme.of(context).dividerColor.withValues(alpha: 0.13)),
                    borderRadius: BorderRadius.circular(10)),
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  ListTile(
                      title: Text(localizations.domainWhitelist),
                      trailing: const Icon(Icons.arrow_right),
                      onTap: () => navigator(
                          context,
                          MobileFilterWidget(
                              configuration: proxyServer.configuration, hostList: HostFilter.whitelist))),
                  Divider(height: 0, thickness: 0.4, color: Theme.of(context).dividerColor.withValues(alpha: 0.22)),
                  ListTile(
                      title: Text(localizations.domainBlacklist),
                      trailing: const Icon(Icons.arrow_right),
                      onTap: () => navigator(
                          context,
                          MobileFilterWidget(
                              configuration: proxyServer.configuration, hostList: HostFilter.blacklist))),
                  Platform.isIOS
                      ? const SizedBox()
                      : Column(mainAxisSize: MainAxisSize.min, children: [
                          Divider(
                              height: 0, thickness: 0.4, color: Theme.of(context).dividerColor.withValues(alpha: 0.22)),
                          ListTile(
                              title: Text(localizations.appWhitelist),
                              trailing: const Icon(Icons.arrow_right),
                              onTap: () => navigator(context, AppWhitelist(proxyServer: proxyServer))),
                          Divider(
                              height: 0, thickness: 0.4, color: Theme.of(context).dividerColor.withValues(alpha: 0.22)),
                          ListTile(
                              title: Text(localizations.appBlacklist),
                              trailing: const Icon(Icons.arrow_right),
                              onTap: () => navigator(context, AppBlacklist(proxyServer: proxyServer)))
                        ])
                ]))));
  }
}
