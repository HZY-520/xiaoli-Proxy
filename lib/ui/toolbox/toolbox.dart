import 'package:flutter/material.dart';
import 'package:proxypin/network/bin/server.dart';
import 'package:proxypin/network/components/manager/hosts_manager.dart';
import 'package:proxypin/network/components/manager/network_condition_manager.dart';
import 'package:proxypin/network/components/manager/request_block_manager.dart';
import 'package:proxypin/network/components/manager/request_breakpoint_manager.dart';
import 'package:proxypin/ui/component/multi_window.dart';
import 'package:proxypin/ui/mobile/request/request_editor.dart';
import 'package:proxypin/ui/mobile/setting/environment.dart';
import 'package:proxypin/ui/mobile/setting/hosts.dart';
import 'package:proxypin/ui/mobile/setting/request_block.dart';
import 'package:proxypin/ui/mobile/setting/request_breakpoint.dart';
import 'package:proxypin/ui/mobile/setting/request_crypto.dart';
import 'package:proxypin/ui/mobile/setting/request_map.dart';
import 'package:proxypin/ui/mobile/setting/script.dart';
import 'package:proxypin/ui/mobile/setting/ssl.dart';
import 'package:proxypin/ui/mobile/setting/weak_network.dart';
import 'package:proxypin/ui/toolbox/qr_code_page.dart';
import 'package:proxypin/ui/toolbox/regexp.dart';
import 'package:proxypin/ui/toolbox/timestamp.dart';
import 'package:proxypin/utils/platform.dart';

import 'aes_page.dart';
import 'cert_hash.dart';
import 'encoder.dart';
import 'text_diff.dart';
import 'text_editor.dart';
import 'websocket_request.dart';
import 'xml_viewer.dart';

class Toolbox extends StatefulWidget {
  final ProxyServer? proxyServer;

  const Toolbox({super.key, this.proxyServer});

  @override
  State<StatefulWidget> createState() {
    return _ToolboxState();
  }
}

class _ToolboxState extends State<Toolbox> {
  @override
  Widget build(BuildContext context) {
    final tools = <_HcTool>[
      // ===== 黄鸟工具箱同款 4 项（已去掉 PING/域名解析/网络配置） =====
      _HcTool('执行cURL', Icons.code, () => _nav(MobileRequestEditor(proxyServer: widget.proxyServer))),
      _HcTool('证书提取', Icons.verified_user, () => _open(const CertHashPage(), 'CertHashPage', '证书提取')),
      _HcTool('文本解密', Icons.vpn_key, () => _open(const AesPage(), 'AesPage', '文本解密')),
      _HcTool('时间戳', Icons.access_time, () => _open(const TimestampPage(), 'TimestampPage', '时间戳')),

      // ===== 原有工具 =====
      _HcTool('HTTP', Icons.http,
          () => _open(MobileRequestEditor(proxyServer: widget.proxyServer), 'RequestEditor', 'HTTP')),
      _HcTool('WebSocket', Icons.sync_alt,
          () => _open(const WebSocketRequestPage(), 'WebSocketRequestPage', 'WebSocket')),
      _HcTool('XML', Icons.code, () => _open(const XmlViewerPage(), 'XmlViewerPage', 'XML')),
      _HcTool('文本比对', Icons.difference_outlined, () => _open(const TextDiffPage(), 'TextDiffPage', '文本比对')),
      _HcTool('文本编辑', Icons.note_alt_outlined, () => _open(const TextEditorPage(), 'TextEditorPage', '文本编辑')),
      _HcTool('URL', Icons.link, () => encodeWindow(EncoderType.url, context)),
      _HcTool('Base64', Icons.format_bold_outlined, () => encodeWindow(EncoderType.base64, context)),
      _HcTool('Unicode', Icons.format_underline_outlined, () => encodeWindow(EncoderType.unicode, context)),
      _HcTool('MD5', Icons.tag_outlined, () => encodeWindow(EncoderType.md5, context)),
      _HcTool('AES', Icons.enhanced_encryption_outlined, () => _open(const AesPage(), 'AesPage', 'AES')),
      _HcTool('证书Hash', Icons.key_outlined, () => _open(const CertHashPage(), 'CertHashPage', '证书Hash')),
      _HcTool('正则', Icons.find_in_page_outlined, () => _open(const RegExpPage(), 'RegExpPage', '正则')),
      _HcTool('二维码', Icons.qr_code_2, () => _open(const QrCodePage(), 'QrCodePage', '二维码')),

      // ===== 代理功能 =====
      _HcTool('HTTPS代理', Icons.lock_outline, () => _nav(MobileSslWidget(proxyServer: widget.proxyServer!))),
      _HcTool('Hosts', Icons.domain, () async {
        var m = await HostsManager.instance;
        if (context.mounted) _nav(HostsPage(hostsManager: m));
      }),
      _HcTool('请求屏蔽', Icons.block_flipped, () async {
        var m = await RequestBlockManager.instance;
        if (context.mounted) _nav(MobileRequestBlock(requestBlockManager: m));
      }),
      _HcTool('请求映射', Icons.swap_horiz_outlined, () => _nav(MobileRequestMapPage())),
      _HcTool('请求加解密', Icons.security, () => _nav(const MobileRequestCryptoPage())),
      _HcTool('脚本', Icons.code, () => _nav(const MobileScript())),
      _HcTool('断点', Icons.bug_report_outlined, () async {
        var m = await RequestBreakpointManager.instance;
        if (context.mounted) _nav(MobileRequestBreakpointPage(manager: m));
      }),
      _HcTool('弱网', Icons.speed, () async {
        var m = await NetworkConditionManager.instance;
        if (context.mounted) _nav(MobileWeakNetwork(manager: m));
      }),
      _HcTool('环境变量', Icons.public, () => _nav(const MobileEnvironmentPage())),
    ];

    return SingleChildScrollView(
      child: Column(
        children: [
          for (int i = 0; i < tools.length; i += 3) _gridRow(tools, i, i + 3 < tools.length),
        ],
      ),
    );
  }

  void _nav(Widget page) => Navigator.of(context).push(MaterialPageRoute(builder: (_) => page));

  /// 桌面端用 MultiWindow 开新窗口，移动端正常跳转
  void _open(Widget page, String winKey, String title, {Size? size}) {
    if (!Platforms.isMobile()) {
      MultiWindow.openWindow(title, winKey, size: size ?? const Size(820, 700));
      return;
    }
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => page));
  }

  Widget _gridRow(List<_HcTool> all, int start, bool hasBottom) {
    final count = (all.length - start).clamp(0, 3);
    return Container(
      decoration: BoxDecoration(
        border: Border(
          bottom: hasBottom ? const BorderSide(color: Color(0xFFE0E0E0), width: 0.5) : BorderSide.none,
        ),
      ),
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (int j = 0; j < 3; j++) ...[
              if (j > 0) const VerticalDivider(width: 0.5, color: Color(0xFFE0E0E0)),
              Expanded(child: j < count ? _cell(all[start + j]) : const SizedBox()),
            ],
          ],
        ),
      ),
    );
  }

  Widget _cell(_HcTool t) {
    return InkWell(
      onTap: t.onTap,
      child: Container(
        height: 104,
        padding: const EdgeInsets.symmetric(vertical: 14),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 52,
              height: 52,
              decoration: const BoxDecoration(color: Color(0xFF369EDB), shape: BoxShape.circle),
              child: Icon(t.icon, color: Colors.white, size: 26),
            ),
            const SizedBox(height: 8),
            Text(t.label, style: const TextStyle(fontSize: 12.5), textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }
}

class _HcTool {
  final String label;
  final IconData icon;
  final VoidCallback onTap;
  _HcTool(this.label, this.icon, this.onTap);
}
