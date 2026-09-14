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
 * See the License for specific language governing permissions and
 * limitations under the License.
 */
import 'package:flutter/material.dart';
import 'package:proxypin/native/installed_apps.dart';
import 'package:proxypin/network/bin/configuration.dart';
import 'package:proxypin/network/bin/server.dart';
import 'package:proxypin/ui/mobile/setting/app_filter.dart';

/// 目标应用：选择抓包作用的应用。
/// 与「黑白名单 → 白名单应用」共用 configuration.appWhitelist（HttpCanary 原版设计）。
class TargetAppPage extends StatefulWidget {
  final ProxyServer proxyServer;

  const TargetAppPage({super.key, required this.proxyServer});

  @override
  State<TargetAppPage> createState() => _TargetAppPageState();
}

class _TargetAppPageState extends State<TargetAppPage> {
  late Configuration configuration;
  bool isLoading = true;
  bool changed = false;
  List<AppInfo> appInfoList = [];

  @override
  void initState() {
    super.initState();
    configuration = widget.proxyServer.configuration;
    _loadApps();
  }

  @override
  void dispose() {
    if (changed) {
      configuration.flushConfig();
    }
    super.dispose();
  }

  void _loadApps() async {
    bool isCN = Localizations.localeOf(context) == const Locale.fromSubtags(languageCode: 'zh');
    var futures = <Future<AppInfo>>[];
    for (var element in configuration.appWhitelist) {
      futures.add(InstalledApps.getAppInfo(element).catchError((e) {
        return AppInfo(name: isCN ? "未知应用" : "Unknown app", packageName: element, inValid: true);
      }));
    }
    var list = await Future.wait(futures);
    if (mounted) {
      setState(() {
        appInfoList = list;
        isLoading = false;
      });
    }
  }

  Future<void> _addApp() async {
    final packageName = await Navigator.of(context).push(MaterialPageRoute(
      builder: (context) => InstalledAppsWidget(addedList: appInfoList),
    ));
    if (!mounted) return;
    if (packageName != null && !configuration.appWhitelist.contains(packageName)) {
      configuration.appWhitelist.add(packageName);
      changed = true;
      bool isCN = Localizations.localeOf(context) == const Locale.fromSubtags(languageCode: 'zh');
      var newApp = await InstalledApps.getAppInfo(packageName).catchError((e) {
        return AppInfo(name: isCN ? "未知应用" : "Unknown app", packageName: packageName, inValid: true);
      });
      if (mounted) {
        setState(() => appInfoList.add(newApp));
      }
    }
  }

  void _removeApp(AppInfo appInfo) {
    setState(() {
      configuration.appWhitelist.remove(appInfo.packageName);
      appInfoList.remove(appInfo);
      changed = true;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('已从目标应用中移除 ${appInfo.name ?? appInfo.packageName}'),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  void _showActions(AppInfo appInfo) {
    showModalBottomSheet(
      context: context,
      builder: (ctx) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.delete_outline, color: Colors.red),
                title: const Text('从目标应用中移除'),
                onTap: () {
                  Navigator.of(ctx).pop();
                  _removeApp(appInfo);
                },
              ),
              ListTile(
                leading: const Icon(Icons.close),
                title: const Text('取消'),
                onTap: () => Navigator.of(ctx).pop(),
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('目标应用', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w500)),
        centerTitle: false,
        backgroundColor: const Color(0xFFFF9E05),
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.add, color: Colors.white),
            tooltip: '添加应用',
            onPressed: _addApp,
          ),
        ],
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : appInfoList.isEmpty
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: Text(
                      '点击右上角 + 添加需要抓包的应用',
                      style: TextStyle(color: Colors.grey.shade600, fontSize: 14),
                      textAlign: TextAlign.center,
                    ),
                  ),
                )
              : ListView.separated(
                  itemCount: appInfoList.length,
                  separatorBuilder: (_, __) =>
                      Divider(height: 1, thickness: 1, color: Colors.grey.shade200, indent: 76),
                  itemBuilder: (BuildContext context, int index) {
                    AppInfo appInfo = appInfoList[index];
                    return ListTile(
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                      leading: appInfo.icon == null
                          ? Container(
                              width: 48,
                              height: 48,
                              decoration: BoxDecoration(
                                color: Colors.grey.shade200,
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(Icons.question_mark, color: Colors.grey),
                            )
                          : ClipOval(
                              child: Image.memory(
                                appInfo.icon!,
                                width: 48,
                                height: 48,
                                fit: BoxFit.cover,
                              ),
                            ),
                      title: Text(
                        appInfo.name ?? appInfo.packageName ?? '',
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
                      ),
                      subtitle: Padding(
                        padding: const EdgeInsets.only(top: 2),
                        child: Text(
                          appInfo.packageName ?? '',
                          style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                        ),
                      ),
                      trailing: const Icon(Icons.shield_outlined, color: Color(0xFFFFB300), size: 28),
                      onLongPress: () => _showActions(appInfo),
                    );
                  },
                ),
    );
  }
}
