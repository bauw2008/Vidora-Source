import 'dart:async';
import '../services/api_service.dart';
import '../services/tmdb_service.dart';
import '../services/menu_config_service.dart';

/// 海报轮播项（简化版 - 只用横屏图片）
class PosterItem {
  final String id;
  final String title;
  final String poster;
  final String type;
  final String category;
  final String? rate;
  final String? year;
  final String? overview;

  PosterItem({
    required this.id,
    required this.title,
    required this.poster,
    required this.type,
    required this.category,
    this.rate,
    this.year,
    this.overview,
  });
}

/// 全局海报数据服务
/// 
/// 缓存策略：按天缓存（与 Vidora Web 版一致）
/// 海报来源：电影周榜(2张) + 剧集周榜(2张) + 全球剧集(2张) = 共6张
class PosterService {
  static final PosterService _instance = PosterService._internal();
  factory PosterService() => _instance;
  PosterService._internal();

  List<PosterItem> _cachedPosters = [];
  String? _cacheDate; // 按天缓存
  bool _isLoading = false;
  bool? _tmdbEnabled;

  final _controller = StreamController<void>.broadcast();
  Stream<void> get onRefresh => _controller.stream;

  /// 获取当天日期字符串
  String _getDateString() {
    return DateTime.now().toIso8601String().split('T')[0];
  }

  /// 检查缓存是否有效（按天）
  bool get _isCacheValid {
    return _cacheDate == _getDateString() && _cachedPosters.isNotEmpty;
  }

  /// 获取海报数据
  Future<List<PosterItem>> getPosters() async {
    if (_isCacheValid) {
      return _cachedPosters;
    }

    if (!_isLoading) {
      await refresh();
    }

    return _cachedPosters;
  }

  bool get hasData => _cachedPosters.isNotEmpty;
  bool get isLoading => _isLoading;

  /// 刷新海报数据
  Future<void> refresh() async {
    if (_isLoading) return;
    _isLoading = true;

    try {
      // 获取 TMDB 开关（只请求一次）
      _tmdbEnabled ??= await MenuConfigService.isTMDBPostersEnabled();

      // 并行获取三种周榜
      final results = await Future.wait([
        ApiService.getWeeklyHot(type: 'movie', limit: 10),
        ApiService.getWeeklyHot(type: 'tv', limit: 10),
        ApiService.getWeeklyHot(type: 'tv-global', limit: 10),
      ]);

      final List<Future<PosterItem?>> futures = [];

      // 电影：随机选2部
      futures.addAll(_pickRandom(results[0], 2).map((e) => 
        _buildItem(e, 'movie', '热门电影')));

      // 剧集：随机选2部
      futures.addAll(_pickRandom(results[1], 2).map((e) => 
        _buildItem(e, 'tv', '热门剧集')));

      // 全球剧集：随机选2部
      futures.addAll(_pickRandom(results[2], 2).map((e) => 
        _buildItem(e, 'tv', '全球剧集')));

      // 并行获取 TMDB 海报
      final posters = (await Future.wait(futures))
          .whereType<PosterItem>()
          .toList()
        ..shuffle();

      _cachedPosters = posters;
      _cacheDate = _getDateString();
      _controller.add(null);
    } catch (e) {
      print('加载海报数据失败: $e');
    } finally {
      _isLoading = false;
    }
  }

  /// 构建单个海报项
  Future<PosterItem?> _buildItem(WeeklyHotItem item, String type, String category) async {
    TMDBPosterData? tmdb;
    
    // TMDB 开关开启才获取
    if (_tmdbEnabled == true) {
      tmdb = await TMDBService.searchPoster(
        title: item.title,
        category: type,
        year: item.year,
      );
    }

    // 海报：TMDB backdrop > 豆瓣封面
    final poster = tmdb?.backdrop ?? item.cover;
    if (poster.isEmpty) return null;

    // 简介：TMDB > 豆瓣
    final overview = tmdb?.overview ?? item.description;

    return PosterItem(
      id: item.id,
      title: item.title,
      poster: poster,
      type: type,
      category: category,
      rate: item.rating > 0 ? item.rating.toStringAsFixed(1) : null,
      year: item.year,
      overview: overview?.isNotEmpty == true ? overview : null,
    );
  }

  /// 随机选择
  List<T> _pickRandom<T>(List<T> items, int count) {
    if (items.length <= count) return items;
    return (List<T>.from(items)..shuffle()).take(count).toList();
  }

  /// 清除缓存
  void clearCache() {
    _cachedPosters = [];
    _cacheDate = null;
    _tmdbEnabled = null;
  }

  void dispose() {
    _controller.close();
  }
}