import 'package:proxypin/network/http/http.dart';

/// MCP 断点拦截队列
///
/// 当 [RequestBreakpointInterceptor] 命中断点规则时，除了打开 UI 窗口，
/// 同时把挂起信息写入此队列，供 MCP Tool 查询和放行。
class McpInterceptQueue {
  static final McpInterceptQueue instance = McpInterceptQueue._();
  McpInterceptQueue._();

  final Map<String, _PendingItem> _pending = {};

  void addPendingRequest(String requestId, HttpRequest request) {
    _pending[requestId] = _PendingItem(
      type: 'request',
      requestId: requestId,
      pausedAt: DateTime.now(),
      requestJson: request.toJson(),
    );
  }

  void addPendingResponse(String requestId, HttpRequest request, HttpResponse response) {
    _pending[requestId] = _PendingItem(
      type: 'response',
      requestId: requestId,
      pausedAt: DateTime.now(),
      requestJson: request.toJson(),
      responseJson: response.toJson(),
    );
  }

  void remove(String requestId) => _pending.remove(requestId);

  bool hasPending(String requestId) => _pending.containsKey(requestId);

  String? getPendingType(String requestId) => _pending[requestId]?.type;

  List<Map<String, dynamic>> getPendingList() => _pending.values.map((e) => e.toJson()).toList();

  Map<String, dynamic>? getRawRequestJson(String requestId) => _pending[requestId]?.requestJson;

  Map<String, dynamic>? getRawResponseJson(String requestId) => _pending[requestId]?.responseJson;
}

class _PendingItem {
  final String type; // 'request' | 'response'
  final String requestId;
  final DateTime pausedAt;
  final Map<String, dynamic> requestJson;
  final Map<String, dynamic>? responseJson;

  _PendingItem({
    required this.type,
    required this.requestId,
    required this.pausedAt,
    required this.requestJson,
    this.responseJson,
  });

  Map<String, dynamic> toJson() => {
        'requestId': requestId,
        'type': type,
        'pausedAt': pausedAt.toIso8601String(),
        'waitingSeconds': DateTime.now().difference(pausedAt).inSeconds,
        'request': requestJson,
        if (responseJson != null) 'response': responseJson,
      };
}
