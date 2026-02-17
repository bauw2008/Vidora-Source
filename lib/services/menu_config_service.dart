import 'dart:convert';
import 'package:http/http.dart' as http;
import 'user_data_service.dart';

/// 菜单设置模型
class MenuSettings {
  final bool showMovies;
  final bool showTVShows;
  final bool showAnime;
  final bool showVariety;
  final bool showLive;
  final bool showTvbox;
  final bool showShortDrama;

  MenuSettings({
    this.showMovies = true,
    this.showTVShows = true,
    this.showAnime = true,
    this.showVariety = true,
    this.showLive = false,
    this.showTvbox = false,
    this.showShortDrama = false,
  });

  factory MenuSettings.fromJson(Map<String, dynamic> json) {
    return MenuSettings(
      showMovies: json['showMovies'] ?? true,
      showTVShows: json['showTVShows'] ?? true,
      showAnime: json['showAnime'] ?? true,
      showVariety: json['showVariety'] ?? true,
      showLive: json['showLive'] ?? false,
      showTvbox: json['showTvbox'] ?? false,
      showShortDrama: json['showShortDrama'] ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'showMovies': showMovies,
      'showTVShows': showTVShows,
      'showAnime': showAnime,
      'showVariety': showVariety,
      'showLive': showLive,
      'showTvbox': showTvbox,
      'showShortDrama': showShortDrama,
    };
  }

  /// 获取菜单标签
  static String getMenuLabel(String key) {
    final labels = {
      'showMovies': '电影',
      'showTVShows': '剧集',
      'showAnime': '动漫',
      'showVariety': '综艺',
      'showLive': '直播',
      'showTvbox': 'TVBox',
      'showShortDrama': '短剧',
    };
    return labels[key] ?? key;
  }
}

/// TMDB 配置模型
class TMDBConfig {
  final bool enablePosters;
  final bool enableActorSearch;

  TMDBConfig({
    this.enablePosters = false,
    this.enableActorSearch = false,
  });

  factory TMDBConfig.fromJson(Map<String, dynamic> json) {
    return TMDBConfig(
      enablePosters: json['enablePosters'] ?? false,
      enableActorSearch: json['enableActorSearch'] ?? false,
    );
  }
}

/// 公开配置数据
class PublicConfig {
  final MenuSettings menuSettings;
  final List<dynamic> customCategories;
  final TMDBConfig tmdbConfig;

  PublicConfig({
    required this.menuSettings,
    this.customCategories = const [],
    TMDBConfig? tmdbConfig,
  }) : tmdbConfig = tmdbConfig ?? TMDBConfig();

  factory PublicConfig.fromJson(Map<String, dynamic> json) {
    return PublicConfig(
      menuSettings: MenuSettings.fromJson(json['MenuSettings'] ?? {}),
      customCategories: json['CustomCategories'] ?? [],
      tmdbConfig: json['TMDBConfig'] != null
          ? TMDBConfig.fromJson(json['TMDBConfig'])
          : null,
    );
  }
}

/// 菜单配置服务
class MenuConfigService {
  static const Duration _timeout = Duration(seconds: 10);
  static PublicConfig? _cachedConfig;
  static DateTime? _lastFetchTime;
  static const Duration _cacheDuration = Duration(minutes: 5);

  /// 获取基础 URL
  static Future<String?> _getBaseUrl() async {
    return await UserDataService.getServerUrl();
  }

  /// 获取认证 cookies
  static Future<String?> _getCookies() async {
    return await UserDataService.getCookies();
  }

  /// 获取公开配置
  static Future<PublicConfig?> getPublicConfig({bool forceRefresh = false}) async {
    // 检查缓存
    if (!forceRefresh && _cachedConfig != null && _lastFetchTime != null) {
      final age = DateTime.now().difference(_lastFetchTime!);
      if (age < _cacheDuration) {
        return _cachedConfig;
      }
    }

    final baseUrl = await _getBaseUrl();
    if (baseUrl == null) return null;

    final cookies = await _getCookies();
    final headers = <String, String>{
      'Accept': 'application/json',
    };
    if (cookies != null && cookies.isNotEmpty) {
      headers['Cookie'] = cookies;
    }

    try {
      final response = await http.get(
        Uri.parse('$baseUrl/api/public-config'),
        headers: headers,
      ).timeout(_timeout);

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final config = PublicConfig.fromJson(data);
        
        // 更新缓存
        _cachedConfig = config;
        _lastFetchTime = DateTime.now();
        
        return config;
      }
      return null;
    } catch (e) {
      print('获取菜单配置失败: $e');
      // 如果有缓存，返回缓存数据
      return _cachedConfig;
    }
  }

  /// 获取菜单设置
  static Future<MenuSettings> getMenuSettings({bool forceRefresh = false}) async {
    final config = await getPublicConfig(forceRefresh: forceRefresh);
    return config?.menuSettings ?? MenuSettings();
  }

  /// 获取 TMDB 配置
  static Future<TMDBConfig> getTMDBConfig({bool forceRefresh = false}) async {
    final config = await getPublicConfig(forceRefresh: forceRefresh);
    return config?.tmdbConfig ?? TMDBConfig();
  }

  /// 检查 TMDB 海报功能是否启用
  static Future<bool> isTMDBPostersEnabled() async {
    final tmdbConfig = await getTMDBConfig();
    return tmdbConfig.enablePosters;
  }

  /// 检查菜单是否启用
  static Future<bool> isMenuEnabled(String menuKey) async {
    final settings = await getMenuSettings();
    switch (menuKey) {
      case 'showMovies':
        return settings.showMovies;
      case 'showTVShows':
        return settings.showTVShows;
      case 'showAnime':
        return settings.showAnime;
      case 'showVariety':
        return settings.showVariety;
      case 'showLive':
        return settings.showLive;
      case 'showTvbox':
        return settings.showTvbox;
      case 'showShortDrama':
        return settings.showShortDrama;
      default:
        return true;
    }
  }

  /// 清除缓存
  static void clearCache() {
    _cachedConfig = null;
    _lastFetchTime = null;
  }
}
