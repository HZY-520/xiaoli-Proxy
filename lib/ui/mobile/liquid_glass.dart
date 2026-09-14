/*
 * 小离Proxy - 移动端视觉辅助模块
 *
 * 原为基于 liquid_glass_widgets 的液态玻璃实现，现已全面迁移到
 * shadcn 设计语言。此文件保留同名 API，避免大范围改动调用点，
 * 但内部实现已改为 shadcn 风格的纯色卡片与自适应文字/图标颜色。
 */

import 'package:flutter/material.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

import 'shad/shad_design.dart';

/// 背景层：shadcn 风格使用纯色背景，不再叠加渐变。
///
/// 保留此组件是为了兼容历史调用点。
class GlassBackground extends StatelessWidget {
  /// 可选子组件；传入时作为背景色的承载层包裹子组件
  final Widget? child;

  const GlassBackground({super.key, this.child});

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: ShadTheme.of(context).colorScheme.background,
      child: child ?? const SizedBox.expand(),
    );
  }
}

/// 分组区块：等价于 shadcn 的 Card，内部按行 + 细分隔线排列。
///
/// 参数名保留 `glassSection` 以兼容原有调用点。
Widget glassSection(BuildContext context, List<Widget> children, {EdgeInsetsGeometry? margin}) {
  return ShadSection(
    margin: margin ?? const EdgeInsets.only(bottom: 14),
    children: children,
  );
}

/// 适配亮/暗模式的图标颜色
Color glassIconColor(BuildContext context) => ShadTheme.of(context).colorScheme.mutedForeground;

/// 适配亮/暗模式的文字颜色
Color glassTextColor(BuildContext context) => ShadTheme.of(context).colorScheme.foreground;
