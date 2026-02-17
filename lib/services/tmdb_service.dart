import 'api_service.dart';
import 'douban_cache_service.dart';

/// TMDB海报数据模型
class TMDBPosterData {
  final String id;
  final String title;
  final String backdrop;
  final String poster;
  final String rate;
  final String year;
  final String overview;

  TMDBPosterData({
    required this.id,
    required this.title,
    required this.backdrop,
    required this.poster,
    required this.rate,
    required this.year,
    required this.overview,
  });

  factory TMDBPosterData.fromJson(Map<String, dynamic> json) {
    return TMDBPosterData(
      id: json['id']?.toString() ?? '',
      title: json['title'] ?? '',
      backdrop: json['backdrop'] ?? '',
      poster: json['poster'] ?? '',
      rate: json['rate']?.toString() ?? '',
      year: json['year']?.toString() ?? '',
      overview: json['overview']?.toString() ?? '',
    );
  }

  /// 是否有有效的横屏海报
  bool get hasBackdrop => backdrop.isNotEmpty;

  /// 是否有有效的竖屏海报
  bool get hasPoster => poster.isNotEmpty;

  /// 是否有简介
  bool get hasOverview => overview.isNotEmpty;
}

/// TMDB服务类
/// 
/// 缓存策略：
/// - 服务端已有完整的 TMDB 缓存（Redis + 内存缓存）
/// - 客户端额外缓存以减少网络请求
/// - 搜索结果缓存24小时，热门内容缓存2小时
class TMDBService {
  static final TMDBService _instance = TMDBService._internal();
  factory TMDBService() => _instance;
  TMDBService._internal();

  final _cacheService = DoubanCacheService();

  /// 缓存时长：搜索结果24小时，热门内容2小时
  static const Duration _searchCacheDuration = Duration(hours: 24);
  static const Duration _trendingCacheDuration = Duration(hours: 2);

  /// 搜索TMDB海报
  /// [title] 标题
  /// [category] 类型: 'movie' 电影, 'tv' 剧集
  /// [year] 年份（可选）
  /// 
  /// 说明：服务端已有 TMDB 缓存，客户端额外缓存可减少重复请求
  static Future<TMDBPosterData?> searchPoster({
    required String title,
    required String category,
    String? year,
  }) async {
    if (title.isEmpty) return null;
    
    try {
      // 生成缓存键
      final cacheKey = _generateSearchCacheKey(
        title: title,
        category: category,
        year: year,
      );

      // 尝试从客户端缓存获取
      final cached = await _instance._cacheService.get<TMDBPosterData>(
        cacheKey,
        (data) => TMDBPosterData.fromJson(data as Map<String, dynamic>),
      );

      if (cached != null) {
        return cached;
      }

      // 缓存未命中，从服务端获取（服务端有 Redis 缓存）
      final response = await ApiService.get<Map<String, dynamic>>(
        '/api/tmdb/posters',
        queryParameters: {
          'category': category,
          'title': title,
          if (year != null) 'year': year,
        },
        fromJson: (data) => data as Map<String, dynamic>,
      );

      if (response.success && response.data != null) {
        final data = response.data!;
        final success = data['success'] as bool? ?? false;
        
        if (success && data['data'] != null) {
          final posterData = TMDBPosterData.fromJson(
            data['data'] as Map<String, dynamic>,
          );

          // 保存到客户端缓存
          await _instance._cacheService.set(
            cacheKey,
            posterData,
            _searchCacheDuration,
          );

          return posterData;
        }
      }

      return null;
    } catch (e) {
      print('搜索TMDB海报失败: $e');
      return null;
    }
  }

  /// 获取热门内容的海报
  /// [category] 类型: 'movie' 电影, 'tv' 剧集
  static Future<TMDBPosterData?> getTrendingPoster({
    required String category,
  }) async {
    try {
      // 生成缓存键
      final cacheKey = 'tmdb_trending_$category';

      // 尝试从缓存获取
      final cached = await _instance._cacheService.get<TMDBPosterData>(
        cacheKey,
        (data) => TMDBPosterData.fromJson(data as Map<String, dynamic>),
      );

      if (cached != null) {
        return cached;
      }

      // 缓存未命中，从服务端获取
      final response = await ApiService.get<Map<String, dynamic>>(
        '/api/tmdb/posters',
        queryParameters: {
          'category': category,
        },
        fromJson: (data) => data as Map<String, dynamic>,
      );

      if (response.success && response.data != null) {
        final data = response.data!;
        final success = data['success'] as bool? ?? false;
        
        if (success && data['data'] != null) {
          final posterData = TMDBPosterData.fromJson(
            data['data'] as Map<String, dynamic>,
          );

          // 保存到缓存
          await _instance._cacheService.set(
            cacheKey,
            posterData,
            _trendingCacheDuration,
          );

          return posterData;
        }
      }

      return null;
    } catch (e) {
      print('获取TMDB热门海报失败: $e');
      return null;
    }
  }

  /// 生成搜索缓存键
  static String _generateSearchCacheKey({
    required String title,
    required String category,
    String? year,
  }) {
    final params = {
      'title': title,
      'category': category,
      if (year != null) 'year': year,
    };
    final sortedKeys = params.keys.toList()..sort();
    final paramString = sortedKeys.map((key) => '$key=${params[key]}').join('&');
    return 'tmdb_search_$paramString';
  }
}