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

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_toastr/flutter_toastr.dart';
import 'package:proxypin/l10n/app_localizations.dart';
import 'package:proxypin/network/bin/server.dart';
import 'package:proxypin/network/http/http.dart';
import 'package:proxypin/storage/favorites.dart';
import 'package:proxypin/ui/component/state_component.dart';
import 'package:proxypin/ui/component/utils.dart';
import 'package:proxypin/ui/content/body.dart';
import 'package:proxypin/ui/content/menu.dart';
import 'package:proxypin/ui/component/multi_window_compat.dart';
import 'package:proxypin/utils/export_request.dart';
import 'package:proxypin/utils/lang.dart';
import 'package:proxypin/utils/platform.dart';

/// HttpCanary 主题色
const _hcOrange = Color(0xFFFF9E05);
const _hcTabIndicator = Color(0xFF369EDB); // HttpCanary 真实 colorAccent（取自 APK resources.arsc）
const _hcLabelGray = Color(0xFF666666);
const _hcTextBlack = Color(0xFF333333);
const _hcDivider = Color(0xFFEEEEEE);
const _hcSectionBg = Color(0xFFF5F5F5);

///网络请求详情页
///@Author: wanghongen
class NetworkTabController extends StatefulWidget {
  static GlobalKey<NetworkTabState>? currentKey;
  final String? windowId;
  final ProxyServer? proxyServer;
  final ValueWrap<HttpRequest> request = ValueWrap();
  final ValueWrap<HttpResponse> response = ValueWrap();
  final Widget? title;
  final TextStyle? tabStyle;

  NetworkTabController(
      {HttpRequest? httpRequest,
      HttpResponse? httpResponse,
      this.title,
      this.tabStyle,
      this.proxyServer,
      this.windowId})
      : super(key: GlobalKey<NetworkTabState>()) {
    currentKey = key as GlobalKey<NetworkTabState>;
    request.set(httpRequest);
    response.set(httpResponse);
  }

  void change(HttpRequest? request, HttpResponse? response) {
    this.request.set(request);
    this.response.set(response);
    var state = key as GlobalKey<NetworkTabState>;
    state.currentState?.changeState();
  }

  void changeState() {
    var state = key as GlobalKey<NetworkTabState>;
    state.currentState?.changeState();
  }

  @override
  State<StatefulWidget> createState() {
    return NetworkTabState();
  }

  static NetworkTabController? get current => currentKey?.currentWidget as NetworkTabController?;
}

class NetworkTabState extends State<NetworkTabController> with SingleTickerProviderStateMixin {
  final tabs = [
    '总览',
    '请求',
    '响应',
  ];

  final TextStyle textStyle = const TextStyle(fontSize: 14);
  late TabController _tabController;

  final GlobalKey<HttpBodyState> requestHttpBodyKey = GlobalKey<HttpBodyState>();
  final GlobalKey<HttpBodyState> responseHttpBodyKey = GlobalKey<HttpBodyState>();

  void changeState() {
    setState(() {});
  }

  AppLocalizations get localizations => AppLocalizations.of(context)!;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: tabs.length, vsync: this);
    _tabController.addListener(() {
      if (_tabController.index != 1) {
        requestHttpBodyKey.currentState?.hideSearchOverlay();
      }
      if (_tabController.index != 2) {
        responseHttpBodyKey.currentState?.hideSearchOverlay();
      }
    });

    if (widget.windowId != null) {
      HardwareKeyboard.instance.addHandler(onKeyEvent);
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    HardwareKeyboard.instance.removeHandler(onKeyEvent);
    super.dispose();
  }

  bool onKeyEvent(KeyEvent event) {
    if ((HardwareKeyboard.instance.isMetaPressed || HardwareKeyboard.instance.isControlPressed) &&
        event.logicalKey == LogicalKeyboardKey.keyW) {
      HardwareKeyboard.instance.removeHandler(onKeyEvent);
      WindowController.fromWindowId(widget.windowId!).close();
      return true;
    }

    return false;
  }

  @override
  Widget build(BuildContext context) {
    var tabBar = TabBar(
      padding: const EdgeInsets.only(bottom: 0),
      controller: _tabController,
      labelColor: _hcTextBlack,
      unselectedLabelColor: Colors.grey,
      indicatorColor: _hcTabIndicator,
      indicatorWeight: 3,
      indicatorSize: TabBarIndicatorSize.label,
      dividerColor: _hcDivider,
      labelPadding: const EdgeInsets.symmetric(horizontal: 10),
      labelStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
      unselectedLabelStyle: const TextStyle(fontSize: 14),
      tabs: tabs.map((title) => Tab(child: Text(title, maxLines: 1))).toList(),
    );

    return Scaffold(
      endDrawerEnableOpenDragGesture: false,
      appBar: AppBar(
        systemOverlayStyle: SystemUiOverlayStyle.light,
        backgroundColor: _hcOrange,
        elevation: 0,
        centerTitle: true,
        title: const Text('抓包内容', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w500, color: Colors.white)),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.of(context).maybePop(),
        ),
        actions: [
          _SaveButton(request: widget.request.get()),
          ShareWidget(proxyServer: widget.proxyServer, request: widget.request.get(), response: widget.response.get()),
          _FavoriteButton(request: widget.request.get()),
          const SizedBox(width: 4),
        ],
        bottom: tabBar,
      ),
      body: TabBarView(
        physics: Platforms.isDesktop() ? const NeverScrollableScrollPhysics() : null, //桌面禁止滑动
        controller: _tabController,
        children: [
          SelectionArea(child: General(widget.request, widget.response)),
          KeepAliveWrapper(child: request()),
          KeepAliveWrapper(child: response()),
        ],
      ),
    );
  }

  Widget request() {
    var req = widget.request.get();
    if (req == null) {
      return const SizedBox();
    }

    var path = req.path;
    try {
      path = Uri.decodeFull(path);
    } catch (_) {}

    final query = req.requestUri?.hasQuery == true ? '?${req.requestUri!.query}' : '';
    final summary = '${req.method.name} $path$query ${_shortProtocol(req.protocolVersion)}';

    return _HttpCanaryMessageTabs(
      message: req,
      summaryLine: summary,
      isRequest: true,
    );
  }

  Widget response() {
    var resp = widget.response.get();
    if (resp == null) {
      return const SizedBox();
    }

    final summary = '${_shortProtocol(resp.protocolVersion)} ${resp.status.code}';

    return _HttpCanaryMessageTabs(
      message: resp,
      summaryLine: summary,
      isRequest: false,
      statusCode: resp.status.code,
    );
  }
}

/// 顶栏保存按钮
class _SaveButton extends StatelessWidget {
  final HttpRequest? request;

  const _SaveButton({this.request});

  @override
  Widget build(BuildContext context) {
    return IconButton(
      icon: const Icon(Icons.save_alt, color: Colors.white),
      tooltip: '保存',
      onPressed: () {
        if (request == null) return;
        _showSaveDialog(context, request!);
      },
    );
  }

  void _showSaveDialog(BuildContext context, HttpRequest request) {
    final localizations = AppLocalizations.of(context)!;
    showDialog(
      context: context,
      builder: (menuContext) {
        return AlertDialog(
          title: Text(localizations.save),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                ListTile(
                  visualDensity: const VisualDensity(vertical: -3),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
                  title: Text(localizations.request),
                  onTap: () {
                    Navigator.of(menuContext).pop();
                    WidgetsBinding.instance.addPostFrameCallback((_) {
                      exportRequest(request);
                    });
                  },
                ),
                ListTile(
                  visualDensity: const VisualDensity(vertical: -3),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
                  title: Text(localizations.requestBody),
                  onTap: () {
                    Navigator.of(menuContext).pop();
                    WidgetsBinding.instance.addPostFrameCallback((_) {
                      exportRequestBody(request);
                    });
                  },
                ),
                ListTile(
                  visualDensity: const VisualDensity(vertical: -3),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
                  title: Text(localizations.response),
                  onTap: () {
                    Navigator.of(menuContext).pop();
                    WidgetsBinding.instance.addPostFrameCallback((_) {
                      exportResponse(request.response);
                    });
                  },
                ),
                ListTile(
                  visualDensity: const VisualDensity(vertical: -3),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
                  title: Text(localizations.responseBody),
                  onTap: () {
                    Navigator.of(menuContext).pop();
                    WidgetsBinding.instance.addPostFrameCallback((_) {
                      exportResponseBody(request.response);
                    });
                  },
                ),
                ListTile(
                  visualDensity: const VisualDensity(vertical: -3),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
                  title: Text(localizations.requestResponse),
                  onTap: () {
                    Navigator.of(menuContext).pop();
                    WidgetsBinding.instance.addPostFrameCallback((_) {
                      exportRequestAndResponse(request, request.response);
                    });
                  },
                ),
                ListTile(
                  visualDensity: const VisualDensity(vertical: -3),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
                  title: const Text("HAR"),
                  onTap: () {
                    Navigator.of(menuContext).pop();
                    WidgetsBinding.instance.addPostFrameCallback((_) {
                      exportHar(request);
                    });
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

/// 顶栏收藏按钮
class _FavoriteButton extends StatelessWidget {
  final HttpRequest? request;

  const _FavoriteButton({this.request});

  @override
  Widget build(BuildContext context) {
    return IconButton(
      icon: const Icon(Icons.favorite_border, color: Colors.white),
      tooltip: '收藏',
      onPressed: () {
        if (request == null) return;
        FavoriteStorage.addFavorite(request!);
        FlutterToastr.show(AppLocalizations.of(context)!.addSuccess, context);
      },
    );
  }
}

/// HttpCanary 风格的请求/响应详情子 Tab（Headers / Text / Hex / Raw / 预览）
class _HttpCanaryMessageTabs extends StatefulWidget {
  final HttpMessage message;
  final String summaryLine;
  final bool isRequest;
  final int? statusCode; // 有值时状态码着色

  const _HttpCanaryMessageTabs(
      {required this.message, required this.summaryLine, required this.isRequest, this.statusCode});

  @override
  State<_HttpCanaryMessageTabs> createState() => _HttpCanaryMessageTabsState();
}

class _HttpCanaryMessageTabsState extends State<_HttpCanaryMessageTabs> with SingleTickerProviderStateMixin {
  final tabs = const ['Headers', 'Text', 'Hex', 'Raw', '预览'];
  late TabController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TabController(length: tabs.length, vsync: this);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // 顶部请求行 / 状态行
        Container(
          width: double.infinity,
          color: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
          child: _summaryLine(),
        ),
        const Divider(height: 1, thickness: 1, color: _hcDivider),
        // 内容区
        Expanded(
          child: TabBarView(
            controller: _controller,
            physics: const NeverScrollableScrollPhysics(),
            children: [
              _headersTab(),
              _bodyTab(ViewType.text),
              _bodyTab(ViewType.hex),
              _bodyTab(ViewType.raw),
              _bodyTab(ViewType.preview),
            ],
          ),
        ),
        // 底部 Tab 切换
        Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            border: Border(top: BorderSide(color: _hcDivider)),
          ),
          child: SafeArea(
            top: false,
            child: TabBar(
              controller: _controller,
              labelColor: _hcTextBlack,
              unselectedLabelColor: Colors.grey,
              indicatorColor: _hcTabIndicator,
              indicatorWeight: 3,
              indicatorSize: TabBarIndicatorSize.label,
              labelStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
              unselectedLabelStyle: const TextStyle(fontSize: 13),
              tabs: tabs.map((t) => Tab(text: t)).toList(),
            ),
          ),
        ),
      ],
    );
  }

  /// 状态行：状态码按 2xx 绿 / 3xx 蓝 / 4xx 橙 / 5xx 红 着色
  Widget _summaryLine() {
    const base = TextStyle(fontSize: 15, color: _hcTextBlack, height: 1.4);
    final code = widget.statusCode;
    if (code == null) {
      return SelectableText(widget.summaryLine, style: base);
    }

    final text = widget.summaryLine;
    final index = text.lastIndexOf(code.toString());
    if (index < 0) {
      return SelectableText(text, style: base);
    }

    return SelectableText.rich(TextSpan(children: [
      TextSpan(text: text.substring(0, index), style: base),
      TextSpan(
          text: text.substring(index),
          style: base.copyWith(color: _statusColor(code), fontWeight: FontWeight.w600)),
    ]));
  }

  Widget _headersTab() {
    final headerEntries = <MapEntry<String, List<String>>>[];
    widget.message.headers.forEach((name, values) {
      headerEntries.add(MapEntry(name, values));
    });

    if (headerEntries.isEmpty) {
      return const Center(child: Text('No Headers', style: TextStyle(color: Colors.grey)));
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final entry in headerEntries) ...[
            for (int i = 0; i < entry.value.length; i++) ...[
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SelectableText(
                    '${entry.key}: ',
                    style: const TextStyle(fontSize: 14, color: Color(0xFF1976D2), fontWeight: FontWeight.w400),
                  ),
                  Expanded(
                    child: SelectableText(
                      entry.value[i],
                      style: const TextStyle(fontSize: 14, color: _hcTextBlack, height: 1.4),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 5),
            ],
          ],
        ],
      ),
    );
  }

  Widget _bodyTab(ViewType viewType) {
    if (widget.message.body == null || widget.message.body?.isEmpty == true) {
      return const Center(child: Text('No Body', style: TextStyle(color: Colors.grey)));
    }
    return HttpBodyWidget(
      httpMessage: widget.message,
      showToolbar: false,
      viewType: viewType,
    );
  }
}

/// 状态码配色：2xx 绿 / 3xx 蓝 / 4xx 橙 / 5xx 红
Color _statusColor(int code) {
  if (code >= 200 && code < 300) return const Color(0xFF388E3C);
  if (code >= 300 && code < 400) return const Color(0xFF1976D2);
  if (code >= 400 && code < 500) return const Color(0xFFFF9E05);
  if (code >= 500) return const Color(0xFFE53935);
  return _hcTextBlack;
}

/// 协议简写（HTTP/2 → h2）
String _shortProtocol(String protocol) {
  if (protocol == 'HTTP/2' || protocol == 'HTTP/2.0') return 'h2';
  return protocol;
}

class General extends StatelessWidget {
  final ValueWrap<HttpRequest> request;
  final ValueWrap<HttpResponse> response;

  const General(this.request, this.response, {super.key});

  @override
  Widget build(BuildContext context) {
    var request = this.request.get();
    if (request == null) {
      return const SizedBox();
    }
    var response = this.response.get();

    String requestUrl = request.requestUrl;
    try {
      requestUrl = Uri.decodeFull(request.requestUrl);
    } catch (_) {}

    final reqCt = request.headers.contentType.isEmpty ? '-' : request.headers.contentType;
    final respCt = response?.headers.contentType.isEmpty == true ? '-' : (response?.headers.contentType ?? '-');
    final remoteAddr = response?.remoteHost == null
        ? '-'
        : '${response!.remoteHost}${response.remotePort == null ? '' : ':${response.remotePort}'}';

    final statusText = response == null
        ? '进行中'
        : (response.status.code >= 200 && response.status.code < 300 ? '已完成' : '失败');

    final connection = request.headers.get('Connection')?.toLowerCase() ??
        response?.headers.get('Connection')?.toLowerCase() ??
        '';
    final keptAliveValue = (connection == 'keep-alive') ? 'true' : 'false';

    final rows = <Widget>[
      _buildUrlRow(requestUrl),
      _buildRow('状态', statusText),
      _buildRow('重写', 'false'),
      _buildRow('响应码', response?.status.toString() ?? '-',
          valueColor: response == null ? null : _statusColor(response.status.code)),
      _buildRow('协议', _shortProtocol(request.protocolVersion)),
      _buildRow('方法', request.method.name),
      _buildRow('域名', request.hostAndPort?.host ?? '-'),
      _buildRow('Kept Alive', keptAliveValue),
      _buildRow('Content-Type ↑', reqCt),
      _buildRow('Content-Type ↓', respCt),
      _buildRow('服务器', remoteAddr),
      _buildSectionHeader('时间'),
      _buildRow('开始时间', request.requestTime.formatMillisecond()),
      _buildRow('结束时间', response?.responseTime.formatMillisecond() ?? '-'),
      _buildRow('总时长', response?.costTime() ?? '-'),
      _buildSectionHeader('数据量'),
      _buildRow('请求', getPackage(request.packageSize)),
      _buildRow('响应', getPackage(response?.packageSize)),
    ];

    return ListView.builder(
      padding: EdgeInsets.zero,
      itemCount: rows.length,
      itemBuilder: (context, index) => rows[index],
    );
  }

  Widget _buildUrlRow(String url) {
    return Container(
      width: double.infinity,
      decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: _hcDivider))),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: SelectableText(
        url,
        style: const TextStyle(fontSize: 14, color: _hcTextBlack, height: 1.5),
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Container(
      width: double.infinity,
      color: _hcSectionBg,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Text(title, style: const TextStyle(fontSize: 13, color: _hcLabelGray)),
    );
  }

  Widget _buildRow(String label, String value, {Color? valueColor}) {
    return Container(
      decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: _hcDivider))),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              label,
              style: const TextStyle(fontSize: 14, color: _hcLabelGray),
            ),
          ),
          Expanded(
            child: SelectableText(
              value,
              style: TextStyle(
                  fontSize: 14, color: valueColor ?? _hcTextBlack, height: 1.4),
            ),
          ),
        ],
      ),
    );
  }
}

class Cookies extends StatelessWidget {
  final ValueWrap<HttpRequest> request;
  final ValueWrap<HttpResponse> response;

  const Cookies(this.request, this.response, {super.key});

  @override
  Widget build(BuildContext context) {
    var requestCookie = request.get()?.cookies.expand((cookie) => _cookieWidget(cookie)!);

    var responseCookie = response.get()?.headers.getList("Set-Cookie")?.expand((e) => _cookieWidget(e)!);
    return ListView(children: [
      requestCookie == null ? const SizedBox() : expansionTile("Request Cookies", requestCookie.toList()),
      const SizedBox(height: 15),
      responseCookie == null ? const SizedBox() : expansionTile("Response Cookies", responseCookie.toList()),
    ]);
  }

  Iterable<Widget>? _cookieWidget(String? cookie) {
    var headers = <Widget>[];

    cookie?.split(";").map((e) => Strings.splitFirst(e, "=")).where((element) => element != null).forEach((e) {
      headers.add(RowWidget(e!.key.trim(), e.value));
      headers.add(const Divider(thickness: 0.1, height: 10));
    });

    return headers;
  }
}

class RowWidget extends StatelessWidget {
  final String name;
  final String? value;
  final TextStyle textStyle = const TextStyle(fontSize: 14);

  const RowWidget(this.name, this.value, {super.key});

  @override
  Widget build(BuildContext context) {
    return Row(children: [
      Expanded(
          flex: 2,
          child: SelectableText(name,
              contextMenuBuilder: contextMenu,
              style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 14, color: _hcLabelGray))),
      Expanded(flex: 4, child: SelectableText(contextMenuBuilder: contextMenu, style: textStyle, value ?? ''))
    ]);
  }
}

Widget expansionTile(String title, List<Widget> content,
    {bool initiallyExpanded = true, ValueChanged<bool>? onExpansionChanged}) {
  return ExpansionTile(
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 14)),
      tilePadding: const EdgeInsets.only(left: 0),
      expandedAlignment: Alignment.topLeft,
      initiallyExpanded: initiallyExpanded,
      onExpansionChanged: onExpansionChanged,
      shape: const Border(),
      children: content);
}
