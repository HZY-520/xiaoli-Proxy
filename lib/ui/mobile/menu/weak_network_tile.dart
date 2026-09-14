/*
 * Copyright 2026 Hongen Wang
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *      https://www.apache.org/licenses/LICENSE-2.0
 */

import 'package:flutter/material.dart';
import 'package:shadcn_ui/shadcn_ui.dart';
import 'package:lico_proxy/l10n/app_localizations.dart';
import 'package:lico_proxy/network/components/manager/network_condition_manager.dart';
import 'package:lico_proxy/ui/mobile/shad/shad_design.dart';
import 'package:lico_proxy/ui/mobile/setting/weak_network.dart';

/// 手机端「网络限制」入口（shadcn 重构版）
///
/// 用于抽屉菜单和底部导航配置页共用；启用时在标题旁展示一个小圆点，
/// 提醒用户当前网络已被人为限速，避免"网络怎么变慢了"的困惑。
///
/// [icon] 前置图标，默认使用限速图标；
/// [trailing] 右侧组件，默认无（配置页不需要箭头）。
class WeakNetworkMenuTile extends StatefulWidget {
  final IconData? icon;
  final Widget? trailing;

  const WeakNetworkMenuTile({super.key, this.icon, this.trailing});

  @override
  State<WeakNetworkMenuTile> createState() => _WeakNetworkMenuTileState();
}

class _WeakNetworkMenuTileState extends State<WeakNetworkMenuTile> {
  NetworkConditionManager? _manager;

  @override
  void initState() {
    super.initState();
    NetworkConditionManager.instance.then((m) {
      if (!mounted) return;
      setState(() => _manager = m);
      m.addListener(_onChanged);
    });
  }

  @override
  void dispose() {
    _manager?.removeListener(_onChanged);
    super.dispose();
  }

  void _onChanged() {
    if (mounted) setState(() {});
  }

  int get _activeRuleCount => _manager?.rules.where((r) => r.enabled).length ?? 0;

  bool get _isActive => (_manager?.enabled ?? false) && _activeRuleCount > 0;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final scheme = ShadTheme.of(context).colorScheme;

    // 生效时给标题带一个圆点徽标，视觉上等同于桌面端工具栏指示器
    final title = _isActive
        ? Row(mainAxisSize: MainAxisSize.min, children: [
            Text(l10n.weakNetwork),
            const SizedBox(width: 8),
            Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(color: scheme.primary, shape: BoxShape.circle),
            ),
          ])
        : Text(l10n.weakNetwork);

    return ShadTile(
      titleWidget: title,
      icon: widget.icon ?? LucideIcons.gauge,
      trailing: widget.trailing,
      onTap: () async {
        final m = _manager ?? await NetworkConditionManager.instance;
        if (context.mounted) {
          Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => MobileWeakNetwork(manager: m)),
          );
        }
      },
    );
  }
}
