import 'dart:convert';
import 'dart:io';

import 'package:flutter/cupertino.dart';
import 'package:lico_proxy/l10n/app_localizations.dart';
import 'package:http/http.dart' as http;
import 'package:lico_proxy/network/util/logger.dart';
import 'package:lico_proxy/ui/app_update/remote_version_entity.dart';
import 'package:lico_proxy/ui/component/app_dialog.dart';
import 'package:lico_proxy/ui/configuration.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'constants.dart';
import 'new_version_dialog.dart';

class AppUpdateRepository {
  static final HttpClient httpClient = HttpClient();

  static Future<void> checkUpdate(BuildContext context, {bool canIgnore = true, bool showToast = false}) async {
    try {
      var lastVersion = await getLatestVersion();
      if (lastVersion == null) {
        logger.w("[AppUpdate] failed to fetch latest version info");
        return;
      }

      if (!context.mounted) return;

      var availableUpdates = compareVersions(AppConfiguration.version, lastVersion.version);
      if (availableUpdates) {
        if (canIgnore) {
          var ignoreVersion = await SharedPreferencesAsync().getString(Constants.ignoreReleaseVersionKey);
          if (ignoreVersion == lastVersion.version) {
            logger.d("ignored release [${lastVersion.version}]");
            return;
          }
        }

        logger.d("new version available: $lastVersion");

        if (!context.mounted) return;
        NewVersionDialog(
          AppConfiguration.version,
          lastVersion,
          canIgnore: true,
        ).show(context);
        return;
      }

      logger.i("already using latest version[${AppConfiguration.version}], last: [${lastVersion.version}]");

      if (showToast) {
        AppLocalizations localizations = AppLocalizations.of(context)!;
        CustomToast.success(localizations.appUpdateNotAvailableMsg).show(context);
      }
    } catch (e) {
      logger.e("Error checking for updates: $e");
      if (showToast) {
        CustomToast.error(e.toString()).show(context);
      }
    }
  }

  /// Fetches the latest version information from the GitHub releases API.
  static Future<RemoteVersionEntity?> getLatestVersion({bool includePreReleases = false}) async {
    late final http.Response response;
    try {
      response = await http.get(Uri.parse(Constants.githubReleasesApiUrl));
    } catch (e) {
      logger.w("[AppUpdate] failed to fetch latest version info: $e");
      return null;
    }
    if (response.statusCode != 200 || response.body.isEmpty) {
      logger.w(
          "[AppUpdate] failed to fetch latest version info: status=${response.statusCode} bodyLen=${response.body.length}");
      return null;
    }

    var body = jsonDecode(response.body) as List;
    final releases = body.map((e) => GithubReleaseParser.parse(e as Map<String, dynamic>));
    late RemoteVersionEntity latest;
    if (includePreReleases) {
      latest = releases.first;
    } else {
      latest = releases.firstWhere((e) => e.preRelease == false);
    }

    logger.d("[AppUpdate] latest version: $latest");
    return latest;
  }

  static bool compareVersions(String currentVersion, String latestVersion) {
    String normalizeVersion(String version) {
      return version.startsWith('v') ? version.substring(1) : version;
    }

    List<int> parseVersion(String version) {
      return normalizeVersion(version)
          .split('.')
          .map((e) => int.tryParse(e.trim()) ?? 0)
          .toList();
    }

    List<int> current = parseVersion(currentVersion);
    List<int> latest = parseVersion(latestVersion);

    // 逐段比较，缺失的段位补 0，避免 "1.0" vs "1.0.0" 被误判为新版本
    final length = current.length > latest.length ? current.length : latest.length;
    for (int i = 0; i < length; i++) {
      final c = i < current.length ? current[i] : 0;
      final l = i < latest.length ? latest[i] : 0;
      if (c > l) return false; // 当前版本更高
      if (c < l) return true; // 需要更新
    }
    return false;
  }
}
