/*
 * Copyright 2023 Hongen Wang
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
import 'dart:io';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_toastr/flutter_toastr.dart';
import 'package:proxypin/l10n/app_localizations.dart';
import 'package:proxypin/native/vpn.dart';
import 'package:proxypin/network/bin/server.dart';
import 'package:proxypin/network/util/logger.dart';
import 'package:proxypin/ui/desktop/ssl/pc_cert.dart';
import 'package:proxypin/ui/configuration.dart';
import 'package:proxypin/utils/lang.dart';
import 'package:proxypin/utils/desktop_tray.dart';
import 'package:proxypin/utils/platform.dart';
import 'package:window_manager/window_manager.dart';

import '../mobile/setting/ssl.dart';

/// HttpCanary 3.3.6 右下角抓包按钮图标（从参考图逐点矢量化提取）
/// 来源：flutter_capture_icons-2.zip / svg/ic_capture_start.svg、ic_capture_stop.svg（形状 IoU 0.96+）
/// 图标自带彩色圆形底：idle=蓝 #369EDB + 白色纸飞机+斜杠；active=绿 #388E3C + 白色纸飞机（无斜杠）。
/// 颜色已内置于 SVG，外部 FloatingActionButton 背景须设为透明。
const String _captureIdleSvg = '''
<svg xmlns="http://www.w3.org/2000/svg" width="48" height="48" viewBox="0 0 48 48">
  <circle cx="24" cy="24" r="24" fill="#369EDB"/>
  <path d="M30.88 32.60L30.56 32.52L27.44 29.40L25.84 28.76L22.08 27.64L21.96 27.20L23.24 25.76L23.24 25.20L22.88 24.84L22.32 24.84L19.68 27.00L19.36 27.00L13.96 24.96L14.32 24.52L19.48 22.08L19.48 21.52L15.64 17.76L15.92 17.08L16.56 16.60L17.52 17.40L31.72 31.52L31.72 31.84Z" fill="#FFFFFF"/>
  <path d="M29.52 26.92L28.20 25.84L28.20 25.04L28.76 23.04L28.72 22.52L28.24 22.52L27.08 23.92L26.80 24.20L25.64 23.36L25.64 22.56L24.72 22.44L22.92 20.64L31.92 16.04L32.04 16.32L31.88 17.12Z" fill="#FFFFFF"/>
  <path d="M22.16 32.36L21.88 32.24L21.88 29.20L22.48 29.08L23.84 29.56L24.04 29.92Z" fill="#FFFFFF"/>
</svg>''';

const String _captureActiveSvg = '''
<svg xmlns="http://www.w3.org/2000/svg" width="48" height="48" viewBox="0 0 48 48">
  <circle cx="24" cy="24" r="24" fill="#388E3C"/>
  <path d="M28.88 29.32L28.24 29.24L24.00 27.80L22.64 27.48L21.96 27.12L22.68 26.08L25.48 22.88L25.44 22.36L24.88 22.36L20.64 25.96L19.60 26.68L14.56 24.84L14.16 24.60L30.24 16.44L32.00 15.72L31.88 16.88L30.76 21.28L30.44 23.20L30.20 23.76L29.08 29.04Z" fill="#FFFFFF"/>
  <path d="M22.16 32.04L21.96 28.80L22.40 28.68L24.00 29.24L24.04 29.60Z" fill="#FFFFFF"/>
</svg>''';

///启动按钮
///@author wanghongen
///2023/10/8
class SocketLaunch extends StatefulWidget {
  static ValueNotifier<ValueWrap<bool>> startStatus = ValueNotifier(ValueWrap());

  final ProxyServer proxyServer;
  final int size;
  final EdgeInsetsGeometry? padding; // IconButton 内边距，默认 8.0
  final bool startup; //默认是否启动
  final Function? onStart;
  final Function? onStop;

  final bool serverLaunch; //是否启动代理服务器

  const SocketLaunch(
      {super.key,
      required this.proxyServer,
      this.size = 25,
      this.padding,
      this.onStart,
      this.onStop,
      this.startup = true,
      this.serverLaunch = true});

  @override
  State<StatefulWidget> createState() => _SocketLaunchState();
}

class _SocketLaunchState extends State<SocketLaunch> with WindowListener, WidgetsBindingObserver {
  AppLocalizations get localizations => AppLocalizations.of(context)!;
  bool started = false;

  @override
  void initState() {
    super.initState();
    if (Platforms.isDesktop()) {
      windowManager.addListener(this);
      windowManager.setPreventClose(true);
      DesktopTrayManager.instance.setQuitHandler(appExit);
    }

    WidgetsBinding.instance.addObserver(this);
    //启动代理服务器
    if (widget.startup) {
      start();
    }

    SocketLaunch.startStatus.addListener(() {
      if (SocketLaunch.startStatus.value.get() == started) {
        return;
      }
      setState(() {
        started = SocketLaunch.startStatus.value.get() ?? started;
      });
    });
  }

  @override
  void dispose() {
    windowManager.removeListener(this);
    WidgetsBinding.instance.removeObserver(this);
    if (Platforms.isDesktop()) {
      DesktopTrayManager.instance.setQuitHandler(null);
    }
    super.dispose();
  }

  @override
  void onWindowClose() async {
    logger.d("onWindowClose");
    await _handleWindowClose();
  }

  Future<void> _handleWindowClose() async {
    final appConfiguration = AppConfiguration.current;
    if (Platforms.isDesktop() && appConfiguration?.minimizeToTray == null || appConfiguration?.minimizeToTray == true) {
      if (appConfiguration?.minimizeToTray == null) {
        final minimize = await _showTrayClosePrompt();
        if (!mounted) {
          return;
        }

        appConfiguration?.minimizeToTray = minimize;
        await appConfiguration?.flushConfig();

        if (!minimize) {
          await appExit();
          return;
        }
      }

      try {
        await DesktopTrayManager.instance.showToTray();
        return;
      } catch (e) {
        logger.e('show to tray failed, fallback to exit', error: e);
      }
    }

    await appExit();
  }

  Future<bool> _showTrayClosePrompt() async {
    return await showDialog<bool>(
          context: context,
          barrierDismissible: false,
          builder: (ctx) {
            return AlertDialog(
              title: Text(localizations.minimizeToTrayTitle),
              content: SizedBox(width: 320, child: Text(maxLines: 3, localizations.trayClosePromptContent)),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(ctx).pop(false),
                  child: Text(localizations.trayCloseExitAnyway),
                ),
                FilledButton(
                  onPressed: () => Navigator.of(ctx).pop(true),
                  child: Text(localizations.trayCloseMinimizeToTray),
                ),
              ],
            );
          },
        ) ??
        false;
  }

  Future<void> appExit() async {
    logger.d("appExit");
    await widget.proxyServer.stop();
    started = false;
    if (Platforms.isDesktop()) {
      await DesktopTrayManager.instance.exitApp();
      windowManager.setPreventClose(false);
      await windowManager.destroy();
    }

    if (!Platform.isWindows && !Platform.isLinux) {
      try {
        await SystemNavigator.pop(animated: true).timeout(const Duration(milliseconds: 150));
      } catch (_) {
        //
      }
    }

    exit(0);
  }

  @override
  Future<AppExitResponse> didRequestAppExit() async {
    bool isPreventClose = await windowManager.isPreventClose();
    if (!isPreventClose || Platform.isMacOS) {
      await appExit();
    }
    return super.didRequestAppExit();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      if (widget.proxyServer.isRunning && started) {
        widget.proxyServer.retryBind().catchError((e) {
          logger.e('retryBind failed on resumed', error: e);
        });
      }

      if (Platforms.isMobile() && started == false) {
        Vpn.isRunning().then((value) {
          Vpn.isVpnStarted = value;
          SocketLaunch.startStatus.value = ValueWrap.of(value);
        });
      }
    }

    if (state == AppLifecycleState.detached) {
      logger.d('AppLifecycleState.detached');
      widget.onStop?.call();
      widget.proxyServer.stop();
      started = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    return IconButton(
        tooltip: started ? localizations.stop : localizations.start,
        padding: widget.padding ?? const EdgeInsets.all(8.0),
        icon: SvgPicture.string(started ? _captureActiveSvg : _captureIdleSvg,
            width: widget.size.toDouble(), height: widget.size.toDouble()),
        onPressed: () async {
          if (started) {
            if (!widget.serverLaunch) {
              setState(() {
                widget.onStop?.call();
                started = !started;
              });
              return;
            }

            widget.proxyServer.stop().then((value) {
              widget.onStop?.call();
              if (mounted) {
                setState(() {
                  started = !started;
                });
              }
            }).catchError((e) {
              logger.e("stop proxy server failed", error: e);
              if (mounted) {
                FlutterToastr.show(localizations.fail, context, duration: 3);
                setState(() {
                  started = false;
                });
              }
            });
          } else {
            start();
          }
        });
  }

  ///启动代理服务器
  Future<void> start() async {
    try {
      if (!widget.serverLaunch) {
        await widget.onStart?.call();
        setState(() {
          started = true;
        });
        return;
      }

      widget.proxyServer.start().then((value) {
        if (mounted) {
          setState(() {
            started = true;
          });
        }
        widget.onStart?.call();
      }).catchError((e) {
        logger.e("启动代理服务器失败", error: e);
        String message = localizations.proxyPortRepeat(widget.proxyServer.port);
        FlutterToastr.show(message, context, duration: 3);
      });
    } finally {
      Future.delayed(const Duration(seconds: 5)).then((value) {
        if (!mounted) {
          return;
        }
        if (Platforms.isDesktop()) {
          PCCertChecker.check(context);
        } else if (Platform.isIOS) {
          IOSCertChecker.check(context);
        }
      });
    }
  }
}
