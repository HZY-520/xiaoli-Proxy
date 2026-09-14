import 'dart:io';

import 'package:flutter/material.dart';
import 'package:shadcn_ui/shadcn_ui.dart';
import 'package:flutter/services.dart';
import 'package:lico_proxy/l10n/app_localizations.dart';
import 'package:lico_proxy/network/bin/configuration.dart';
import 'package:lico_proxy/network/bin/server.dart';
import 'package:lico_proxy/network/util/logger.dart';
import 'package:lico_proxy/ui/component/widgets.dart';
import 'package:lico_proxy/ui/configuration.dart';
import 'package:lico_proxy/ui/mobile/setting/theme.dart';
import 'package:lico_proxy/ui/mobile/shad/shad_design.dart';

///设置
///@author wanghongen
class Preference extends StatefulWidget {
  final ProxyServer proxyServer;
  final AppConfiguration appConfiguration;

  const Preference({super.key, required this.proxyServer, required this.appConfiguration});

  @override
  State<StatefulWidget> createState() => _PreferenceState();
}

class _PreferenceState extends State<Preference> {
  late ProxyServer proxyServer;
  late Configuration configuration;
  late AppConfiguration appConfiguration;

  final memoryCleanupController = TextEditingController();
  final memoryCleanupList = [null, 512, 1024, 2048, 4096];

  @override
  void initState() {
    super.initState();
    proxyServer = widget.proxyServer;
    configuration = widget.proxyServer.configuration;
    appConfiguration = widget.appConfiguration;

    if (!memoryCleanupList.contains(appConfiguration.memoryCleanupThreshold)) {
      memoryCleanupController.text = appConfiguration.memoryCleanupThreshold.toString();
    }
  }

  @override
  void dispose() {
    memoryCleanupController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    AppLocalizations localizations = AppLocalizations.of(context)!;
    final dividerColor = ShadTheme.of(context).colorScheme.border.withValues(alpha: 0.45);

    Widget section(List<Widget> tiles) => ShadSection(children: tiles);

    return Scaffold(
        appBar: ShadHeader(title: localizations.preference),
        body: ListView(
          padding: const EdgeInsets.all(12),
          children: [
            section([
              ShadTile(
                titleWidget: Text(localizations.language),
                trailing: const Icon(LucideIcons.chevronRight, size: 16),
                onTap: () => _language(context),
              ),
              Divider(height: 0, thickness: 0.5, color: dividerColor),
              MobileThemeSetting(appConfiguration: appConfiguration),
              Divider(height: 0, thickness: 0.5, color: dividerColor),
              ShadTile(
                titleWidget: Text(localizations.themeColor),
              ),
              Padding(padding: const EdgeInsets.symmetric(horizontal: 0, vertical: 8), child: themeColor(context)),
            ]),
            const SizedBox(height: 12),
            section([
              ShadTile(
                titleWidget: Text(localizations.autoStartup),
                subtitleWidget: Text(localizations.autoStartupDescribe,
                    style: TextStyle(fontSize: 12, color: ShadTheme.of(context).colorScheme.mutedForeground)),
                trailing: SwitchWidget(
                    value: proxyServer.configuration.startup,
                    scale: 0.8,
                    onChanged: (value) {
                      configuration.startup = value;
                      configuration.flushConfig();
                    }),
              ),
              Divider(height: 0, thickness: 0.5, color: dividerColor),
              if (Platform.isAndroid) ...[
                ShadTile(
                  titleWidget: Text(localizations.windowMode),
                  subtitleWidget: Text(localizations.windowModeSubTitle,
                      style: TextStyle(fontSize: 12, color: ShadTheme.of(context).colorScheme.mutedForeground)),
                  trailing: SwitchWidget(
                      value: appConfiguration.pipEnabled.value,
                      scale: 0.8,
                      onChanged: (value) {
                        appConfiguration.pipEnabled.value = value;
                        appConfiguration.flushConfig();
                      }),
                ),
                Divider(height: 0, thickness: 0.5, color: dividerColor),
              ],
              ShadTile(
                titleWidget: Text(localizations.pipIcon),
                subtitleWidget: Text(localizations.pipIconDescribe,
                    style: TextStyle(fontSize: 12, color: ShadTheme.of(context).colorScheme.mutedForeground)),
                trailing: SwitchWidget(
                    value: appConfiguration.pipIcon.value,
                    scale: 0.8,
                    onChanged: (value) {
                      appConfiguration.pipIcon.value = value;
                      appConfiguration.flushConfig();
                    }),
              ),
              Divider(height: 0, thickness: 0.5, color: dividerColor),
              ShadTile(
                titleWidget: Text(localizations.bottomNavigation),
                subtitleWidget: Text(localizations.bottomNavigationSubtitle,
                    style: TextStyle(fontSize: 12, color: ShadTheme.of(context).colorScheme.mutedForeground)),
                trailing: SwitchWidget(
                    value: appConfiguration.bottomNavigation,
                    scale: 0.8,
                    onChanged: (value) {
                      appConfiguration.bottomNavigation = value;
                      appConfiguration.flushConfig();
                    }),
              ),
              Divider(height: 0, thickness: 0.5, color: dividerColor),
              ShadTile(
                titleWidget: Text(localizations.clearConfirm),
                subtitleWidget: Text(localizations.clearConfirmSubtitle,
                    style: TextStyle(fontSize: 12, color: ShadTheme.of(context).colorScheme.mutedForeground)),
                trailing: SwitchWidget(
                    value: appConfiguration.clearConfirm,
                    scale: 0.8,
                    onChanged: (value) {
                      appConfiguration.clearConfirm = value;
                      appConfiguration.flushConfig();
                    }),
              ),
            ]),
            const SizedBox(height: 12),
            section([
              ShadTile(
                titleWidget: Text(localizations.memoryCleanup),
                subtitleWidget: Text(localizations.memoryCleanupSubtitle,
                    style: TextStyle(fontSize: 12, color: ShadTheme.of(context).colorScheme.mutedForeground)),
                trailing: memoryCleanup(context, localizations),
              ),
            ]),
            const SizedBox(height: 15),
          ],
        ));
  }

  Widget themeColor(BuildContext context) {
    return Wrap(
      children: ColorMapping.colors.entries.map((pair) {
        var dividerColor = Theme.of(context).focusColor;
        var background = appConfiguration.themeColor == pair.value ? dividerColor : Colors.transparent;

        return GestureDetector(
            onTap: () => appConfiguration.setThemeColor = pair.key,
            child: Tooltip(
              message: pair.key,
              child: Container(
                margin: const EdgeInsets.all(4.0),
                decoration: BoxDecoration(
                  color: background,
                  border: Border.all(color: Colors.transparent, width: 8),
                ),
                child: Dot(color: pair.value, size: 15),
              ),
            ));
      }).toList(),
    );
  }

  //选择语言
  void _language(BuildContext context) {
    AppLocalizations localizations = AppLocalizations.of(context)!;
    showDialog(
        context: context,
        builder: (context) {
          return ShadDialog.alert(
            padding: const EdgeInsets.only(left: 5, top: 5, right: 5, bottom: 5),
            title: Text(localizations.language),
            actions: [
              ShadButton.outline(
                  onPressed: () {
                    Navigator.of(context).pop();
                  },
                  child: Text(localizations.cancel)),
            ],
            child: Wrap(
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                TextButton(
                    onPressed: () {
                      appConfiguration.language = null;
                      Navigator.of(context).pop();
                    },
                    child: Text(localizations.followSystem)),
                const Divider(thickness: 0.5, height: 0),
                TextButton(
                    onPressed: () {
                      appConfiguration.language = const Locale.fromSubtags(languageCode: 'zh');
                      Navigator.of(context).pop();
                    },
                    child: const Text("简体中文")),
                const Divider(thickness: 0.5, height: 0),
                TextButton(
                    onPressed: () {
                      appConfiguration.language = const Locale.fromSubtags(languageCode: 'zh', scriptCode: 'Hant');
                      Navigator.of(context).pop();
                    },
                    child: const Text("繁體中文")),
                const Divider(thickness: 0.5, height: 0),
                TextButton(
                    onPressed: () {
                      appConfiguration.language = const Locale.fromSubtags(languageCode: 'vi');
                      Navigator.of(context).pop();
                    },
                    child: const Text("Tiếng Việt")),
                const Divider(thickness: 0.5, height: 0),
                TextButton(
                    onPressed: () {
                      appConfiguration.language = const Locale.fromSubtags(languageCode: 'th');
                      Navigator.of(context).pop();
                    },
                    child: const Text("ไทย")),
                const Divider(thickness: 0.5, height: 0),
                TextButton(
                    onPressed: () {
                      appConfiguration.language = const Locale.fromSubtags(languageCode: 'es');
                      Navigator.of(context).pop();
                    },
                    child: const Text("Español")),
                const Divider(thickness: 0.5, height: 0),
                TextButton(
                    child: const Text("English"),
                    onPressed: () {
                      appConfiguration.language = const Locale.fromSubtags(languageCode: 'en');
                      Navigator.of(context).pop();
                    }),
                const Divider(thickness: 0.5),
              ],
            ),
          );
        });
  }

  bool memoryCleanupOpened = false;

  ///内存清理
  Widget memoryCleanup(BuildContext context, AppLocalizations localizations) {
    try {
      return DropdownButton<int>(
          value: appConfiguration.memoryCleanupThreshold,
          onTap: () => memoryCleanupOpened = true,
          onChanged: (val) {
            memoryCleanupOpened = false;
            setState(() {
              appConfiguration.memoryCleanupThreshold = val;
            });
            appConfiguration.flushConfig();
          },
          underline: Container(),
          items: [
            DropdownMenuItem(value: null, child: Text(localizations.unlimited)),
            const DropdownMenuItem(value: 512, child: Text("512M")),
            const DropdownMenuItem(value: 1024, child: Text("1024M")),
            const DropdownMenuItem(value: 2048, child: Text("2048M")),
            const DropdownMenuItem(value: 4096, child: Text("4096M")),
            DropdownMenuInputItem(
                controller: memoryCleanupController,
                child: Container(
                    constraints: BoxConstraints(maxWidth: 65, minWidth: 35),
                    child: TextField(
                        controller: memoryCleanupController,
                        keyboardType: TextInputType.datetime,
                        onSubmitted: (value) {
                          setState(() {});
                          appConfiguration.memoryCleanupThreshold = int.tryParse(value);
                          appConfiguration.flushConfig();

                          if (memoryCleanupOpened) {
                            memoryCleanupOpened = false;
                            Navigator.pop(context);
                            return;
                          }
                        },
                        inputFormatters: [
                          LengthLimitingTextInputFormatter(5),
                          FilteringTextInputFormatter.allow(RegExp("[0-9]"))
                        ],
                        decoration: InputDecoration(hintText: localizations.custom, suffixText: "M")))),
          ]);
    } catch (e) {
      appConfiguration.memoryCleanupThreshold = null;
      logger.e('memory button build error', error: e, stackTrace: StackTrace.current);
      return const SizedBox();
    }
  }
}

class DropdownMenuInputItem extends DropdownMenuItem<int> {
  final TextEditingController controller;

  @override
  int? get value => int.tryParse(controller.text) ?? 0;

  const DropdownMenuInputItem({super.key, required this.controller, required super.child});
}
