/*
 * 小离Proxy - shadcn 设计系统基础层
 *
 * 基于 flutter-shadcn-ui (shadcn_ui) 构建统一的设计语言与复用组件，
 * 用于移动端所有页面的 UI 重构。仅影响 Android/移动端展示层。
 */

import 'package:flutter/material.dart';
import 'package:shadcn_ui/shadcn_ui.dart';
import 'package:lico_proxy/ui/configuration.dart';

/// 全局 shadcn 主题构建器。
///
/// - 使用 zinc 中性色板，贴近 shadcn 官方默认观感
/// - 圆角统一 12，边框细而含蓄
/// - 亮/暗自动跟随系统或用户在设置页选择的主题
class LicoTheme {
  LicoTheme._();

  static const double radius = 12;

  /// 亮色主题
  static ShadThemeData light({Color? seed}) {
    final zinc = ShadZincColorScheme.light(
      primary: seed ?? const Color(0xFF18181B),
    );
    return ShadThemeData(
      colorScheme: zinc,
      radius: BorderRadius.circular(radius),
      brightness: Brightness.light,
    );
  }

  /// 暗色主题
  static ShadThemeData dark({Color? seed}) {
    final zinc = ShadZincColorScheme.dark(
      primary: seed ?? const Color(0xFFFAFAFA),
    );
    return ShadThemeData(
      colorScheme: zinc,
      radius: BorderRadius.circular(radius),
      brightness: Brightness.dark,
    );
  }

  /// 读取当前应用配置中的主题模式
  static ThemeMode resolveMode() {
    try {
      return AppConfiguration.current?.themeMode ?? ThemeMode.system;
    } catch (_) {
      return ThemeMode.system;
    }
  }
}

/// 分组卡片：设置页/配置页的统一区块容器。
///
/// 视觉上等价于 shadcn 的 Card，但内部按「行 + 细分隔线」排列，
/// 可直接承载原来的 ListTile 列表内容。
class ShadSection extends StatelessWidget {
  /// 区块标题（可选）
  final String? title;

  /// 区块副标题（可选）
  final String? description;

  /// 行内容
  final List<Widget> children;

  /// 外边距
  final EdgeInsetsGeometry margin;

  const ShadSection({
    super.key,
    this.title,
    this.description,
    required this.children,
    this.margin = const EdgeInsets.only(bottom: 14),
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: margin,
      child: ShadCard(
        padding: EdgeInsets.zero,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (title != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 2),
                child: Text(title!, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
              ),
            if (description != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 2, 16, 6),
                child: Text(description!,
                    style: TextStyle(fontSize: 12, color: ShadTheme.of(context).colorScheme.mutedForeground)),
              ),
            ...children,
          ],
        ),
      ),
    );
  }
}

/// 设置行：替代 ListTile，保持 shadcn 的紧凑排版。
///
/// 统一处理：前置图标、标题、副标题、右侧 trailing、点击回调、底部细分隔线。
class ShadTile extends StatelessWidget {
  final IconData? icon;
  final Widget? leading;
  final String? title;

  /// 自定义标题组件（优先于 [title]，用于需要在标题旁挂徽标等场景）
  final Widget? titleWidget;
  final String? subtitle;
  final Widget? trailing;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final bool showDivider;
  final Color? iconColor;
  final bool danger;

  const ShadTile({
    super.key,
    this.icon,
    this.leading,
    this.title,
    this.titleWidget,
    this.subtitle,
    this.trailing,
    this.onTap,
    this.onLongPress,
    this.showDivider = true,
    this.iconColor,
    this.danger = false,
  }) : assert(title != null || titleWidget != null, 'title 与 titleWidget 至少需要一个');

  @override
  Widget build(BuildContext context) {
    final scheme = ShadTheme.of(context).colorScheme;
    final titleColor = danger ? scheme.destructive : null;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        InkWell(
          onTap: onTap,
          onLongPress: onLongPress,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
            child: Row(
              children: [
                if (leading != null) ...[leading!, const SizedBox(width: 12)],
                if (leading == null && icon != null) ...[
                  Icon(icon, size: 19, color: iconColor ?? scheme.mutedForeground),
                  const SizedBox(width: 12),
                ],
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      DefaultTextStyle.merge(
                        style: TextStyle(fontSize: 15, fontWeight: FontWeight.w500, color: titleColor),
                        child: titleWidget ?? Text(title!),
                      ),
                      if (subtitle != null) ...[
                        const SizedBox(height: 2),
                        Text(subtitle!,
                            style: TextStyle(fontSize: 12, color: scheme.mutedForeground),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis),
                      ],
                    ],
                  ),
                ),
                if (trailing != null) ...[const SizedBox(width: 10), trailing!],
              ],
            ),
          ),
        ),
        if (showDivider)
          Divider(height: 0, thickness: 0.5, indent: 16, endIndent: 16, color: scheme.border.withValues(alpha: 0.5)),
      ],
    );
  }
}

/// 页头：shadcn 风格的紧凑顶栏，替代 Material AppBar。
class ShadHeader extends StatelessWidget implements PreferredSizeWidget {
  final String title;
  final List<Widget> actions;
  final Widget? leading;
  final Widget? bottom;

  const ShadHeader({super.key, required this.title, this.actions = const [], this.leading, this.bottom});

  @override
  Size get preferredSize => Size.fromHeight(bottom == null ? kToolbarHeight : kToolbarHeight + 48);

  @override
  Widget build(BuildContext context) {
    final scheme = ShadTheme.of(context).colorScheme;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          height: kToolbarHeight,
          decoration: BoxDecoration(
            color: scheme.background,
            border: Border(bottom: BorderSide(color: scheme.border.withValues(alpha: 0.5), width: 0.5)),
          ),
          child: Row(
            children: [
              const SizedBox(width: 6),
              if (leading != null) leading!,
              if (leading == null)
                ShadIconButton.ghost(
                  icon: const Icon(LucideIcons.chevronLeft, size: 20),
                  onPressed: () => Navigator.of(context).maybePop(),
                ),
              const SizedBox(width: 4),
              Expanded(child: Text(title, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w600))),
              ...actions,
              const SizedBox(width: 6),
            ],
          ),
        ),
        if (bottom != null) bottom!,
      ],
    );
  }
}

/// 统一的确认/信息弹窗（shadcn Dialog）
Future<bool?> showLicoConfirm(
  BuildContext context, {
  required String title,
  String? description,
  String confirmText = '确定',
  String cancelText = '取消',
  bool destructive = false,
}) {
  return showShadDialog<bool>(
    context: context,
    builder: (ctx) => ShadDialog.alert(
      title: Text(title),
      description: description == null ? null : Text(description),
      actions: [
        ShadButton.outline(child: Text(cancelText), onPressed: () => Navigator.of(ctx).pop(false)),
        ShadButton(
          onPressed: () => Navigator.of(ctx).pop(true),
          backgroundColor: destructive ? ShadTheme.of(ctx).colorScheme.destructive : null,
          child: Text(confirmText),
        ),
      ],
    ),
  );
}

/// 状态徽标（shadcn Badge），用于请求方法、状态码等短标签。
class ShadTag extends StatelessWidget {
  final String text;
  final Color? color;
  final bool outline;

  const ShadTag(this.text, {super.key, this.color, this.outline = false});

  @override
  Widget build(BuildContext context) {
    final scheme = ShadTheme.of(context).colorScheme;
    final c = color ?? scheme.primary;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: outline ? Colors.transparent : c.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(6),
        border: outline ? Border.all(color: c.withValues(alpha: 0.35), width: 0.8) : null,
      ),
      child: Text(text,
          style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: outline ? c : c, height: 1.4)),
    );
  }
}

/// 空状态占位
class ShadEmpty extends StatelessWidget {
  final IconData icon;
  final String message;

  const ShadEmpty({super.key, this.icon = LucideIcons.inbox, required this.message});

  @override
  Widget build(BuildContext context) {
    final scheme = ShadTheme.of(context).colorScheme;
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 40, color: scheme.mutedForeground.withValues(alpha: 0.6)),
          const SizedBox(height: 12),
          Text(message,
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13, color: scheme.mutedForeground)),
        ],
      ),
    );
  }
}
