/*
 * shadcn/ui 风格设计系统（安卓端）
 * 基于 flutter-shadcn-ui（shadcn_ui）设计语言实现。
 * 仅用于安卓端（移动端）UI 视觉改造，不涉及任何功能逻辑。
 *
 * 说明：
 * - 全局使用 shadcn 中性色板（背景 #FAFAFA / 卡片 #FFFFFF / 边框 #E4E4E7，暗色对应 zinc 系）。
 * - 此模块保留原有函数名以兼容各处调用（glassSection 等），但渲染为 shadcn 风格卡片。
 */

import 'package:flutter/material.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

/// shadcn 圆角半径（约 10dp，即 0.625rem）
const double shadcnRadius = 10;

/// 全局背景：shadcn 风格中性纯色背景。
class GlassBackground extends StatelessWidget {
  const GlassBackground({super.key});

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: Theme.of(context).brightness == Brightness.dark
              ? const [Color(0xFF09090B), Color(0xFF09090B)]
              : const [Color(0xFFFAFAFA), Color(0xFFFAFAFA)],
        ),
      ),
      child: const SizedBox.expand(),
    );
  }
}

/// shadcn 分组卡片：替换设置页中原来的「透明 Card 区块」。
/// 外层 ShadCard（白底 + 1px 边框 + 圆角）+ 内部保持原有 ListTile 内容与分割线。
Widget shadSection(BuildContext context, List<Widget> children,
    {EdgeInsetsGeometry? margin, EdgeInsetsGeometry? padding = EdgeInsets.zero}) {
  return Padding(
    padding: margin ?? const EdgeInsets.only(bottom: 12),
    child: ShadCard(
      padding: padding,
      radius: BorderRadius.circular(shadcnRadius),
      clipBehavior: Clip.antiAlias,
      child: Column(children: children),
    ),
  );
}

/// 兼容旧调用：glassSection 等价于 shadSection
Widget glassSection(BuildContext context, List<Widget> children,
    {EdgeInsetsGeometry? margin, EdgeInsetsGeometry? padding}) {
  return shadSection(context, children, margin: margin, padding: padding);
}

/// 适配亮/暗模式的图标颜色（shadcn 前景色）
Color glassIconColor(BuildContext context) => Theme.of(context).colorScheme.onSurface;

/// 适配亮/暗模式的文字颜色（shadcn 前景色）
Color glassTextColor(BuildContext context) => Theme.of(context).colorScheme.onSurface;

/// shadcn 次要文字颜色（muted-foreground）
Color shadMutedColor(BuildContext context) =>
    Theme.of(context).brightness == Brightness.dark ? const Color(0xFFA1A1AA) : const Color(0xFF71717A);

/// shadcn 边框颜色（border）
Color shadBorderColor(BuildContext context) =>
    Theme.of(context).brightness == Brightness.dark ? const Color(0xFF27272A) : const Color(0xFFE4E4E7);

/// shadcn 卡片背景色（card）
Color shadCardColor(BuildContext context) =>
    Theme.of(context).brightness == Brightness.dark ? const Color(0xFF18181B) : Colors.white;

/// shadcn 页面背景色（background）
Color shadBackgroundColor(BuildContext context) =>
    Theme.of(context).brightness == Brightness.dark ? const Color(0xFF09090B) : const Color(0xFFFAFAFA);

/// 主色（primary）：亮色主题为 #18181B，暗色主题提亮为 #FAFAFA，保证对比度
Color shadPrimaryColor(BuildContext context) =>
    Theme.of(context).brightness == Brightness.dark ? const Color(0xFFFAFAFA) : const Color(0xFF18181B);

/// 主色前景（primary-foreground）
Color shadOnPrimaryColor(BuildContext context) =>
    Theme.of(context).brightness == Brightness.dark ? const Color(0xFF18181B) : const Color(0xFFFAFAFA);