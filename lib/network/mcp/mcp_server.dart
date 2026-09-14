/*
 * Copyright 2024 Hongen Wang All rights reserved.
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
import 'dart:io' as io;
import 'dart:math';

import 'package:shared_preferences/shared_preferences.dart';

import 'package:proxypin/network/http/http.dart' as http;
import 'package:proxypin/network/mcp/mcp_tools.dart';
import 'package:proxypin/network/util/logger.dart';
import 'package:proxypin/utils/listenable_list.dart';

/// MCP (Model Context Protocol) Server
/// 同时提供两种传输：
///  - Streamable HTTP（/mcp，MCP 2025-03-26+ 规范的最新传输方式）
///  - 旧版 HTTP+SSE（/sse + /message，向后兼容 2024-11-05 客户端）
class McpServer {
  static McpServer? _instance;
  io.HttpServer? _server;
  int _port;
  bool _running = false;

  /// 默认端口
  static const int defaultPort = 9010;

  /// 服务端支持的最新的 MCP 协议版本
  static const String latestProtocolVersion = '2025-06-18';

  /// 服务端支持协商的协议版本列表
  static const List<String> supportedProtocolVersions = ['2024-11-05', '2025-03-26', '2025-06-18'];

  /// SSE 客户端连接列表（旧版传输）
  final List<_SseClient> _sseClients = [];

  /// Streamable HTTP 会话（Mcp-Session-Id -> session）
  final Map<String, _McpSession> _sessions = {};

  /// 抓包数据源引用
  ListenableList<http.HttpRequest>? _requestContainer;

  McpServer._({int port = defaultPort}) : _port = port;

  static const String _prefsKey = 'proxyPinMcp_port';
  static const String _autoStartKey = 'proxyPinMcp_autoStart';

  /// 从本地读取已保存的端口
  static Future<int?> loadPort() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getInt(_prefsKey);
    } catch (_) {}
    return null;
  }

  /// 保存端口到本地
  static Future<void> savePort(int port) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(_prefsKey, port);
    } catch (_) {}
  }

  /// 读取自动启动开关（默认开启）
  static Future<bool> loadAutoStart() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getBool(_autoStartKey) ?? true;
    } catch (_) {}
    return true;
  }

  /// 保存自动启动开关
  static Future<void> saveAutoStart(bool enabled) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_autoStartKey, enabled);
    } catch (_) {}
  }

  /// App 启动时调用：恢复已保存端口，并按配置自动启动服务
  Future<void> autoStartIfEnabled() async {
    final savedPort = await loadPort();
    if (savedPort != null && savedPort > 0 && savedPort < 65536 && savedPort != _port) {
      _port = savedPort;
    }

    final enabled = await loadAutoStart();
    if (!enabled || _running) return;

    try {
      await start();
      logger.i('MCP Server auto-started on port $_port');
    } catch (e) {
      logger.e('MCP Server auto-start failed: $e');
    }
  }

  static McpServer get instance {
    _instance ??= McpServer._();
    return _instance!;
  }

  bool get isRunning => _running;
  int get port => _port;

  set port(int value) {
    _port = value;
    savePort(value);
  }

  /// 绑定抓包数据容器
  void bindRequestContainer(ListenableList<http.HttpRequest> container) {
    _requestContainer = container;
  }

  ListenableList<http.HttpRequest>? get requestContainer => _requestContainer;

  /// 启动 MCP Server
  /// 如果指定端口被占用，会自动尝试递增端口（最多尝试 10 次）
  Future<void> start() async {
    if (_running) return;

    // 确保旧实例已关闭
    if (_server != null) {
      await stop();
    }

    // 尝试绑定端口，失败则自动递增
    int attempts = 0;
    const maxAttempts = 10;
    int tryPort = _port;

    while (attempts < maxAttempts) {
      try {
        // Android 上 anyIPv4 会被拒绝，必须用 loopback（仅本机访问）
        final bindAddr = io.Platform.isAndroid ? io.InternetAddress.loopbackIPv4 : io.InternetAddress.anyIPv4;
        _server = await io.HttpServer.bind(bindAddr, tryPort);
        _port = tryPort;
        _running = true;
        logger.i('MCP Server started on port $_port (streamable-http: /mcp, legacy-sse: /sse)');

        _server!.listen((io.HttpRequest httpRequest) {
          _handleRequest(httpRequest);
        }, onError: (error) {
          logger.e('MCP Server error: $error');
        });
        return;
      } catch (e) {
        attempts++;
        if (attempts >= maxAttempts) {
          logger.e('Failed to start MCP Server after $maxAttempts attempts: $e');
          rethrow;
        }
        logger.w('Port $tryPort is in use, trying port ${tryPort + 1}...');
        tryPort++;
      }
    }
  }

  /// 停止 MCP Server
  Future<void> stop() async {
    if (!_running) return;

    // 关闭所有 SSE 连接
    for (var client in _sseClients) {
      client.close();
    }
    _sseClients.clear();
    _sessions.clear();

    await _server?.close(force: true);
    _server = null;
    _running = false;
    logger.i('MCP Server stopped');
  }

  /// 处理 HTTP 请求路由
  void _handleRequest(io.HttpRequest request) {
    final path = request.uri.path;
    final method = request.method;

    // CORS 支持
    _setCorsHeaders(request.response);

    if (method == 'OPTIONS') {
      request.response
        ..statusCode = io.HttpStatus.ok
        ..close();
      return;
    }

    // 新版 Streamable HTTP 传输（MCP 2025-03-26+）
    if (path == '/mcp') {
      if (method == 'POST') {
        _handleStreamableHttp(request);
      } else if (method == 'GET') {
        _handleStreamableHttpGet(request);
      } else if (method == 'DELETE') {
        _handleSessionDelete(request);
      } else {
        _writeError(request.response, io.HttpStatus.methodNotAllowed, -32601, 'Method not allowed');
      }
      return;
    }

    // 旧版 HTTP+SSE 传输（向后兼容）
    if (path == '/sse' && method == 'GET') {
      _handleSseConnection(request);
    } else if (path == '/message' && method == 'POST') {
      _handleMessage(request);
    } else if (path == '/health' && method == 'GET') {
      _handleHealth(request);
    } else {
      request.response
        ..statusCode = io.HttpStatus.notFound
        ..write(jsonEncode({'error': 'Not Found'}))
        ..close();
    }
  }

  void _setCorsHeaders(io.HttpResponse response) {
    response.headers.set('Access-Control-Allow-Origin', '*');
    response.headers.set('Access-Control-Allow-Methods', 'GET, POST, DELETE, OPTIONS');
    response.headers.set('Access-Control-Allow-Headers', 'Content-Type, Mcp-Session-Id, MCP-Protocol-Version, Last-Event-ID');
    response.headers.set('Access-Control-Expose-Headers', 'Mcp-Session-Id, MCP-Protocol-Version');
    response.headers.set('Access-Control-Max-Age', '86400');
  }

  /// 健康检查端点
  void _handleHealth(io.HttpRequest request) {
    request.response
      ..statusCode = io.HttpStatus.ok
      ..headers.contentType = io.ContentType.json
      ..write(jsonEncode({
        'status': 'ok',
        'server': 'ProxyPin MCP Server',
        'version': '1.1.0',
        'protocolVersion': latestProtocolVersion,
        'supportedProtocolVersions': supportedProtocolVersions,
        'transports': {
          'streamableHttp': '/mcp',
          'legacySse': '/sse',
        },
        'requestCount': _requestContainer?.length ?? 0,
      }))
      ..close();
  }

  // ─────────────────────────────────────────────────────────────
  // Streamable HTTP 传输（MCP 2025-03-26 / 2025-06-18）
  // ─────────────────────────────────────────────────────────────

  /// 处理 POST /mcp：客户端发送 JSON-RPC 消息，服务端以 application/json 返回
  Future<void> _handleStreamableHttp(io.HttpRequest request) async {
    // 读取请求体
    final body = await utf8.decoder.bind(request).join();
    if (body.isEmpty) {
      _writeError(request.response, io.HttpStatus.badRequest, -32700, 'Empty request body');
      return;
    }

    dynamic decoded;
    try {
      decoded = jsonDecode(body);
    } catch (e) {
      _writeError(request.response, io.HttpStatus.badRequest, -32700, 'Parse error: $e');
      return;
    }

    // 仅支持单条消息（MCP 2025-03-26 起移除了 JSON-RPC 批处理）
    if (decoded is! Map<String, dynamic>) {
      _writeError(request.response, io.HttpStatus.badRequest, -32600, 'Invalid Request: expected a single JSON-RPC object');
      return;
    }

    final message = decoded;
    final method = message['method'] as String?;
    final hasId = message.containsKey('id') && message['id'] != null;

    // 会话校验（initialize 之外的消息若携带了未知会话 id 则拒绝；未携带则宽容放行）
    final sessionId = request.headers.value('Mcp-Session-Id');
    if (method != 'initialize' && sessionId != null && !_sessions.containsKey(sessionId)) {
      _writeError(request.response, io.HttpStatus.notFound, -32001, 'Session not found or expired');
      return;
    }
    final session = sessionId == null ? null : _sessions[sessionId];
    session?.touch();

    // 客户端发送的是通知或响应（无 id）→ 202 Accepted，无响应体
    if (!hasId) {
      logger.d('MCP notification/response via /mcp: $method');
      request.response
        ..statusCode = io.HttpStatus.accepted
        ..close();
      return;
    }

    // initialize：协商协议版本并创建会话
    if (method == 'initialize') {
      final params = message['params'] as Map<String, dynamic>? ?? {};
      final clientVersion = params['protocolVersion'] as String?;
      final negotiated = _negotiateProtocolVersion(clientVersion);

      final newSession = _McpSession(_generateSessionId(), negotiated);
      _sessions[newSession.id] = newSession;
      logger.i('MCP session created (streamable-http): ${newSession.id}, protocol: $negotiated');

      _writeJsonRpc(request.response, _initializeResult(message['id'], negotiated), sessionId: newSession.id);
      return;
    }

    // 其余请求：正常处理后以 application/json 返回
    final jsonRpcResponse = await _handleJsonRpc(message);
    _writeJsonRpc(request.response, jsonRpcResponse, sessionId: sessionId);
  }

  /// 处理 GET /mcp：用于服务端主动推送的 SSE 流。
  /// 本服务不主动推送消息，按规范返回 405。
  void _handleStreamableHttpGet(io.HttpRequest request) {
    request.response
      ..statusCode = io.HttpStatus.methodNotAllowed
      ..headers.contentType = io.ContentType.json
      ..write(jsonEncode({
        'jsonrpc': '2.0',
        'error': {'code': -32601, 'message': 'Server does not offer an SSE stream at this endpoint'},
        'id': null,
      }))
      ..close();
  }

  /// 处理 DELETE /mcp：客户端显式终止会话
  void _handleSessionDelete(io.HttpRequest request) {
    final sessionId = request.headers.value('Mcp-Session-Id');
    if (sessionId != null && _sessions.remove(sessionId) != null) {
      logger.i('MCP session terminated: $sessionId');
      request.response
        ..statusCode = io.HttpStatus.ok
        ..close();
      return;
    }
    _writeError(request.response, io.HttpStatus.notFound, -32001, 'Session not found');
  }

  /// 协议版本协商：客户端请求的版本受支持则回显，否则返回服务端最新版本
  String _negotiateProtocolVersion(String? clientVersion) {
    if (clientVersion != null && supportedProtocolVersions.contains(clientVersion)) {
      return clientVersion;
    }
    return latestProtocolVersion;
  }

  String _generateSessionId() {
    final rand = Random.secure();
    final bytes = List<int>.generate(16, (_) => rand.nextInt(256));
    return bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
  }

  Map<String, dynamic> _initializeResult(dynamic id, String protocolVersion) {
    return _buildResponse(id, {
      'protocolVersion': protocolVersion,
      'capabilities': {
        'tools': {},
      },
      'serverInfo': {
        'name': 'proxypin-mcp-server',
        'version': '1.1.0',
      },
    });
  }

  void _writeJsonRpc(io.HttpResponse response, Map<String, dynamic> jsonRpc, {String? sessionId}) {
    if (sessionId != null) {
      response.headers.set('Mcp-Session-Id', sessionId);
    }
    response
      ..statusCode = io.HttpStatus.ok
      ..headers.contentType = io.ContentType.json
      ..write(jsonEncode(jsonRpc))
      ..close();
  }

  void _writeError(io.HttpResponse response, int statusCode, int rpcCode, String message) {
    response
      ..statusCode = statusCode
      ..headers.contentType = io.ContentType.json
      ..write(jsonEncode({
        'jsonrpc': '2.0',
        'error': {'code': rpcCode, 'message': message},
        'id': null,
      }))
      ..close();
  }

  // ─────────────────────────────────────────────────────────────
  // 旧版 HTTP+SSE 传输（向后兼容 2024-11-05）
  // ─────────────────────────────────────────────────────────────

  /// 处理 SSE 连接
  void _handleSseConnection(io.HttpRequest request) {
    final response = request.response;
    response.statusCode = io.HttpStatus.ok;
    response.headers.set('Content-Type', 'text/event-stream; charset=utf-8');
    response.headers.set('Cache-Control', 'no-cache');
    response.headers.set('Connection', 'keep-alive');
    response.bufferOutput = false;

    final sessionId = DateTime.now().millisecondsSinceEpoch.toRadixString(36);
    final messageEndpoint = 'http://${request.requestedUri.host}:$_port/message?sessionId=$sessionId';

    final client = _SseClient(sessionId, response);
    _sseClients.add(client);

    logger.i('MCP SSE client connected: $sessionId, endpoint: $messageEndpoint');

    // 发送 endpoint 事件
    client.sendEvent('endpoint', messageEndpoint);

    // 心跳保活
    client.startHeartbeat();

    // 监听连接关闭
    request.response.done.then((_) {
      _sseClients.remove(client);
      client.close();
      logger.i('MCP SSE client disconnected: $sessionId');
    }).catchError((e) {
      _sseClients.remove(client);
      client.close();
    });
  }

  /// 处理 MCP JSON-RPC 消息（旧版传输）
  Future<void> _handleMessage(io.HttpRequest request) async {
    try {
      final body = await utf8.decoder.bind(request).join();
      final json = jsonDecode(body) as Map<String, dynamic>;

      final sessionId = request.uri.queryParameters['sessionId'];
      final client = _sseClients.firstWhere(
        (c) => c.sessionId == sessionId,
        orElse: () => _SseClient('', request.response),
      );

      final jsonRpcResponse = await _handleJsonRpc(json);

      // 通过 SSE 发送响应
      if (client.sessionId.isNotEmpty) {
        client.sendEvent('message', jsonEncode(jsonRpcResponse));
      }

      // 同时在 HTTP 响应中返回
      request.response
        ..statusCode = io.HttpStatus.ok
        ..headers.contentType = io.ContentType.json
        ..write(jsonEncode(jsonRpcResponse))
        ..close();
    } catch (e) {
      logger.e('MCP message handling error: $e');
      request.response
        ..statusCode = io.HttpStatus.badRequest
        ..headers.contentType = io.ContentType.json
        ..write(jsonEncode({
          'jsonrpc': '2.0',
          'error': {'code': -32700, 'message': 'Parse error: $e'},
          'id': null,
        }))
        ..close();
    }
  }

  // ─────────────────────────────────────────────────────────────
  // 公共 JSON-RPC 处理
  // ─────────────────────────────────────────────────────────────

  /// 处理 JSON-RPC 方法调用
  Future<Map<String, dynamic>> _handleJsonRpc(Map<String, dynamic> request) async {
    final method = request['method'] as String?;
    final id = request['id'];
    final params = request['params'] as Map<String, dynamic>? ?? {};

    switch (method) {
      case 'initialize':
        final clientVersion = params['protocolVersion'] as String?;
        return _initializeResult(id, _negotiateProtocolVersion(clientVersion));

      case 'notifications/initialized':
        return _buildResponse(id, {});

      case 'tools/list':
        return _buildResponse(id, {
          'tools': McpTools.getToolDefinitions(),
        });

      case 'tools/call':
        final toolName = params['name'] as String?;
        final arguments = params['arguments'] as Map<String, dynamic>? ?? {};
        final result = await McpTools.callTool(toolName ?? '', arguments, _requestContainer);
        return _buildResponse(id, result);

      case 'ping':
        return _buildResponse(id, {});

      default:
        return {
          'jsonrpc': '2.0',
          'error': {'code': -32601, 'message': 'Method not found: $method'},
          'id': id,
        };
    }
  }

  Map<String, dynamic> _buildResponse(dynamic id, Map<String, dynamic> result) {
    return {
      'jsonrpc': '2.0',
      'result': result,
      'id': id,
    };
  }
}

/// Streamable HTTP 会话
class _McpSession {
  final String id;
  final String protocolVersion;
  DateTime lastActivity = DateTime.now();

  _McpSession(this.id, this.protocolVersion);

  void touch() {
    lastActivity = DateTime.now();
  }
}

/// SSE 客户端连接（旧版传输）
class _SseClient {
  final String sessionId;
  final io.HttpResponse _response;
  Timer? _heartbeat;
  bool _closed = false;

  _SseClient(this.sessionId, this._response);

  /// 发送 SSE 事件
  void sendEvent(String event, String data) {
    if (_closed) return;
    try {
      _response.write('event: $event\ndata: $data\n\n');
      _response.flush();
    } catch (e) {
      // 连接已关闭
    }
  }

  /// 启动心跳
  void startHeartbeat() {
    _heartbeat = Timer.periodic(const Duration(seconds: 30), (_) {
      if (!_closed) {
        try {
          _response.write(':heartbeat\n\n');
          _response.flush();
        } catch (e) {
          close();
        }
      }
    });
  }

  /// 关闭连接
  void close() {
    _closed = true;
    _heartbeat?.cancel();
    try {
      _response.close();
    } catch (_) {}
  }
}
