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
import 'dart:io';

import 'package:date_format/date_format.dart';
import 'package:proxypin/network/http/content_type.dart' as pc;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:proxypin/l10n/app_localizations.dart';
import 'package:flutter_toastr/flutter_toastr.dart';
import 'package:proxypin/network/bin/server.dart';
import 'package:proxypin/network/components/manager/request_rewrite_manager.dart';
import 'package:proxypin/network/components/manager/rewrite_rule.dart';
import 'package:proxypin/network/components/manager/script_manager.dart';
import 'package:proxypin/network/channel/host_port.dart';
import 'package:proxypin/network/http/http.dart';
import 'package:proxypin/network/http/http_client.dart';
import 'package:proxypin/network/util/cache.dart';
import 'package:proxypin/storage/favorites.dart';
import 'package:proxypin/ui/component/multi_select_controller.dart';
import 'package:proxypin/ui/component/utils.dart';
import 'package:proxypin/ui/component/widgets.dart';
import 'package:proxypin/ui/configuration.dart';
import 'package:proxypin/ui/content/panel.dart';
import 'package:proxypin/ui/desktop/request/request.dart';
import 'package:proxypin/ui/mobile/request/repeat.dart';
import 'package:proxypin/ui/mobile/request/request_editor.dart';
import 'package:proxypin/ui/mobile/setting/request_rewrite.dart';
import 'package:proxypin/ui/mobile/setting/script.dart';
import 'package:proxypin/utils/curl.dart';
import 'package:proxypin/utils/keyword_highlight.dart';
import 'package:proxypin/utils/lang.dart';
import 'package:proxypin/utils/navigator.dart';
import 'package:shared_preferences/shared_preferences.dart';

///请求行
class RequestRow extends StatefulWidget {
  final int index;
  final HttpRequest request;
  final ProxyServer proxyServer;
  final bool displayDomain;
  final Function(HttpRequest)? onRemove;
  final MultiSelectController selectionController;
  final RequestSelectionHandlers selectionHandlers;
  final Function(VoidCallback refresh)? onMount; // 注册刷新回调

  const RequestRow({
    super.key,
    required this.request,
    required this.proxyServer,
    this.displayDomain = true,
    this.onRemove,
    required this.selectionController,
    required this.index,
    required this.selectionHandlers,
    this.onMount,
  });

  @override
  State<StatefulWidget> createState() {
    return RequestRowState();
  }
}

class RequestRowState extends State<RequestRow> {
  static ExpiringCache<String, Image> imageCache = ExpiringCache<String, Image>(const Duration(minutes: 5));
  static const int maxAutoReadEntries = 5000;
  static LruCacheSet<String> autoReadRequests = LruCacheSet<String>(5000);

  static bool markAutoRead(String requestId) {
    return autoReadRequests.add(requestId);
  }

  static void removeAutoReadByIds(Iterable<String> requestIds) {
    autoReadRequests.removeAll(requestIds);
  }

  late HttpRequest request;
  HttpResponse? response;
  bool selected = false;
  Color? highlightColor; //高亮颜色

  AppLocalizations get localizations => AppLocalizations.of(availableContext)!;

  @override
  void initState() {
    request = widget.request;
    response = request.response;
    super.initState();
    // 注册响应刷新回调
    widget.onMount?.call(() {
      response = request.response;
      if (!mounted) return;
      setState(() {});
    });
  }

  Color? color(String url) {
    if (highlightColor != null) {
      return highlightColor;
    }

    highlightColor = KeywordHighlights.getHighlightColor(url);
    if (highlightColor != null) {
      return highlightColor;
    }

    // 只有开启「自动已读」时已读行才置灰；未开启时已读状态仅影响未读蓝点，不改文字颜色
    if (AppConfiguration.current?.autoReadEnabled == true && autoReadRequests.contains(request.requestId)) {
      return Colors.grey;
    }
    return null;
  }

  BuildContext getContext() => mounted ? super.context : NavigatorHelper().context;

  BuildContext get availableContext => getContext();

  @override
  Widget build(BuildContext context) {
    String url = widget.displayDomain ? request.requestUrl : request.path;
    var operationName = request.graphqlOperationName;

    var time = formatDate(request.requestTime, [HH, ':', nn, ':', ss]);
    // HttpCanary：列表只显示一个包大小（优先响应大小，无响应时回退请求大小）
    var sizeText = getPackage(response?.packageSize ?? request.packageSize);

    var highlightColor = color(url);

    // 应用名称：优先进程名，回退到域名
    var appName = request.processInfo?.name ?? request.hostAndPort?.domain ?? url;
    // 是否已读（点开过详情）：未读时左侧显示蓝色小点
    final bool read = autoReadRequests.contains(request.requestId);

    // 状态信息
    Color statusColor;
    IconData statusIcon;
    String statusText;
    if (response == null || response!.status.code < 0) {
      statusColor = const Color(0xFFFF9E05);
      statusIcon = Icons.error_outline;
      statusText = '无响应';
    } else {
      final code = response!.status.code;
      statusColor = code >= 300 && code < 400
          ? const Color(0xFF1976D2)
          : code >= 400 && code < 500
              ? const Color(0xFFFF9E05)
              : code >= 500
                  ? const Color(0xFFE53935)
                  : const Color(0xFF388E3C);
      statusIcon = code >= 400 ? Icons.error_outline : Icons.check_circle_outline;
      statusText = '${response!.status.code} ${response!.status.reasonPhrase}'.trim();
    }

    var ct = response?.contentType;

    return GestureDetector(
        onLongPressStart: menu,
        child: ListTile(
          visualDensity: const VisualDensity(vertical: -4),
          minLeadingWidth: 44,
          selected: selected ||
              (widget.selectionController.isSelectionMode && widget.selectionController.contains(request.requestId)),
          textColor: highlightColor,
          selectedColor: highlightColor,
          leading: rowLeading(),
          title: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 第一行：[未读蓝点] + 应用名(撑满) + 灰色圆形序号 + 时间(贴右)
              Row(children: [
                Expanded(
                    child: Row(children: [
                  if (!read)
                    Container(
                        width: 6,
                        height: 6,
                        margin: const EdgeInsets.only(right: 6),
                        decoration: const BoxDecoration(color: Colors.blue, shape: BoxShape.circle)),
                  Flexible(
                      child: Text(appName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500))),
                  const SizedBox(width: 5),
                  _indexBadge(widget.index),
                ])),
                const SizedBox(width: 8),
                Text(time, style: const TextStyle(fontSize: 11, color: Colors.grey)),
              ]),
              const SizedBox(height: 3),
              // 第二行：METHOD url 独占整行
              Row(children: [
                Expanded(
                    child: Text.rich(
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        TextSpan(style: TextStyle(fontSize: 13, color: highlightColor), children: [
                          TextSpan(text: '${request.method.name} $url'),
                          if (operationName != null) graphqlOperationSpan(request, fontSize: 13)!,
                        ]))),
              ]),
              const SizedBox(height: 3),
              // 第三行：状态 + (右推) + 类型圆标 + 单个包大小
              Row(children: [
                Icon(statusIcon, size: 13, color: statusColor),
                const SizedBox(width: 4),
                Expanded(
                    child: Text(statusText,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontSize: 12, color: statusColor))),
                const SizedBox(width: 8),
                _typeBadge(ct),
                const SizedBox(width: 6),
                Text(sizeText, style: const TextStyle(fontSize: 11, color: Colors.grey)),
              ]),
            ],
          ),
          subtitle: null,
          trailing: null,
          contentPadding:
              Platform.isIOS ? const EdgeInsets.symmetric(horizontal: 8) : const EdgeInsets.only(left: 3, right: 0),
          onTap: () {
            if (widget.selectionController.isSelectionMode) {
              widget.selectionController.toggle(request.requestId);
              return;
            }

            // 点开详情即标记已读：左侧未读蓝点消失（与“自动已读”开关无关）
            if (markAutoRead(request.requestId)) {
              setState(() {});
            }

            Navigator.of(getContext()).push(MaterialPageRoute(builder: (context) {
              return NetworkTabController(
                  proxyServer: widget.proxyServer,
                  httpRequest: request,
                  httpResponse: response,
                  title: Text(localizations.captureDetail, style: const TextStyle(fontSize: 16)));
            }));
          },
        ));
  }

  Widget? rowLeading() {
    var icon = appIcon();
    if (!widget.selectionController.isSelectionMode) {
      return icon;
    }

    bool isSelected = widget.selectionController.contains(request.requestId);
    var checkbox = Icon(isSelected ? Icons.check_box_outlined : Icons.check_box_outline_blank_outlined,
        size: 20, color: isSelected ? Theme.of(context).colorScheme.primary : null);

    if (icon == null) {
      return checkbox;
    }

    return Row(mainAxisSize: MainAxisSize.min, children: [checkbox, const SizedBox(width: 6), icon]);
  }

  Widget? appIcon() {
    if (Platform.isIOS) {
      return null;
    }
    if (request.processInfo == null) {
      return const Icon(Icons.question_mark, size: 42);
    }

    //如果有缓存图标直接返回图标
    if (request.processInfo!.hasCacheIcon) {
      return imageCache.putIfAbsent(request.processInfo!.id, () {
        return Image.memory(request.processInfo!.cacheIcon!, width: 42, gaplessPlayback: true);
      });
    }

    return FutureBuilder(
        future: request.processInfo!.getIcon(),
        builder: (BuildContext context, AsyncSnapshot<Uint8List> snapshot) {
          if (snapshot.hasData) {
            return Image.memory(snapshot.data!, width: 42);
          }
          return const SizedBox(width: 42);
        });
  }

  /// HttpCanary 类型标记背景色（蓝色 #369EDB，圆形）
  static const Color _hcTypeBg = Color(0xFF369EDB);

  /// 序号徽章：应用名右侧的灰色圆形小按钮
  Widget _indexBadge(int index) {
    return Container(
        width: 16,
        height: 16,
        alignment: Alignment.center,
        decoration: const BoxDecoration(color: Colors.grey, shape: BoxShape.circle),
        child: Text('$index',
            style: const TextStyle(
                fontSize: 10, color: Colors.white, fontWeight: FontWeight.w500, height: 1.0)));
  }

  /// 类型圆标：图片/视频/JSON 用 HttpCanary 图标包矢量（蓝色圆底），
  /// 其余 MIME 用「单字母白色圆标」（对齐 HttpCanary 动态绘制的字母圆标）。
  Widget _typeBadge(pc.ContentType? ct) {
    const double badgeSize = 18;
    const double iconSize = 12;

    String? asset;
    if (ct == pc.ContentType.image) {
      asset = 'assets/hc_icons/05_image_photo.svg';
    } else if (ct == pc.ContentType.video) {
      asset = 'assets/hc_icons/07_video_play.svg';
    } else if (ct == pc.ContentType.json) {
      asset = 'assets/hc_icons/08_json_braces.svg';
    }

    if (asset != null) {
      return Container(
          width: badgeSize,
          height: badgeSize,
          alignment: Alignment.center,
          decoration: const BoxDecoration(color: _hcTypeBg, shape: BoxShape.circle),
          child: SvgPicture.asset(asset, width: iconSize, height: iconSize));
    }

    // 未匹配图示的 MIME：单字母白色圆标
    var letter = ct == null ? '?' : ct.name[0].toUpperCase();
    return Container(
        width: badgeSize,
        height: badgeSize,
        alignment: Alignment.center,
        decoration: const BoxDecoration(color: _hcTypeBg, shape: BoxShape.circle),
        child: Text(letter,
            style: const TextStyle(
                fontSize: 11, color: Colors.white, fontWeight: FontWeight.bold, height: 1.0)));
  }

  ///菜单
  void menu(details) {
    setState(() {
      selected = true;
    });

    var globalPosition = details.globalPosition;
    MediaQueryData mediaQuery = MediaQuery.of(context);
    var position = RelativeRect.fromLTRB(globalPosition.dx, globalPosition.dy, globalPosition.dx, globalPosition.dy);
    final selectionMode = widget.selectionController.isSelectionMode;
    // Trigger haptic feedback
    if (Platform.isAndroid) HapticFeedback.mediumImpact();

    showMenu(
        context: context,
        constraints: BoxConstraints(maxWidth: mediaQuery.size.width * 0.88),
        position: position,
        items: [
          PopupMenuContainer(
              child: Column(
            children: selectionMode
                ? [
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Padding(
                          padding: EdgeInsets.only(left: 20, top: 5),
                          child: Text(localizations.selectAction, style: Theme.of(context).textTheme.bodyLarge)),
                    ),
                    menuItem(
                      left: itemButton(
                          onPressed: () {
                            widget.selectionHandlers.onExportSelected?.call();
                            Navigator.maybePop(availableContext);
                          },
                          label: localizations.export,
                          icon: Icons.checklist_rtl_outlined),
                      right: itemButton(
                          onPressed: () {
                            widget.selectionHandlers.onRepeatSelected?.call();
                            Navigator.maybePop(availableContext);
                          },
                          label: localizations.repeat,
                          icon: Icons.delete_outline),
                    ),
                    SizedBox(height: 1),
                    Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                      itemButton(
                          onPressed: () {
                            widget.selectionHandlers.onDeleteSelected?.call();
                            Navigator.maybePop(availableContext);
                          },
                          label: localizations.delete,
                          icon: Icons.delete_outline),
                      SizedBox(width: 15),
                    ]),
                  ]
                : [
                    //复制url
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Padding(
                          padding: EdgeInsets.only(left: 20, top: 5),
                          child: Text(localizations.selectAction, style: Theme.of(context).textTheme.bodyLarge)),
                    ),
                    //copy
                    menuItem(
                      left: itemButton(
                          onPressed: () {
                            Clipboard.setData(ClipboardData(text: request.requestUrl)).then((value) {
                              FlutterToastr.show(localizations.copied, getContext());
                              Navigator.maybePop(getContext());
                            });
                          },
                          label: localizations.copyUrl,
                          icon: Icons.link,
                          iconSize: 22),
                      right: itemButton(
                          onPressed: () {
                            Clipboard.setData(ClipboardData(text: curlRequest(request))).then((value) {
                              FlutterToastr.show(localizations.copied, getContext());
                              Navigator.maybePop(getContext());
                            });
                          },
                          label: localizations.copyCurl,
                          icon: Icons.code),
                    ),
                    //repeat
                    menuItem(
                      left: itemButton(
                          onPressed: () {
                            onRepeat(request);
                            Navigator.maybePop(getContext());
                          },
                          label: localizations.repeat,
                          icon: Icons.repeat_one),
                      right: itemButton(
                          onPressed: () => showCustomRepeat(request),
                          label: localizations.customRepeat,
                          icon: Icons.repeat),
                    ),
                    //favorite and edit
                    menuItem(
                      left: itemButton(
                          onPressed: () {
                            FavoriteStorage.addFavorite(widget.request);
                            FlutterToastr.show(localizations.addSuccess, availableContext);
                            Navigator.maybePop(availableContext);
                          },
                          label: localizations.favorite,
                          icon: Icons.favorite_outline),
                      right: itemButton(
                          onPressed: () async {
                            await Navigator.maybePop(availableContext);

                            var pageRoute = MaterialPageRoute(
                                builder: (context) =>
                                    MobileRequestEditor(request: widget.request, proxyServer: widget.proxyServer));
                            Navigator.push(getContext(), pageRoute);
                          },
                          label: localizations.editRequest,
                          icon: Icons.replay_outlined),
                    ),
                    //script and rewrite
                    menuItem(
                      left: itemButton(
                          onPressed: () async {
                            Navigator.maybePop(availableContext);

                            var scriptManager = await ScriptManager.instance;
                            var url = request.domainPath;
                            var scriptItem = scriptManager.list.firstWhereOrNull((it) => it.urls.contains(url));
                            String? script = scriptItem == null ? null : await scriptManager.getScript(scriptItem);

                            var pageRoute = MaterialPageRoute(
                                builder: (context) => ScriptEdit(
                                    scriptItem: scriptItem,
                                    script: script,
                                    urls: scriptItem?.urls ?? [url],
                                    title: request.hostAndPort?.host));

                            Navigator.push(getContext(), pageRoute);
                          },
                          label: localizations.script,
                          icon: Icons.javascript_outlined),
                      right: itemButton(
                          onPressed: () async {
                            Navigator.maybePop(availableContext);
                            bool isRequest = response == null;
                            var requestRewrites = await RequestRewriteManager.instance;

                            var ruleType = isRequest ? RuleType.requestReplace : RuleType.responseReplace;
                            var rule = requestRewrites.getRequestRewriteRule(request, ruleType);

                            var rewriteItems = await requestRewrites.getRewriteItems(rule);

                            var pageRoute = MaterialPageRoute(
                                builder: (_) => RewriteRule(rule: rule, items: rewriteItems, request: request));
                            var context = availableContext;
                            if (context.mounted) Navigator.push(context, pageRoute);
                          },
                          label: localizations.requestRewrite,
                          icon: Icons.edit_outlined),
                    ),
                    menuItem(
                      left: itemButton(
                          onPressed: () {
                            highlightColor = Theme.of(availableContext).colorScheme.primary;
                            Navigator.maybePop(availableContext);
                          },
                          label: localizations.highlight,
                          icon: Icons.highlight_outlined),
                      right: itemButton(
                          onPressed: () {
                            AppConfiguration.current?.autoReadEnabled = !AppConfiguration.current!.autoReadEnabled;
                            highlightColor = Colors.grey;
                            Navigator.maybePop(availableContext);
                          },
                          label: localizations.autoRead,
                          icon: AppConfiguration.current?.autoReadEnabled == true
                              ? Icons.check_box_outlined
                              : Icons.check_box_outline_blank_outlined),
                    ),
                    SizedBox(height: 1),
                    menuItem(
                      left: itemButton(
                          onPressed: () {
                            widget.selectionController.toggle(request.requestId);
                            Navigator.maybePop(availableContext);
                          },
                          label: localizations.select,
                          icon: Icons.checklist_rtl_outlined),
                      right: itemButton(
                          onPressed: () {
                            widget.onRemove?.call(request);
                            FlutterToastr.show(localizations.deleteSuccess, availableContext);
                            Navigator.maybePop(availableContext);
                          },
                          label: localizations.delete,
                          icon: Icons.delete_outline),
                    ),
                  ],
          )),
        ]).then((value) {
      selected = false;
      if (mounted) setState(() {});
    });
  }

  //显示高级重发
  Future<void> showCustomRepeat(HttpRequest request) async {
    await Navigator.maybePop(availableContext);
    var pageRoute = MaterialPageRoute(
        builder: (context) => futureWidget(SharedPreferences.getInstance(),
            (prefs) => MobileCustomRepeat(onRepeat: () => onRepeat(request), prefs: prefs)));

    Navigator.push(getContext(), pageRoute);
  }

  void onRepeat(HttpRequest request) {
    var httpRequest = request.copy(uri: request.requestUrl);
    var proxyInfo = widget.proxyServer.isRunning ? ProxyInfo.of("127.0.0.1", widget.proxyServer.port) : null;
    HttpClients.proxyRequest(httpRequest, proxyInfo: proxyInfo);

    if (mounted) {
      FlutterToastr.show(localizations.reSendRequest, context);
    }
  }

  Widget itemButton(
      {required String label, required IconData icon, required Function() onPressed, double iconSize = 20}) {
    var theme = Theme.of(context);
    var style = theme.textTheme.bodyMedium;
    return TextButton.icon(
        onPressed: onPressed,
        label: Text(label, style: style),
        icon: Icon(icon, size: iconSize, color: theme.colorScheme.primary.withValues(alpha: 0.65)));
  }

  Widget menuItem({required Widget left, required Widget right}) {
    return Row(
      children: [
        SizedBox(width: 130, child: Align(alignment: Alignment.centerLeft, child: left)),
        Expanded(child: Align(alignment: Alignment.centerLeft, child: right))
      ],
    );
  }
}
