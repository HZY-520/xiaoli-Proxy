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
 * See the License for specific language governing permissions and
 * limitations under the License.
 */

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_toastr/flutter_toastr.dart';
import 'package:proxypin/network/mcp/mcp_server.dart';

/// MCP Server 管理页面
/// 允许用户启动/停止 MCP Server，查看连接配置信息
class McpServerPage extends StatefulWidget {
  const McpServerPage({super.key});

  @override
  State<McpServerPage> createState() => _McpServerPageState();
}

class _McpServerPageState extends State<McpServerPage> {
  final McpServer _mcpServer = McpServer.instance;
  final TextEditingController _portController = TextEditingController();
  bool _isLoading = false;
  bool _autoStart = true;

  @override
  void initState() {
    super.initState();
    // 读取本地保存的端口，没有再默认 9010
    McpServer.loadPort().then((savedPort) {
      if (savedPort != null && savedPort != _mcpServer.port) {
        _mcpServer.port = savedPort;
      }
      if (mounted) {
        setState(() {
          _portController.text = _mcpServer.port.toString();
        });
      } else {
        _portController.text = _mcpServer.port.toString();
      }
    });
    // 读取自动启动开关
    McpServer.loadAutoStart().then((enabled) {
      if (mounted) {
        setState(() {
          _autoStart = enabled;
        });
      } else {
        _autoStart = enabled;
      }
    });
  }

  @override
  void dispose() {
    _portController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(title: const Text('MCP Server')),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 680),
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 状态卡片 + 端口配置
                _buildStatusCard(theme, isDark),
                const SizedBox(height: 16),

                // 连接信息
                if (_mcpServer.isRunning) ...[
                  _buildConnectionInfo(theme, isDark),
                  const SizedBox(height: 16),
                ],

                // AI 配置指南
                _buildConfigGuide(theme, isDark),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// 状态卡片（含端口配置）
  Widget _buildStatusCard(ThemeData theme, bool isDark) {
    final isRunning = _mcpServer.isRunning;

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: isRunning ? Colors.green.withValues(alpha: 0.3) : theme.dividerColor.withValues(alpha: 0.3),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 标题行：图标 + 标题 + 状态 + 按钮
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: isRunning
                        ? Colors.green.withValues(alpha: 0.1)
                        : theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    Icons.hub_outlined,
                    color: isRunning ? Colors.green : theme.iconTheme.color?.withValues(alpha: 0.5),
                    size: 26,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('MCP Server', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600)),
                      const SizedBox(height: 3),
                      Row(
                        children: [
                          Container(
                            width: 8,
                            height: 8,
                            decoration: BoxDecoration(
                              color: isRunning ? Colors.green : Colors.grey,
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Flexible(
                            child: Text(
                              isRunning ? '运行中 · 端口 ${_mcpServer.port}' : '已停止',
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: isRunning ? Colors.green : theme.textTheme.bodySmall?.color,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                _isLoading
                    ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2))
                    : FilledButton.icon(
                        onPressed: _toggleServer,
                        icon: Icon(isRunning ? Icons.stop : Icons.play_arrow, size: 18),
                        label: Text(isRunning ? '停止' : '启动'),
                        style: FilledButton.styleFrom(
                          backgroundColor: isRunning ? Colors.red.shade400 : Colors.green,
                          foregroundColor: Colors.white,
                        ),
                      ),
              ],
            ),
            const SizedBox(height: 16),
            Divider(height: 1, color: theme.dividerColor.withValues(alpha: 0.2)),
            const SizedBox(height: 14),
            // 端口配置行
            Row(
              children: [
                Icon(Icons.settings_ethernet, size: 18, color: theme.iconTheme.color?.withValues(alpha: 0.5)),
                const SizedBox(width: 10),
                Text('端口:', style: theme.textTheme.bodyMedium),
                const SizedBox(width: 10),
                SizedBox(
                  width: 80,
                  child: TextField(
                    controller: _portController,
                    keyboardType: TextInputType.number,
                    enabled: !isRunning,
                    style: const TextStyle(fontSize: 14),
                    decoration: InputDecoration(
                      isDense: true,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(6)),
                    ),
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    onChanged: (value) {
                      final port = int.tryParse(value);
                      if (port != null && port > 0 && port < 65536) {
                        _mcpServer.port = port;
                      }
                    },
                  ),
                ),
                if (isRunning) ...[
                  const SizedBox(width: 10),
                  Flexible(
                    child: Text(
                      '停止服务后才能修改端口',
                      style: theme.textTheme.bodySmall?.copyWith(color: Colors.orange.shade400, fontSize: 11),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 12),
            // 自动启动开关
            Row(
              children: [
                Icon(Icons.power_settings_new, size: 18, color: theme.iconTheme.color?.withValues(alpha: 0.5)),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('开机自启', style: theme.textTheme.bodyMedium),
                      Text('App 启动时自动开启 MCP Server',
                          style: theme.textTheme.bodySmall?.copyWith(fontSize: 11, color: theme.hintColor)),
                    ],
                  ),
                ),
                Switch(
                  value: _autoStart,
                  onChanged: (value) {
                    setState(() {
                      _autoStart = value;
                    });
                    McpServer.saveAutoStart(value);
                  },
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  /// 连接信息
  Widget _buildConnectionInfo(ThemeData theme, bool isDark) {
    final localIp = _getLocalIp();
    final mcpUrl = 'http://$localIp:${_mcpServer.port}/mcp';
    final sseUrl = 'http://$localIp:${_mcpServer.port}/sse';

    final configJson = '''{
  "mcpServers": {
    "proxypin": {
      "url": "$mcpUrl"
    }
  }
}''';

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.blue.withValues(alpha: 0.3)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.link, size: 18, color: Colors.blue),
                const SizedBox(width: 8),
                Text('连接信息', style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600)),
              ],
            ),
            const SizedBox(height: 12),

            // Streamable HTTP URL（最新 MCP 协议）
            _buildCopyableField(theme, 'Streamable HTTP (推荐)', mcpUrl, isDark),
            const SizedBox(height: 10),

            // SSE URL（旧版兼容）
            _buildCopyableField(theme, 'SSE Endpoint (旧版)', sseUrl, isDark),
            const SizedBox(height: 10),

            // Health URL
            _buildCopyableField(theme, 'Health Check', 'http://$localIp:${_mcpServer.port}/health', isDark),
            const SizedBox(height: 12),

            // MCP 配置 JSON
            Text('MCP 配置 (JSON)', style: theme.textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w500)),
            const SizedBox(height: 6),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isDark ? Colors.grey.shade900 : Colors.grey.shade100,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Stack(
                children: [
                  SelectableText(
                    configJson,
                    style: TextStyle(
                      fontFamily: 'monospace',
                      fontSize: 12,
                      color: isDark ? Colors.green.shade300 : Colors.grey.shade800,
                    ),
                  ),
                  Positioned(
                    top: 0,
                    right: 0,
                    child: IconButton(
                      icon: const Icon(Icons.copy, size: 16),
                      onPressed: () => _copyToClipboard(configJson),
                      tooltip: '复制',
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(minWidth: 24, minHeight: 24),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// 可复制字段
  Widget _buildCopyableField(ThemeData theme, String label, String value, bool isDark) {
    return Row(
      children: [
        SizedBox(
          width: 100,
          child: Text(label, style: theme.textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w500)),
        ),
        Expanded(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: isDark ? Colors.grey.shade900 : Colors.grey.shade100,
              borderRadius: BorderRadius.circular(6),
            ),
            child: SelectableText(
              value,
              style: TextStyle(fontFamily: 'monospace', fontSize: 12, color: Colors.blue.shade300),
            ),
          ),
        ),
        const SizedBox(width: 4),
        IconButton(
          icon: const Icon(Icons.copy, size: 14),
          onPressed: () => _copyToClipboard(value),
          tooltip: '复制',
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
        ),
      ],
    );
  }

  /// AI 配置指南
  Widget _buildConfigGuide(ThemeData theme, bool isDark) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: theme.dividerColor.withValues(alpha: 0.3)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.auto_awesome, size: 18, color: Colors.amber),
                const SizedBox(width: 8),
                Text('AI 配置指南', style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600)),
              ],
            ),
            const SizedBox(height: 12),
            _buildGuideItem(theme, '1', '在本页点击「启动」，保持 MCP Server 运行。'),
            _buildGuideItem(theme, '2', '复制上面的 MCP 配置 JSON，或直接使用 Streamable HTTP 地址。'),
            _buildGuideItem(theme, '3', '在 AI 客户端（Claude Desktop / Cursor / Cherry Studio 等）的 MCP 配置中粘贴，重启后即可让 AI 调用本机抓包数据。'),
            const SizedBox(height: 8),
            Text('可用工具:', style: theme.textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w600)),
            const SizedBox(height: 4),
            ..._toolItems(theme),
          ],
        ),
      ),
    );
  }

  List<Widget> _toolItems(ThemeData theme) {
    const tools = [
      ('get_request_list', '获取抓包请求列表（支持域名/方法/状态码/关键词过滤、分页）'),
      ('get_request_detail', '获取指定请求的完整详情（请求头/体、响应头/体、耗时）'),
      ('get_request_stats', '统计请求数量、方法分布、状态码分布、域名 Top'),
      ('search_requests', '按关键词或正则搜索请求'),
      ('get_request_body', '获取请求/响应 body（自动解码）'),
      ('analyze_encrypted_content', '分析疑似加密/编码内容（Base64 / Hex / JSON 等）'),
      ('get_domain_summary', '按域名聚合请求概览'),
      ('get_cookie_info', '提取请求/响应中的 Cookie 信息'),
      ('compare_requests', '对比两个请求的差异'),
      ('replay_request', '重放指定请求'),
      ('generate_code', '将请求生成 cURL / fetch / Python / JS / Go 代码'),
      ('add_breakpoint', '新增断点规则（拦截请求/响应）'),
      ('list_breakpoints', '列出所有断点规则'),
      ('remove_breakpoint', '删除断点规则'),
      ('get_pending_intercepts', '获取当前挂起的拦截队列'),
      ('release_intercept', '放行挂起的拦截'),
      ('list_rewrite_rules', '列出请求重写规则'),
      ('add_rewrite_rule', '新增请求重写规则'),
      ('remove_rewrite_rule', '删除请求重写规则'),
      ('list_scripts', '列出 JS 脚本'),
      ('get_script_content', '获取脚本源码'),
      ('create_or_update_script', '新建或更新 JS 脚本'),
      ('find_sensitive_data', '在请求中查找敏感数据（手机号/邮箱/Token 等）'),
      ('analyze_auth', '分析鉴权方式（Bearer / Basic / API Key / JWT）'),
      ('extract_api_endpoints', '提取 API 端点与路径'),
    ];

    return tools
        .map((t) => _buildToolItem(theme, t.$1, t.$2))
        .toList();
  }

  Widget _buildGuideItem(ThemeData theme, String step, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 20,
            height: 20,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: theme.colorScheme.primary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(step,
                style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: theme.colorScheme.primary)),
          ),
          const SizedBox(width: 8),
          Expanded(child: Text(text, style: theme.textTheme.bodySmall)),
        ],
      ),
    );
  }

  Widget _buildToolItem(ThemeData theme, String name, String desc) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 3),
      child: Row(
        children: [
          const SizedBox(width: 8),
          Icon(Icons.build_circle_outlined, size: 12, color: theme.iconTheme.color?.withValues(alpha: 0.4)),
          const SizedBox(width: 6),
          Text(name,
              style: TextStyle(
                  fontFamily: 'monospace', fontSize: 11, fontWeight: FontWeight.w600, color: Colors.blue.shade300)),
          const SizedBox(width: 8),
          Expanded(
              child: Text(desc,
                  style: theme.textTheme.bodySmall?.copyWith(fontSize: 11), overflow: TextOverflow.ellipsis)),
        ],
      ),
    );
  }

  /// 启动/停止服务器
  Future<void> _toggleServer() async {
    setState(() => _isLoading = true);

    try {
      if (_mcpServer.isRunning) {
        await _mcpServer.stop();
        if (mounted) FlutterToastr.show('已停止 MCP Server', context);
      } else {
        final port = int.tryParse(_portController.text);
        if (port == null || port <= 0 || port >= 65536) {
          if (mounted) FlutterToastr.show('端口无效', context);
          return;
        }
        _mcpServer.port = port;
        await _mcpServer.start();
        // 端口可能因占用自动递增，同步显示实际端口
        _portController.text = _mcpServer.port.toString();
        if (mounted) FlutterToastr.show('MCP Server 已启动 · 端口 ${_mcpServer.port}', context);
      }
    } catch (e) {
      final msg = e.toString();
      if (mounted) {
        if (msg.contains('Failed to create server socket') || msg.contains('address already in use')) {
          FlutterToastr.show('端口 ${_mcpServer.port} 被占用，请更换端口', context);
        } else {
          FlutterToastr.show('Error: $msg', context);
        }
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _copyToClipboard(String text) {
    Clipboard.setData(ClipboardData(text: text));
    if (mounted) FlutterToastr.show('已复制', context);
  }

  String _getLocalIp() {
    // Android 上 MCP Server 仅绑定 loopback，本机访问请用 127.0.0.1
    return '127.0.0.1';
  }
}
