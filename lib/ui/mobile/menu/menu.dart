/*
 * 小离Proxy - 顶栏更多菜单（shadcn 重构版）
 *
 * 由 PopupMenuButton 改为 shadcn 的 Popover，菜单项统一为 ShadTile 风格。
 * 所有菜单动作与原实现一致。
 */
import 'dart:io';

import 'package:date_format/date_format.dart';
import 'package:flutter/material.dart';
import 'package:shadcn_ui/shadcn_ui.dart';
import 'package:lico_proxy/l10n/app_localizations.dart';
import 'package:lico_proxy/network/bin/server.dart';
import 'package:lico_proxy/ui/mobile/mobile.dart';
import 'package:lico_proxy/ui/mobile/setting/app_filter.dart';
import 'package:lico_proxy/ui/mobile/setting/report_servers.dart';
import 'package:lico_proxy/ui/mobile/setting/ssl.dart';
import 'package:lico_proxy/ui/mobile/widgets/highlight.dart';
import 'package:lico_proxy/ui/mobile/widgets/remote_device.dart';

/// 顶栏「更多」菜单
class MoreMenu extends StatelessWidget {
  static bool sortDesc = true;

  final ProxyServer proxyServer;
  final ValueNotifier<RemoteModel> remoteDevice;

  const MoreMenu({super.key, required this.proxyServer, required this.remoteDevice});

  @override
  Widget build(BuildContext context) {
    AppLocalizations localizations = AppLocalizations.of(context)!;
    final scheme = ShadTheme.of(context).colorScheme;

    return ShadPopover(
      padding: const EdgeInsets.all(6),
      popover: (ctx) => SizedBox(
        width: 208,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _MenuItem(
              icon: proxyServer.enableSsl ? LucideIcons.lockOpen : LucideIcons.lock,
              iconColor: proxyServer.enableSsl ? null : scheme.destructive,
              label: localizations.httpsProxy,
              onTap: () => navigator(ctx, MobileSslWidget(proxyServer: proxyServer)),
            ),
            if (Platform.isAndroid)
              _MenuItem(
                icon: LucideIcons.smartphone,
                label: localizations.appWhitelist,
                onTap: () => navigator(ctx, AppWhitelist(proxyServer: proxyServer)),
              ),
            _MenuItem(
              icon: LucideIcons.monitorSmartphone,
              label: localizations.remoteDevice,
              onTap: () => navigator(ctx, RemoteDevicePage(proxyServer: proxyServer, remoteDevice: remoteDevice)),
            ),
            _MenuItem(
              icon: LucideIcons.cloudUpload,
              label: localizations.reportServers,
              onTap: () => navigator(ctx, const ReportServersPageMobile()),
            ),
            _MenuItem(
              icon: LucideIcons.search,
              label: localizations.search,
              onTap: () async {
                await Navigator.maybePop(ctx);
                MobileApp.searchStateKey.currentState?.showSearch();
              },
            ),
            Divider(height: 8, thickness: 0.5, color: scheme.border.withValues(alpha: 0.6)),
            _MenuItem(
              icon: LucideIcons.highlighter,
              label: '${localizations.keyword}${localizations.highlight}',
              onTap: () => navigator(ctx, const KeywordHighlight()),
            ),
            _MenuItem(
              icon: LucideIcons.share2,
              label: localizations.viewExport,
              onTap: () async {
                Navigator.maybePop(ctx);
                var name = formatDate(DateTime.now(), [m, '-', d, ' ', HH, ':', nn, ':', ss]);
                MobileApp.requestStateKey.currentState?.export(context, '小离Proxy$name');
              },
            ),
            _MenuItem(
              icon: LucideIcons.listChecks,
              label: localizations.select,
              onTap: () async {
                await Navigator.maybePop(ctx);
                MobileApp.multiSelectController.toggleSelectionMode();
              },
            ),
            _MenuItem(
              icon: LucideIcons.arrowUpDown,
              label: sortDesc ? localizations.timeAsc : localizations.timeDesc,
              onTap: () async {
                await Navigator.maybePop(ctx);
                sortDesc = !sortDesc;
                MobileApp.requestStateKey.currentState?.sort(sortDesc);
              },
            ),
          ],
        ),
      ),
      child: const ShadIconButton.ghost(
        icon: Icon(LucideIcons.ellipsisVertical, size: 22),
        width: 38,
        height: 38,
      ),
    );
  }

  void navigator(BuildContext context, Widget widget) async {
    await Navigator.maybePop(context);
    if (context.mounted) {
      Navigator.of(context).push(
        MaterialPageRoute(builder: (BuildContext context) => widget),
      );
    }
  }
}

/// 菜单项：紧凑的图标 + 文字行
class _MenuItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final Color? iconColor;

  const _MenuItem({required this.icon, required this.label, required this.onTap, this.iconColor});

  @override
  Widget build(BuildContext context) {
    final scheme = ShadTheme.of(context).colorScheme;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
        child: Row(
          children: [
            Icon(icon, size: 17, color: iconColor ?? scheme.mutedForeground),
            const SizedBox(width: 10),
            Expanded(
              child: Text(label,
                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis),
            ),
          ],
        ),
      ),
    );
  }
}
