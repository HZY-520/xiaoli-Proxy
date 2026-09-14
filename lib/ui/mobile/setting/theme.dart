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
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */
import 'package:flutter/material.dart';
import 'package:lico_proxy/l10n/app_localizations.dart';
import 'package:lico_proxy/ui/configuration.dart';
import 'package:shadcn_ui/shadcn_ui.dart';
import '../shad/shad_design.dart';

class MobileThemeSetting extends StatelessWidget {
  final AppConfiguration appConfiguration;

  const MobileThemeSetting({super.key, required this.appConfiguration});

  @override
  Widget build(BuildContext context) {
    AppLocalizations localizations = AppLocalizations.of(context)!;

    return PopupMenuButton(
        tooltip: appConfiguration.themeMode.name,
        surfaceTintColor: Theme.of(context).colorScheme.onPrimary,
        offset: const Offset(150, 0),
        itemBuilder: (BuildContext context) {
          return [
            PopupMenuItem(
                child: Tooltip(
                    preferBelow: false,
                    message: localizations.material3,
                    child: ShadTile(
                      titleWidget: const Text("Material3"),
                      showDivider: false,
                      trailing: ShadSwitch(
                          value: appConfiguration.useMaterial3,
                          onChanged: (bool value) {
                            appConfiguration.useMaterial3 = value;
                            Navigator.of(context).pop();
                          }),
                    ))),
            PopupMenuItem(
                child: ShadTile(
                  trailing: const Icon(Icons.cached),
                  titleWidget: Text(localizations.followSystem),
                ),
                onTap: () => appConfiguration.themeMode = ThemeMode.system),
            PopupMenuItem(
                child: ShadTile(
                  trailing: const Icon(Icons.sunny),
                  titleWidget: Text(localizations.themeLight),
                ),
                onTap: () => appConfiguration.themeMode = ThemeMode.light),
            PopupMenuItem(
                child: ShadTile(
                  trailing: const Icon(Icons.nightlight_outlined),
                  titleWidget: Text(localizations.themeDark),
                ),
                onTap: () => appConfiguration.themeMode = ThemeMode.dark),
          ];
        },
        child: ShadTile(
          titleWidget: Text(localizations.theme),
          trailing: getIcon(),
        ));
  }

  Icon getIcon() {
    switch (appConfiguration.themeMode) {
      case ThemeMode.system:
        return const Icon(Icons.cached);
      case ThemeMode.dark:
        return const Icon(Icons.nightlight_outlined);
      case ThemeMode.light:
        return const Icon(Icons.sunny);
    }
  }
}
