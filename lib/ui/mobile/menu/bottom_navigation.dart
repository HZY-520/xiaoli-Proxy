/*
 * 小离Proxy - 配置页 / 设置页（shadcn 重构版）
 *
 * 视觉层改用 shadcn_ui 的 ShadHeader + ShadSection + ShadTile，
 * 移除了液态玻璃容器依赖。所有跳转目标与配置读写逻辑保持不变。
 */
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:shadcn_ui/shadcn_ui.dart';
import 'package:lico_proxy/l10n/app_localizations.dart';
import 'package:lico_proxy/network/bin/server.dart';
import 'package:lico_proxy/network/components/manager/hosts_manager.dart';
import 'package:lico_proxy/network/components/manager/request_block_manager.dart';
import 'package:lico_proxy/network/components/manager/request_rewrite_manager.dart';
import 'package:lico_proxy/network/util/system_proxy.dart';
import 'package:lico_proxy/storage/histories.dart';
import 'package:lico_proxy/ui/component/proxy_port_setting.dart';
import 'package:lico_proxy/ui/configuration.dart';
import 'package:lico_proxy/ui/mobile/shad/shad_design.dart';
import 'package:lico_proxy/ui/mobile/menu/drawer.dart';
import 'package:lico_proxy/ui/mobile/menu/weak_network_tile.dart';
import 'package:lico_proxy/ui/mobile/setting/environment.dart';
import 'package:lico_proxy/ui/mobile/setting/hosts.dart';
import 'package:lico_proxy/ui/mobile/setting/preference.dart';
import 'package:lico_proxy/ui/mobile/mobile.dart';
import 'package:lico_proxy/ui/mobile/request/favorite.dart';
import 'package:lico_proxy/ui/mobile/request/history.dart';
import 'package:lico_proxy/ui/mobile/setting/request_block.dart';
import 'package:lico_proxy/ui/mobile/setting/request_crypto.dart';
import 'package:lico_proxy/ui/mobile/setting/request_rewrite.dart';
import 'package:lico_proxy/ui/mobile/setting/script.dart';
import 'package:lico_proxy/ui/mobile/setting/ssl.dart';
import 'package:lico_proxy/ui/mobile/widgets/about.dart';
import 'package:lico_proxy/ui/mobile/setting/request_breakpoint.dart';

import '../../../network/components/manager/request_breakpoint_manager.dart';
import '../../component/widgets.dart';
import '../setting/proxy.dart';
import '../setting/request_map.dart';

/// @author wanghongen
/// 2024/9/30
class ConfigPage extends StatefulWidget {
  final ProxyServer proxyServer;

  const ConfigPage({super.key, required this.proxyServer});

  @override
  State<StatefulWidget> createState() => _ConfigPageState();
}

class _ConfigPageState extends State<ConfigPage> {
  late ProxyServer proxyServer = widget.proxyServer;
  late HistoryTask historyTask;

  @override
  void initState() {
    super.initState();
    historyTask = HistoryTask.ensureInstance(proxyServer.configuration, MobileApp.container);
  }

  @override
  Widget build(BuildContext context) {
    AppLocalizations localizations = AppLocalizations.of(context)!;

    return Scaffold(
        appBar: ShadHeader(title: localizations.config),
        body: ListView(
          padding: const EdgeInsets.all(12),
          children: [
            // ===== 抓包记录 =====
            ShadSection(children: [
              ShadTile(
                  icon: LucideIcons.star,
                  title: localizations.favorites,
                  onTap: () => navigator(context, MobileFavorites(proxyServer: proxyServer))),
              ShadTile(
                icon: LucideIcons.history,
                title: localizations.history,
                showDivider: false,
                onTap: () => navigator(context,
                    MobileHistory(proxyServer: proxyServer, container: MobileApp.container, historyTask: historyTask)),
              ),
            ]),
            // ===== 请求处理规则 =====
            ShadSection(children: [
              ShadTile(
                  icon: LucideIcons.server,
                  title: localizations.hosts,
                  onTap: () async {
                    var hostsManager = await HostsManager.instance;
                    if (context.mounted) {
                      navigator(context, HostsPage(hostsManager: hostsManager));
                    }
                  }),
              ShadTile(
                  icon: LucideIcons.ban,
                  title: localizations.requestBlock,
                  onTap: () async {
                    var requestBlockManager = await RequestBlockManager.instance;
                    if (context.mounted) {
                      navigator(context, MobileRequestBlock(requestBlockManager: requestBlockManager));
                    }
                  }),
              ShadTile(
                  icon: LucideIcons.squarePen,
                  title: localizations.requestRewrite,
                  onTap: () async {
                    var requestRewrites = await RequestRewriteManager.instance;
                    if (context.mounted) {
                      navigator(context, MobileRequestRewrite(requestRewrites: requestRewrites));
                    }
                  }),
              ShadTile(
                  icon: LucideIcons.arrowLeftRight,
                  title: localizations.requestMap,
                  onTap: () => navigator(context, MobileRequestMapPage())),
              ShadTile(
                  icon: LucideIcons.lock,
                  title: localizations.requestCrypto,
                  onTap: () => navigator(context, const MobileRequestCryptoPage())),
              ShadTile(
                  icon: LucideIcons.fileCode2,
                  title: localizations.script,
                  onTap: () => navigator(context, const MobileScript())),
              ShadTile(
                  icon: LucideIcons.bug,
                  title: localizations.breakpoint,
                  onTap: () async {
                    var manager = await RequestBreakpointManager.instance;
                    if (context.mounted) {
                      navigator(context, MobileRequestBreakpointPage(manager: manager));
                    }
                  }),
              WeakNetworkMenuTile(icon: LucideIcons.wifiOff),
              ShadTile(
                  icon: LucideIcons.globe,
                  title: localizations.environmentVariables,
                  showDivider: false,
                  onTap: () => navigator(context, const MobileEnvironmentPage())),
            ]),
            const SizedBox(height: 4),
          ],
        ));
  }
}

void navigator(BuildContext context, Widget widget) async {
  if (context.mounted) {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (BuildContext context) => widget),
    );
  }
}

class SettingPage extends StatelessWidget {
  final ProxyServer proxyServer;
  final AppConfiguration appConfiguration;

  const SettingPage({super.key, required this.proxyServer, required this.appConfiguration});

  @override
  Widget build(BuildContext context) {
    final configuration = proxyServer.configuration;

    var textEditingController = TextEditingController(text: configuration.proxyPassDomains);

    AppLocalizations localizations = AppLocalizations.of(context)!;
    bool isCN = Localizations.localeOf(context) == const Locale.fromSubtags(languageCode: 'zh');

    return Scaffold(
        appBar: ShadHeader(title: localizations.setting),
        body: ListView(padding: const EdgeInsets.all(12), children: [
          ShadSection(children: [
            ShadTile(
                title: localizations.httpsProxy,
                onTap: () => navigator(context, MobileSslWidget(proxyServer: proxyServer))),
            ShadTile(
                title: localizations.filter,
                showDivider: false,
                onTap: () => navigator(context, FilterMenu(proxyServer: proxyServer))),
          ]),
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
                      })),
            ShadTile(
                title: 'SOCKS5',
                trailing: SwitchWidget(
                    value: configuration.enableSocks5,
                    scale: 0.8,
                    onChanged: (value) {
                      configuration.enableSocks5 = value;
                      proxyServer.configuration.flushConfig();
                    })),
            ShadTile(
                title: localizations.enabledHTTP2,
                trailing: SwitchWidget(
                    value: configuration.enabledHttp2,
                    scale: 0.8,
                    onChanged: (value) {
                      configuration.enabledHttp2 = value;
                      proxyServer.configuration.flushConfig();
                    })),
            ShadTile(
                title: localizations.externalProxy,
                onTap: () {
                  showDialog(
                      context: context,
                      builder: (_) => ExternalProxyDialog(configuration: proxyServer.configuration));
                }),
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
                            style: TextStyle(
                                fontSize: 11, color: ShadTheme.of(context).colorScheme.mutedForeground)),
                      ],
                    ),
                  ),
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
                    decoration: const InputDecoration(
                      contentPadding: EdgeInsets.all(10),
                      border: OutlineInputBorder(),
                    ),
                    maxLines: 5,
                    minLines: 1)),
          ]),
          ShadSection(children: [
            ShadTile(
                title: localizations.setting,
                onTap: () =>
                    navigator(context, Preference(proxyServer: proxyServer, appConfiguration: appConfiguration))),
            ShadTile(
                title: localizations.about,
                showDivider: false,
                onTap: () => navigator(context, const About())),
          ]),
          const SizedBox(height: 8),
        ]));
  }
}
