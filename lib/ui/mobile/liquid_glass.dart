/*
 * 液态玻璃（Liquid Glass）UI 辅助模块
 * 基于 liquid_glass_widgets（iOS 26 Liquid Glass 设计语言）实现。
 * 仅用于安卓端（移动端）UI 视觉改造，不涉及任何功能逻辑。
 */

import 'package:flutter/material.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart';

/// 液态玻璃全局渐变背景：为所有玻璃表面提供“折射/模糊”的色彩来源。
class GlassBackground extends StatelessWidget {
  const GlassBackground({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: isDark
              ? const [Color(0xFF141E30), Color(0xFF243B55), Color(0xFF2C5364)]
              : const [Color(0xFFA1C4FD), Color(0xFFC2E9FB), Color(0xFFE0EAFC)],
        ),
      ),
      child: const SizedBox.expand(),
    );
  }
}

/// 玻璃分组卡片：替代设置页中原来的「透明 Card 区块」。
/// 外层玻璃卡片 + 内部保持原有 ListTile 内容与分割线。
Widget glassSection(BuildContext context, List<Widget> children,
    {EdgeInsetsGeometry? margin}) {
  return GlassCard(
    margin: margin ?? const EdgeInsets.only(bottom: 12),
    padding: EdgeInsets.zero,
    clipBehavior: Clip.antiAlias,
    child: Column(children: children),
  );
}

/// 适配亮/暗模式的玻璃图标颜色
Color glassIconColor(BuildContext context) =>
    Theme.of(context).brightness == Brightness.dark
        ? Colors.white
        : const Color(0xDD000000);

/// 适配亮/暗模式的玻璃文字颜色
Color glassTextColor(BuildContext context) =>
    Theme.of(context).brightness == Brightness.dark
        ? Colors.white
        : const Color(0xDD000000);
