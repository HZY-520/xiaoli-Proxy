/*
 * 小离Proxy - 关于页面
 *
 * 作者：离愁Lico
 * 基于 shadcn 设计系统重构
 */

import 'package:flutter/material.dart';
import 'package:shadcn_ui/shadcn_ui.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:lico_proxy/l10n/app_localizations.dart';
import 'package:lico_proxy/ui/configuration.dart';
import 'package:lico_proxy/ui/mobile/shad/shad_design.dart';

import '../../app_update/app_update_repository.dart';

/// 关于
class About extends StatefulWidget {
  const About({super.key});

  @override
  State<StatefulWidget> createState() {
    return _AboutState();
  }
}

class _AboutState extends State<About> {
  bool checkUpdating = false;

  static const String author = '离愁Lico';
  static const String repoUrl = 'https://github.com/HZY-520/xiaoli-Proxy';
  static const String upstreamUrl = 'https://github.com/wanghongenpin/proxypin';

  @override
  Widget build(BuildContext context) {
    AppLocalizations localizations = AppLocalizations.of(context)!;
    final scheme = ShadTheme.of(context).colorScheme;

    return Scaffold(
      appBar: ShadHeader(title: localizations.about),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(14, 18, 14, 28),
        children: [
          Column(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(22),
                child: Image.asset('assets/icon.png', width: 88, height: 88, fit: BoxFit.cover),
              ),
              const SizedBox(height: 14),
              const Text('小离Proxy', style: TextStyle(fontSize: 21, fontWeight: FontWeight.bold)),
              const SizedBox(height: 6),
              Text(localizations.proxyPinSoftware,
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 12.5, color: scheme.mutedForeground)),
              const SizedBox(height: 10),
              ShadTag('v${AppConfiguration.version}'),
            ],
          ),
          const SizedBox(height: 24),

          ShadSection(title: '作者', children: [
            const ShadTile(
              icon: LucideIcons.user,
              title: author,
              subtitle: '小离Proxy 作者 / 维护者',
              showDivider: false,
            ),
          ]),

          ShadSection(title: '开源信息', children: [
            const ShadTile(
              icon: LucideIcons.scale,
              title: '开源许可',
              subtitle: 'Apache License 2.0',
            ),
            ShadTile(
              icon: LucideIcons.code,
              title: '项目仓库',
              subtitle: 'GitHub - xiaoli-Proxy',
              trailing: const Icon(LucideIcons.externalLink, size: 16),
              onTap: () => _safeLaunch(Uri.parse(repoUrl)),
            ),
            ShadTile(
              icon: LucideIcons.gitFork,
              title: '上游项目',
              subtitle: 'ProxyPin（wanghongenpin）',
              trailing: const Icon(LucideIcons.externalLink, size: 16),
              onTap: () => _safeLaunch(Uri.parse(upstreamUrl)),
            ),
            ShadTile(
              icon: LucideIcons.fileText,
              title: '开源声明',
              subtitle: '本项目基于 ProxyPin 二次开发，遵循 Apache-2.0 协议开源',
              onTap: () => _showOpenSourceNotice(localizations),
              showDivider: false,
            ),
          ]),

          ShadSection(title: '支持与反馈', children: [
            ShadTile(
              icon: LucideIcons.messageSquare,
              title: localizations.feedback,
              subtitle: '问题反馈与建议',
              trailing: const Icon(LucideIcons.externalLink, size: 16),
              onTap: () => _safeLaunch(Uri.parse('$repoUrl/issues')),
            ),
            ShadTile(
              icon: LucideIcons.download,
              title: localizations.download,
              subtitle: '获取最新版本',
              trailing: const Icon(LucideIcons.externalLink, size: 16),
              onTap: () => _safeLaunch(Uri.parse('$repoUrl/releases')),
            ),
            ShadTile(
              icon: LucideIcons.refreshCw,
              title: localizations.appUpdateCheckVersion,
              subtitle: '检查是否有新版本',
              trailing: checkUpdating
                  ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(LucideIcons.chevronRight, size: 16),
              onTap: () async {
                if (checkUpdating) return;
                setState(() => checkUpdating = true);
                await AppUpdateRepository.checkUpdate(context, canIgnore: false, showToast: true);
                if (mounted) setState(() => checkUpdating = false);
              },
            ),
            ShadTile(
              icon: LucideIcons.shieldCheck,
              title: localizations.privacyPolicy,
              trailing: const Icon(LucideIcons.chevronRight, size: 16),
              onTap: () => _showPrivacy(localizations),
              showDivider: false,
            ),
          ]),

          const SizedBox(height: 6),
          Center(
            child: Text(
              'Copyright © 2024-2026 $author\nPowered by Flutter',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 11.5, color: scheme.mutedForeground, height: 1.6),
            ),
          ),
          const SizedBox(height: 14),
        ],
      ),
    );
  }

  Future<void> _safeLaunch(Uri uri) async {
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  void _showOpenSourceNotice(AppLocalizations l10n) {
    showShadDialog(
      context: context,
      builder: (ctx) => ShadDialog.alert(
        title: const Text('开源声明'),
        description: const Text(
          '小离Proxy 是基于 ProxyPin 二次开发的安卓端网络调试工具。\n\n'
          '• 上游项目：ProxyPin（wanghongenpin）\n'
          '• 开源协议：Apache License 2.0\n'
          '• 本项目作者：离愁Lico\n\n'
          '您可以在遵循 Apache-2.0 协议的前提下自由使用、修改和分发本项目源码，请保留原始版权与许可声明。',
          style: TextStyle(height: 1.6, fontSize: 13),
        ),
        actions: [
          ShadButton.outline(onPressed: () => Navigator.of(ctx).pop(), child: Text(l10n.close)),
        ],
      ),
    );
  }

  void _showPrivacy(AppLocalizations l10n) {
    showShadDialog(
      context: context,
      builder: (ctx) => ShadDialog.alert(
        title: Text(l10n.privacyPolicy),
        description: SingleChildScrollView(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 385),
            child: Text(l10n.privacyContent, style: const TextStyle(height: 1.5, fontSize: 13)),
          ),
        ),
        actions: [
          ShadButton.outline(onPressed: () => Navigator.of(ctx).pop(), child: Text(l10n.close)),
        ],
      ),
    );
  }
}
