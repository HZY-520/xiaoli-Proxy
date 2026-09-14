import 'dart:io';

import 'package:flutter/services.dart';

/// 悬浮窗保活服务桥接
class FloatingWindow {
  static const MethodChannel _channel = MethodChannel('com.proxy/floating');

  /// 是否有悬浮窗权限
  static Future<bool> canDrawOverlays() async {
    if (!Platform.isAndroid) return false;
    try {
      return await _channel.invokeMethod<bool>('canDrawOverlays') ?? false;
    } catch (_) {
      return false;
    }
  }

  /// 跳转到系统悬浮窗权限设置
  static Future<void> openOverlaySettings() async {
    if (!Platform.isAndroid) return;
    await _channel.invokeMethod('openOverlaySettings');
  }

  /// 启动悬浮窗
  static Future<bool> start({required bool isRunning}) async {
    if (!Platform.isAndroid) return false;
    try {
      return await _channel.invokeMethod<bool>('startFloating', {'isRunning': isRunning}) ?? false;
    } catch (_) {
      return false;
    }
  }

  /// 关闭悬浮窗
  static Future<void> stop() async {
    if (!Platform.isAndroid) return;
    await _channel.invokeMethod('stopFloating');
  }

  /// 同步当前抓包状态到悬浮窗图标
  static Future<void> updateState(bool isRunning) async {
    if (!Platform.isAndroid) return;
    try {
      await _channel.invokeMethod('updateState', {'isRunning': isRunning});
    } catch (_) {}
  }

  /// 悬浮窗是否正在显示
  static Future<bool> isShowing() async {
    if (!Platform.isAndroid) return false;
    try {
      return await _channel.invokeMethod<bool>('isFloating') ?? false;
    } catch (_) {
      return false;
    }
  }
}
