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

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:code_forge/code_forge.dart';
import 'package:flutter/material.dart';
import 'package:shadcn_ui/shadcn_ui.dart';
import 'package:lico_proxy/network/bin/configuration.dart';
import 'package:lico_proxy/network/components/manager/environment_manager.dart';
import 'package:lico_proxy/ui/component/chinese_font.dart';
import 'package:lico_proxy/ui/component/multi_window_compat.dart';
import 'package:lico_proxy/ui/component/multi_window.dart';
import 'package:lico_proxy/ui/configuration.dart';
import 'package:lico_proxy/ui/desktop/desktop.dart';
import 'package:lico_proxy/ui/mobile/liquid_glass.dart';
import 'package:lico_proxy/ui/mobile/mobile.dart';
import 'package:lico_proxy/ui/mobile/shad/shad_design.dart';
import 'package:lico_proxy/utils/desktop_support.dart';
import 'package:lico_proxy/utils/navigator.dart';
import 'package:lico_proxy/utils/platform.dart';
import 'package:window_manager/window_manager.dart';

import 'l10n/app_localizations.dart';

///主入口
///@author wanghongen
void main(List<String> args) async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    await RustLib.init();
  } catch (e) {
    // code_forge Rust FFI initialization may fail on iOS 14.x due to
    // deployment-target / cargokit-build incompatibilities. Degrade
    // gracefully instead of crashing the whole app at startup.
    print('RustLib.init failed: $e');
  }

  final windowController = Platforms.isDesktop() ? await DesktopMultiWindow.ensureInitialized() : null;

  var instance = AppConfiguration.instance;

  //多窗口
  if (args.firstOrNull == 'multi_window') {
    final windowId = windowController!.windowId;
    final argument =
        windowController.arguments.isEmpty ? const {} : jsonDecode(windowController.arguments) as Map<String, dynamic>;
    DesktopMultiWindow.initializeFromArguments(argument);
    var appConfiguration = await instance;

    if (Platform.isMacOS) {
      windowManager.setTitleBarStyle(TitleBarStyle.hidden);
    }
    if (appConfiguration.themeMode != ThemeMode.system) {
      windowManager.setBrightness(appConfiguration.themeMode == ThemeMode.dark ? Brightness.dark : Brightness.light);
    }
    runApp(FluentApp(multiWindow(windowId, argument), appConfiguration));
    return;
  }

  var configuration = Configuration.instance;
  // 预热环境变量,避免第一个请求命中时才 IO
  unawaited(EnvironmentManager.preload());
  //移动端
  if (Platforms.isMobile()) {
    var appConfiguration = await instance;
    runApp(FluentApp(MobileHomePage((await configuration), appConfiguration), appConfiguration, glass: true));
    return;
  }

  var appConfiguration = await instance;
  if (Platforms.isDesktop()) {
    await DesktopSupport.initialize(appConfiguration);
  }

  runApp(FluentApp(DesktopHomePage(await configuration, appConfiguration), appConfiguration));
}

class FluentApp extends StatelessWidget {
  final Widget home;
  final AppConfiguration appConfiguration;

  /// 是否启用液态玻璃（仅安卓/移动端 UI 重构时开启）
  final bool glass;

  const FluentApp(this.home, this.appConfiguration, {super.key, this.glass = false});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
        valueListenable: appConfiguration.globalChange,
        builder: (_, current, __) {
          final isMobile = Platforms.isMobile();
          // 移动端：shadcn 设计系统（zinc 色板）；桌面端：保持原 Material 主题
          return ShadApp(
            title: '小离Proxy',
            debugShowCheckedModeBanner: false,
            navigatorKey: navigatorHelper.navigatorKey,
            theme: isMobile ? LicoTheme.light(seed: appConfiguration.themeColor) : null,
            darkTheme: isMobile ? LicoTheme.dark(seed: appConfiguration.themeColor) : null,
            themeMode: appConfiguration.themeMode,
            locale: appConfiguration.language,
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            // 移动端：shadcn 纯色背景容器（原液态玻璃包裹已移除）
            builder: glass ? (context, child) => GlassBackground(child: child!) : null,
            // shadcn 主题之外仍挂一层 Material 主题，保证未迁移的 Material 组件（如旧 AppBar）可用
            materialThemeBuilder: (context, theme) => themeDataFrom(theme),
            home: home,
          );
        });
  }

  ThemeData themeDataFrom(ThemeData base) {
    return base.copyWith(
      pageTransitionsTheme: const PageTransitionsTheme(builders: {
        TargetPlatform.android: FadeUpwardsPageTransitionsBuilder(),
      }),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith<Color?>((states) => Colors.white),
        trackColor: WidgetStateProperty.resolveWith<Color?>((states) {
          if (states.contains(WidgetState.selected)) return const Color(0xFF369EDB);
          return const Color(0xFFBDBDBD);
        }),
        trackOutlineColor: WidgetStateProperty.resolveWith<Color?>((states) => Colors.transparent),
      ),
    );
  }

  ThemeData theme(Brightness brightness) {
    bool isDark = brightness == Brightness.dark;

    Color? themeColor = isDark ? appConfiguration.themeColor : appConfiguration.themeColor;
    Color? cardColor = isDark ? Color(0XFF3C3C3C) : Colors.white;
    Color? surfaceContainer = isDark ? Colors.grey[800] : Colors.white;

    var colorScheme = ColorScheme.fromSeed(
      brightness: brightness,
      seedColor: themeColor,
      primary: themeColor,
      surface: cardColor,
      secondary: const Color(0xFF2196F3),
      onPrimary: Colors.white,
      surfaceContainer: surfaceContainer,
      surfaceContainerHigh: surfaceContainer,
    );

    var themeData =
        ThemeData(brightness: brightness, useMaterial3: appConfiguration.useMaterial3, colorScheme: colorScheme);

    if (!appConfiguration.useMaterial3) {
      themeData = themeData.copyWith(
        appBarTheme: themeData.appBarTheme.copyWith(
          iconTheme: themeData.iconTheme.copyWith(size: 20),
          backgroundColor: themeData.canvasColor,
          elevation: 0,
          titleTextStyle: themeData.textTheme.titleMedium,
        ),
        tabBarTheme: themeData.tabBarTheme.copyWith(
          labelColor: themeData.colorScheme.primary,
          indicatorColor: themeColor,
          unselectedLabelColor: themeData.textTheme.titleMedium?.color,
        ),
      );
    }

    if (Platform.isWindows) {
      themeData = themeData.useSystemChineseFont();
    }

    // 黄鸟复刻：所有子页面 AppBar 统一橙底白字（被 AppBar 自身 backgroundColor 显式覆盖的除外）
    // 黄鸟复刻：所有 Switch 统一 关闭=灰、开启=蓝 #369EDB
    // 去掉花哨的页面切换动画，使用最基础的淡入向上过渡
    return themeData.copyWith(
      pageTransitionsTheme: const PageTransitionsTheme(builders: {
        TargetPlatform.android: FadeUpwardsPageTransitionsBuilder(),
      }),
      dialogTheme:
          themeData.dialogTheme.copyWith(shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
      // 液态玻璃模式：顶栏透明（背景由 GlassPage 渐变提供），图标/文字颜色随亮暗主题自适应
      appBarTheme: glass
          ? themeData.appBarTheme.copyWith(
              backgroundColor: Colors.transparent,
              foregroundColor: isDark ? Colors.white : const Color(0xDD000000),
              elevation: 0,
              scrolledUnderElevation: 0,
              iconTheme: IconThemeData(color: isDark ? Colors.white : const Color(0xDD000000), size: 22),
              titleTextStyle: TextStyle(
                  color: isDark ? Colors.white : const Color(0xDD000000),
                  fontSize: 18,
                  fontWeight: FontWeight.w500),
            )
          : themeData.appBarTheme.copyWith(
              backgroundColor: const Color(0xFFFF9E05),
              foregroundColor: Colors.white,
              elevation: 0,
              iconTheme: const IconThemeData(color: Colors.white, size: 22),
              titleTextStyle: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w500),
            ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith<Color?>((states) {
          if (states.contains(WidgetState.selected)) {
            return Colors.white;
          }
          return Colors.white;
        }),
        trackColor: WidgetStateProperty.resolveWith<Color?>((states) {
          if (states.contains(WidgetState.selected)) {
            return const Color(0xFF369EDB);
          }
          return const Color(0xFFBDBDBD);
        }),
        trackOutlineColor: WidgetStateProperty.resolveWith<Color?>((states) {
          return Colors.transparent;
        }),
      ),
    );
  }
}
