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

import 'package:date_format/date_format.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:shadcn_ui/shadcn_ui.dart';
import 'package:flutter/services.dart';
import 'package:lico_proxy/l10n/app_localizations.dart';
import 'package:flutter_toastr/flutter_toastr.dart';
import 'package:lico_proxy/network/bin/configuration.dart';
import 'package:lico_proxy/network/bin/server.dart';
import 'package:lico_proxy/network/channel/host_port.dart';
import 'package:lico_proxy/network/http/http.dart';
import 'package:lico_proxy/network/http/http_client.dart';
import 'package:lico_proxy/network/util/logger.dart';
import 'package:lico_proxy/storage/histories.dart';
import 'package:lico_proxy/ui/component/history_cache_time.dart';
import 'package:lico_proxy/ui/component/multi_select_controller.dart';
import 'package:lico_proxy/ui/component/utils.dart';
import 'package:lico_proxy/ui/component/widgets.dart';
import 'package:lico_proxy/ui/mobile/request/list.dart';
import 'package:lico_proxy/ui/mobile/request/search.dart';
import 'package:lico_proxy/utils/listenable_list.dart';
import 'package:lico_proxy/utils/platform.dart';
import 'package:lico_proxy/utils/quick_share.dart';
import 'package:lico_proxy/ui/mobile/shad/shad_design.dart';
import 'package:share_plus/share_plus.dart';

import '../../../utils/har.dart';

class MobileHistory extends StatefulWidget {
  final ProxyServer proxyServer;
  final HistoryTask historyTask;
  final ListenableList<HttpRequest> container;
  final String? autoOpenHistoryPath;

  const MobileHistory(
      {super.key,
      required this.proxyServer,
      required this.container,
      required this.historyTask,
      this.autoOpenHistoryPath});

  @override
  State<StatefulWidget> createState() {
    return _MobileHistoryState();
  }
}

///重发所有请求
void _repeatAllRequests(Iterable<HttpRequest> requests, ProxyServer proxyServer, {BuildContext? context}) async {
  var localizations = context == null ? null : AppLocalizations.of(context);

  for (var request in requests) {
    var httpRequest = request.copy(uri: request.requestUrl);
    var proxyInfo = proxyServer.isRunning ? ProxyInfo.of("127.0.0.1", proxyServer.port) : null;
    try {
      await HttpClients.proxyRequest(httpRequest, proxyInfo: proxyInfo, timeout: const Duration(seconds: 3));
      if (context != null && context.mounted) {
        FlutterToastr.show(localizations!.reSendRequest, rootNavigator: true, context);
      }
    } catch (e) {
      if (context != null && context.mounted) {
        FlutterToastr.show('${localizations!.fail} $e', rootNavigator: true, context);
      }
    }
  }
}

class _MobileHistoryState extends State<MobileHistory> {
  ///是否保存会话
  static bool _sessionSaved = false;
  late Configuration configuration;
  var storageInstance = HistoryStorage.instance;
  late final OnchangeListEvent<HistoryItem> _historyListener;
  bool _autoOpened = false;

  @override
  void initState() {
    super.initState();
    configuration = widget.proxyServer.configuration;
    _historyListener = OnchangeListEvent<HistoryItem>(() {
      if (mounted) {
        setState(() {});
      }
    });
    storageInstance.then((storage) => storage.addListener(_historyListener));
    WidgetsBinding.instance.addPostFrameCallback((_) => _openImportedHistoryIfNeeded());
  }

  @override
  void dispose() {
    storageInstance.then((storage) => storage.removeListener(_historyListener));
    super.dispose();
  }

  AppLocalizations get localizations => AppLocalizations.of(context)!;

  Future<void> _openImportedHistoryIfNeeded() async {
    if (_autoOpened || !mounted) {
      return;
    }

    final targetPath = widget.autoOpenHistoryPath;
    if (targetPath == null || targetPath.isEmpty) {
      return;
    }

    final storage = await storageInstance;
    if (!mounted) {
      return;
    }

    HistoryItem? target;
    for (final history in storage.histories) {
      if (history.path == targetPath) {
        target = history;
        break;
      }
    }
    if (target == null) {
      return;
    }

    _autoOpened = true;
    toRequestsView(target, storage);
  }

  @override
  Widget build(BuildContext context) {
    return futureWidget(storageInstance, (storage) {
      List<Widget> children = [];

      if (widget.container.isNotEmpty == true && !_sessionSaved && widget.historyTask.history == null) {
        //当前会话未保存，是否保存当前会话
        children.add(buildSaveSession(storage));
      }

      var histories = storage.histories;
      for (int i = histories.length - 1; i >= 0; i--) {
        var entry = histories.elementAt(i);
        children.add(buildItem(storage, i, entry));
      }

      return Scaffold(
          appBar: ShadHeader(title: localizations.history, actions: [
            ShadIconButton.ghost(
                onPressed: () => import(storage),
                icon: const Icon(LucideIcons.import, size: 19),
                width: 38,
                height: 38),
            HistoryCacheTime(configuration, onSelected: (val) {
              if (val == 0) {
                widget.container.removeListener(widget.historyTask);
              } else {
                widget.container.addListener(widget.historyTask);
              }
            }),
            const SizedBox(width: 6)
          ]),
          body: children.isEmpty
              ? ShadEmpty(icon: LucideIcons.inbox, message: localizations.emptyData)
              : ListView.separated(
                  itemCount: children.length,
                  itemBuilder: (context, index) => children[index],
                  separatorBuilder: (_, index) => const Divider(thickness: 0.3, height: 0),
                ));
    });
  }

  //构建保存会话
  Widget buildSaveSession(HistoryStorage storage) {
    var name = formatDate(DateTime.now(), [mm, '-', d, ' ', HH, ':', nn, ':', ss]);

    return ShadTile(
      titleWidget: Text(name),
      subtitleWidget: Text(localizations.historyUnSave),
      trailing: TextButton.icon(
        icon: const Icon(Icons.save),
        label: Text(localizations.save),
        onPressed: () async {
          setState(() {
            widget.container.addListener(widget.historyTask);
            widget.historyTask.startTask();
            _sessionSaved = true;
          });
        },
      ),
      onTap: () {},
    );
  }

  //导入har
  Future<void> import(HistoryStorage storage) async {
    FilePickerResult? result = await FilePicker.pickFiles(type: FileType.any);
    if (result == null || result.files.isEmpty) {
      return;
    }

    try {
      var historyItem = await storage.addHarFile(result.files.single.xFile);
      setState(() {
        toRequestsView(historyItem, storage);
        FlutterToastr.show(localizations.importSuccess, context);
      });
    } catch (e, t) {
      logger.e("导入失败", error: e, stackTrace: t);
      if (mounted) {
        FlutterToastr.show("${localizations.importFailed} $e", context);
      }
    }
  }

  int selectIndex = -1;

  //构建历史记录
  Widget buildItem(HistoryStorage storage, int index, HistoryItem item) {
    return GestureDetector(
        onLongPressStart: (detail) async {
          if (Platform.isAndroid) HapticFeedback.mediumImpact();
          setState(() {
            selectIndex = index;
          });

          final menuItems = <PopupMenuEntry>[
            PopupMenuItem(child: Text(localizations.rename), onTap: () => renameHistory(storage, item)),
            PopupMenuItem(
                child: Text(localizations.share), onTap: () => export(storage, item, offset: detail.globalPosition)),
          ];

          if (QuickShareService.isRemoteConnected(widget.proxyServer) && item.requestLength > 0) {
            menuItems.addAll([
              PopupMenuItem(
                  child: Text('${localizations.send} ${localizations.remoteDevice}'),
                  onTap: () => sendToRemote(storage, item)),
            ]);
          }

          menuItems.addAll([
            const PopupMenuDivider(height: 0.3),
            PopupMenuItem(
                child: Text(localizations.repeatAllRequests),
                onTap: () async {
                  var requests = (await storage.getRequests(item)).reversed;
                  //重发所有请求
                  _repeatAllRequests(requests.toList(), widget.proxyServer, context: mounted ? context : null);
                }),
            const PopupMenuDivider(height: 0.3),
            PopupMenuItem(child: Text(localizations.delete), onTap: () => deleteHistory(storage, index))
          ]);

          final popupOffset = detail.globalPosition.translate(-50, index == 0 ? -100 : 100);
          showContextMenu(context, popupOffset, items: menuItems).whenComplete(() {
            setState(() {
              selectIndex = -1;
            });
          });
        },
        child: ShadTile(
          titleWidget: Text(item.name),
          subtitleWidget: Text(localizations.historySubtitle(item.requestLength, item.size)),
          onTap: () => toRequestsView(item, storage),
        ));
  }

  void toRequestsView(HistoryItem item, HistoryStorage storage) {
    Navigator.of(context)
        .push(MaterialPageRoute(
            builder: (BuildContext context) => HistoryRecord(history: item, proxyServer: widget.proxyServer)))
        .then((value) async {
      if (item != widget.historyTask.history && item.requests != null && item.requestLength != item.requests?.length) {
        await storage.flushRequests(item, item.requests!);
        setState(() {});
      }
      Future.delayed(const Duration(seconds: 60), () => item.requests = null);
    });
  }

  //导出har
  Future<void> export(HistoryStorage storage, HistoryItem item, {Offset? offset}) async {
    //文件名称
    String fileName =
        '${item.name.contains("小离Proxy") ? '' : '小离Proxy'}${item.name}.har'.replaceAll(" ", "_").replaceAll(":", "_");
    //获取请求
    List<HttpRequest> requests = await storage.getRequests(item);
    var json = await Har.writeJson(requests, title: item.name);
    var file = XFile.fromData(utf8.encode(json), mimeType: "har");

    Rect? rect;
    if (await Platforms.isIpad() && offset != null) {
      rect = Rect.fromCenter(center: offset, width: 1, height: 1);
    }

    SharePlus.instance.share(ShareParams(files: [file], fileNameOverrides: [fileName], sharePositionOrigin: rect));
    Future.delayed(const Duration(seconds: 30), () => item.requests = null);
  }

  Future<void> sendToRemote(HistoryStorage storage, HistoryItem item) async {
    if (!QuickShareService.isRemoteConnected(widget.proxyServer)) {
      if (mounted) {
        FlutterToastr.show('${localizations.notConnected} ${localizations.remoteDevice}', context);
      }
      return;
    }

    final requests = await storage.getRequests(item);
    if (requests.isEmpty) {
      if (mounted) {
        FlutterToastr.show(localizations.emptyData, context);
      }
      return;
    }

    final result = await QuickShareService.sendHistoryToRemote(widget.proxyServer, requests, historyName: item.name);
    if (mounted) {
      FlutterToastr.show(
          '${localizations.send}: ${localizations.success} ${result.success}, ${localizations.fail} ${result.failed}',
          context);
    }

    Future.delayed(const Duration(seconds: 30), () => item.requests = null);
  }

  //重命名
  void renameHistory(HistoryStorage storage, HistoryItem item) {
    String name = "";
    showDialog(
        context: context,
        builder: (context) {
          return ShadDialog.alert(
            title: Text(localizations.name),
            actions: <Widget>[
              ShadButton.outline(onPressed: () => Navigator.pop(context), child: Text(localizations.cancel)),
              ShadButton(
                onPressed: () {
                  if (name.isEmpty) {
                    FlutterToastr.show(localizations.historyEmptyName, context, position: 2);
                    return;
                  }
                  Navigator.of(context).pop();
                  setState(() {
                    item.name = name;
                    storage.refresh();
                  });
                },
                child: Text(localizations.save),
              ),
            ],
            child: TextField(
              decoration: InputDecoration(label: Text(localizations.name)),
              onChanged: (val) => name = val,
            ),
          );
        });
  }

  //删除
  void deleteHistory(HistoryStorage storage, int index) {
    showDialog(
        context: context,
        builder: (context) {
          return ShadDialog.alert(
            title: Text(localizations.historyDeleteConfirm),
            actions: [
              ShadButton.outline(onPressed: () => Navigator.pop(context), child: Text(localizations.cancel)),
              ShadButton(
                  backgroundColor: ShadTheme.of(context).colorScheme.destructive,
                  onPressed: () {
                    setState(() {
                      if (storage.getHistory(index) == widget.historyTask.history) {
                        widget.historyTask.cancelTask();
                      }
                      storage.removeHistory(index);
                    });
                    FlutterToastr.show(localizations.deleteSuccess, context);
                    Navigator.pop(context);
                  },
                  child: Text(localizations.delete)),
            ],
          );
        });
  }
}

class HistoryRecord extends StatefulWidget {
  final HistoryItem history;
  final ProxyServer proxyServer;

  const HistoryRecord({super.key, required this.history, required this.proxyServer});

  @override
  State<StatefulWidget> createState() {
    return _HistoryRecordState();
  }
}

class _HistoryRecordState extends State<HistoryRecord> {
  final GlobalKey<RequestListState> requestStateKey = GlobalKey<RequestListState>();

  ///搜索key
  final GlobalKey<MobileSearchState> searchStateKey = GlobalKey<MobileSearchState>();

  final MultiSelectController multiSelectController = MultiSelectController();

  var searchEnabled = ValueNotifier(false);

  AppLocalizations get localizations => AppLocalizations.of(context)!;

  @override
  void dispose() {
    searchEnabled.dispose();
    multiSelectController.clear();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        appBar: ShadHeader(
            height: 38,
            title: localizations.historyRecordTitle(widget.history.requestLength, widget.history.name),
            actions: [
                  PopupMenuButton(
                      offset: const Offset(0, 30),
                      icon: const Icon(Icons.more_vert_outlined),
                      itemBuilder: (BuildContext context) {
                        return [
                          PopupMenuItem(
                              onTap: () {
                                if (searchEnabled.value) {
                                  searchStateKey.currentState?.showSearch();
                                  return;
                                }
                                searchEnabled.value = true;
                              },
                              child: IconText(icon: const Icon(Icons.search), text: localizations.search)),
                          PopupMenuItem(
                              onTap: () => export(context),
                              child: IconText(icon: const Icon(Icons.share), text: localizations.viewExport)),
                          PopupMenuItem(
                              onTap: () async {
                                multiSelectController.toggleSelectionMode();
                              },
                              child: IconText(
                                  icon: const Icon(Icons.checklist_rtl_outlined), text: localizations.selectAction)),
                          PopupMenuItem(
                              onTap: () async {
                                var requests = requestStateKey.currentState?.currentView();
                                if (requests == null) return;
                                //重发所有请求
                                _repeatAllRequests(requests.toList(), widget.proxyServer,
                                    context: mounted ? context : null);
                              },
                              child: IconText(icon: const Icon(Icons.repeat), text: localizations.repeatAllRequests)),
                        ];
                      }),
                ]),
        body: futureWidget(
          loading: true,
          HistoryStorage.instance.then((storage) => storage.getRequests(widget.history)),
          (data) => RequestListWidget(
            proxyServer: widget.proxyServer,
            list: ListenableList(data),
            key: requestStateKey,
            selectionController: multiSelectController,
          ),
        ));
  }

  //导出har
  Future<void> export(BuildContext context) async {
    var item = widget.history;
    requestStateKey.currentState?.export(context, item.name);
  }
}
