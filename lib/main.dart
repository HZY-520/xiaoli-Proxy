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
import 'package:proxypin/network/bin/configuration.dart';
import 'package:proxypin/network/components/manager/environment_manager.dart';
import 'package:proxypin/ui/component/chinese_font.dart';
import 'package:proxypin/ui/component/multi_window_compat.dart';
import 'package:proxypin/ui/component/multi_window.dart';
import 'package:proxypin/ui/configuration.dart';
import 'package:proxypin/ui/desktop/desktop.dart';
import 'package:proxypin/ui/mobile/mobile.dart';
import 'package:proxypin/utils/desktop_support.dart';
import 'package:proxypin/utils/navigator.dart';
import 'package:proxypin/utils/platform.dart';
import 'package:shadcn_ui/shadcn_ui.dart';
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
    runApp(FluentApp(MobileHomePage((await configuration), appConfiguration), appConfiguration));
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

  const FluentApp(this.home, this.appConfiguration, {super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
        valueListenable: appConfiguration.globalChange,
        builder: (_, current, __) {
          return MaterialApp(
            title: '小离Proxy',
            debugShowCheckedModeBanner: false,
            navigatorKey: navigatorHelper.navigatorKey,
            theme: theme(Brightness.light),
            darkTheme: theme(Brightness.dark),
            themeMode: appConfiguration.themeMode,
            locale: appConfiguration.language,
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            // 为 shadcn_ui 组件注入 ShadTheme（跟随亮/暗模式）
            builder: (context, child) => ShadTheme(
              data: ShadThemeData(brightness: Theme.of(context).brightness),
              child: child!,
            ),
            home: home,
          );
        });
  }

  ThemeData theme(Brightness brightness) {
    bool isDark = brightness == Brightness.dark;
    bool mobile = Platforms.isMobile();

    // 桌面端保持原外观：Shadcn 默认色映射回原 HttpCanary 主色
    Color themeColor = appConfiguration.themeColor;
    if (!mobile && ColorMapping.getColorName(themeColor) == "Shadcn") {
      themeColor = ColorMapping.colors["HttpCanary"]!;
    }

    Color background = isDark ? const Color(0xFF09090B) : const Color(0xFFFAFAFA);
    Color cardColor = isDark ? const Color(0xFF18181B) : Colors.white;
    Color borderColor = isDark ? const Color(0xFF27272A) : const Color(0xFFE4E4E7);
    Color foreground = isDark ? const Color(0xFFFAFAFA) : const Color(0xFF09090B);
    Color muted = isDark ? const Color(0xFFA1A1AA) : const Color(0xFF71717A);

    Color? themeCardColor = mobile ? cardColor : (isDark ? const Color(0XFF3C3C3C) : Colors.white);
    Color? surfaceContainer =
        mobile ? cardColor : (isDark ? Colors.grey[800] : Colors.white);

    var colorScheme = ColorScheme.fromSeed(
      brightness: brightness,
      seedColor: themeColor,
      primary: themeColor,
      surface: themeCardColor,
      secondary: const Color(0xFF2196F3),
      onPrimary: isDark ? const Color(0xFF09090B) : Colors.white,
      surfaceContainer: surfaceContainer,
      surfaceContainerHigh: surfaceContainer,
    );

    var themeData =
        ThemeData(brightness: brightness, useMaterial3: true, colorScheme: colorScheme);

    if (Platform.isWindows) {
      themeData = themeData.useSystemChineseFont();
    }

    if (!mobile) {
      // 桌面端：保持原有黄鸟复刻样式
      return themeData.copyWith(
        pageTransitionsTheme: const PageTransitionsTheme(builders: {
          TargetPlatform.android: FadeUpwardsPageTransitionsBuilder(),
        }),
        dialogTheme:
            themeData.dialogTheme.copyWith(shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
        appBarTheme: themeData.appBarTheme.copyWith(
          backgroundColor: const Color(0xFFFF9E05),
          foregroundColor: Colors.white,
          elevation: 0,
          iconTheme: const IconThemeData(color: Colors.white, size: 22),
          titleTextStyle: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w500),
        ),
        switchTheme: SwitchThemeData(
          thumbColor: WidgetStateProperty.resolveWith<Color?>((states) {
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

    // 安卓端：shadcn/ui 风格
    return themeData.copyWith(
      pageTransitionsTheme: const PageTransitionsTheme(builders: {
        TargetPlatform.android: FadeUpwardsPageTransitionsBuilder(),
      }),
      scaffoldBackgroundColor: background,
      canvasColor: background,
      dividerColor: borderColor,
      dialogTheme: themeData.dialogTheme.copyWith(
        backgroundColor: cardColor,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
      appBarTheme: themeData.appBarTheme.copyWith(
        backgroundColor: background,
        foregroundColor: foreground,
        elevation: 0,
        scrolledUnderElevation: 0,
        surfaceTintColor: Colors.transparent,
        iconTheme: IconThemeData(color: foreground, size: 22),
        titleTextStyle: TextStyle(color: foreground, fontSize: 18, fontWeight: FontWeight.w500),
      ),
      cardTheme: CardThemeData(
        color: cardColor,
        elevation: 0,
        margin: EdgeInsets.zero,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
          side: BorderSide(color: borderColor),
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: cardColor,
        elevation: 0,
        height: 58,
        surfaceTintColor: Colors.transparent,
        indicatorColor: Color.lerp(themeColor, cardColor, 0.88),
        labelTextStyle: WidgetStatePropertyAll(TextStyle(fontSize: 11, color: muted)),
        iconTheme: WidgetStateProperty.resolveWith((states) => IconThemeData(
            color: states.contains(WidgetState.selected) ? themeColor : muted, size: 22)),
      ),
      listTileTheme: ListTileThemeData(
        iconColor: muted,
        textColor: foreground,
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(foregroundColor: themeColor),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: themeColor,
          foregroundColor: isDark ? const Color(0xFF09090B) : Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: cardColor,
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: borderColor)),
        focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: themeColor)),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith<Color?>((states) {
          return Colors.white;
        }),
        trackColor: WidgetStateProperty.resolveWith<Color?>((states) {
          if (states.contains(WidgetState.selected)) {
            return themeColor;
          }
          return borderColor;
        }),
        trackOutlineColor: WidgetStateProperty.resolveWith<Color?>((states) {
          return Colors.transparent;
        }),
      ),
    );
  }
}
