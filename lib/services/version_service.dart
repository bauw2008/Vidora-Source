import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

class VersionService {
  static const String githubRepoUrl = 'https://github.com/bauw2008/Vidora-Source';
  static const String githubApiUrl = 'https://api.github.com/repos/bauw2008/Vidora-Source/releases/latest';
  static const String _lastCheckKey = 'last_version_check';
  static const String _dismissedVersionKey = 'dismissed_version';
  
  /// 检查是否有新版本
  /// [forceCheck] 是否强制检查（忽略每天一次的限制）
  static Future<VersionInfo?> checkForUpdate({bool forceCheck = false}) async {
    try {
      // 获取当前版本
      final packageInfo = await PackageInfo.fromPlatform();
      final currentVersion = packageInfo.version;
      final currentBuildNumber = packageInfo.buildNumber;
      
      debugPrint('当前版本: $currentVersion (build: $currentBuildNumber)');
      
      // 从 GitHub API 获取最新 Release 信息
      final response = await http.get(
        Uri.parse(githubApiUrl),
        headers: {
          'Accept': 'application/vnd.github.v3+json',
        },
      ).timeout(const Duration(seconds: 10));
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final tagName = data['tag_name'] as String;
        final latestVersion = tagName.startsWith('v') ? tagName.substring(1) : tagName;
        final releaseNotes = data['body'] as String? ?? '';
        final assets = data['assets'] as List<dynamic>? ?? [];
        
        debugPrint('最新版本: $latestVersion');
        
        // 解析不同架构的 APK 下载链接
        final apkUrls = _parseApkAssets(assets);
        
        // 比较版本号
        if (_isNewerVersion(currentVersion, latestVersion)) {
          // 如果不是强制检查，需要验证是否应该显示提示
          if (!forceCheck) {
            final shouldShow = await shouldShowUpdatePrompt(latestVersion);
            if (!shouldShow) {
              debugPrint('用户已忽略此版本或检查间隔未到');
              return null;
            }
          }
          
          return VersionInfo(
            currentVersion: currentVersion,
            latestVersion: latestVersion,
            releaseNotes: releaseNotes,
            apkUrls: apkUrls,
          );
        }
      }
      
      return null;
    } catch (e) {
      debugPrint('检查版本更新失败: $e');
      return null;
    }
  }
  
  /// 解析 GitHub Release assets，提取不同架构的 APK 下载链接
  static Map<String, String> _parseApkAssets(List<dynamic> assets) {
    final apkUrls = <String, String>{};
    
    for (final asset in assets) {
      final name = asset['name'] as String? ?? '';
      final downloadUrl = asset['browser_download_url'] as String? ?? '';
      
      if (name.endsWith('.apk')) {
        // 根据文件名识别架构
        if (name.contains('arm64-v8a')) {
          apkUrls['arm64'] = downloadUrl;
        } else if (name.contains('armeabi-v7a')) {
          apkUrls['armeabi'] = downloadUrl;
        } else if (name.contains('x86_64')) {
          apkUrls['x86_64'] = downloadUrl;
        } else if (name.contains('universal') || name.contains('release.apk')) {
          // 通用版本或只有一个 APK 的情况
          apkUrls['universal'] = downloadUrl;
        }
      }
    }
    
    debugPrint('解析到的 APK: $apkUrls');
    return apkUrls;
  }
  
  /// 获取适合当前设备的 APK 下载链接
  static String? getPreferredApkUrl(Map<String, String> apkUrls) {
    // 优先级：arm64 > armeabi > x86_64 > universal
    if (apkUrls.containsKey('arm64')) {
      return apkUrls['arm64'];
    }
    if (apkUrls.containsKey('armeabi')) {
      return apkUrls['armeabi'];
    }
    if (apkUrls.containsKey('x86_64')) {
      return apkUrls['x86_64'];
    }
    if (apkUrls.containsKey('universal')) {
      return apkUrls['universal'];
    }
    // 如果都没有，返回第一个可用的
    if (apkUrls.isNotEmpty) {
      return apkUrls.values.first;
    }
    return null;
  }
  
  /// 获取当前设备架构描述
  static String getCurrentArchDescription() {
    // 大多数现代 Android 手机
    return 'arm64-v8a';
  }
  
  /// 获取 GitHub Release 页面 URL
  static String getReleaseUrl(String version) {
    return '$githubRepoUrl/releases/tag/v$version';
  }
  
  /// 比较版本号，判断是否有新版本
  static bool _isNewerVersion(String current, String latest) {
    try {
      // 处理可能的版本号格式（如 1.0.3 或 1.0.3+4）
      final currentParts = current.split('+')[0].split('.').map((e) => int.tryParse(e) ?? 0).toList();
      final latestParts = latest.split('+')[0].split('.').map((e) => int.tryParse(e) ?? 0).toList();
      
      debugPrint('版本比较: current=$currentParts, latest=$latestParts');
      
      for (int i = 0; i < 3; i++) {
        final currentPart = i < currentParts.length ? currentParts[i] : 0;
        final latestPart = i < latestParts.length ? latestParts[i] : 0;
        
        if (latestPart > currentPart) {
          debugPrint('发现新版本: $latestPart > $currentPart (位置 $i)');
          return true;
        }
        if (latestPart < currentPart) {
          return false;
        }
      }
      
      debugPrint('版本相同，无更新');
      return false;
    } catch (e) {
      debugPrint('版本比较失败: $e');
      return false;
    }
  }
  
  /// 检查是否应该显示更新提示（避免频繁提示）
  static Future<bool> shouldShowUpdatePrompt(String version) async {
    final prefs = await SharedPreferences.getInstance();
    
    // 检查用户是否已忽略此版本
    final dismissedVersion = prefs.getString(_dismissedVersionKey);
    if (dismissedVersion == version) {
      debugPrint('用户已忽略版本: $version');
      return false;
    }
    
    // 检查上次检查时间（每天最多提示一次）
    final lastCheck = prefs.getInt(_lastCheckKey) ?? 0;
    final now = DateTime.now().millisecondsSinceEpoch;
    final dayInMs = 24 * 60 * 60 * 1000;
    
    if (now - lastCheck < dayInMs) {
      debugPrint('检查间隔未到，上次检查: ${DateTime.fromMillisecondsSinceEpoch(lastCheck)}');
      return false;
    }
    
    // 更新最后检查时间
    await prefs.setInt(_lastCheckKey, now);
    return true;
  }
  
  /// 标记用户已忽略某个版本
  static Future<void> dismissVersion(String version) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_dismissedVersionKey, version);
  }
  
  /// 清除忽略记录（用于测试或重置）
  static Future<void> clearDismissedVersion() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_dismissedVersionKey);
  }
  
  /// 清除检查时间记录（用于测试）
  static Future<void> clearLastCheckTime() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_lastCheckKey);
  }
}

void debugPrint(String message) {
  // ignore: avoid_print
  print('[VersionService] $message');
}

class VersionInfo {
  final String currentVersion;
  final String latestVersion;
  final String releaseNotes;
  final Map<String, String> apkUrls;
  
  VersionInfo({
    required this.currentVersion,
    required this.latestVersion,
    required this.releaseNotes,
    this.apkUrls = const {},
  });
  
  /// 获取适合当前设备的 APK 下载链接
  String? get preferredApkUrl => VersionService.getPreferredApkUrl(apkUrls);
  
  /// 获取推荐的 APK 类型描述
  String get recommendedApkType {
    if (apkUrls.containsKey('arm64')) {
      return 'arm64-v8a';
    }
    if (apkUrls.containsKey('armeabi')) {
      return 'armeabi-v7a';
    }
    if (apkUrls.containsKey('x86_64')) {
      return 'x86_64';
    }
    return 'universal';
  }
}