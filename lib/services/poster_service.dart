import 'dart:async';
import '../services/api_service.dart';
import '../services/tmdb_service.dart';

/// 海报轮播项
class PosterItem {
  final String id;
  final String title;
  final String poster;
  final String? portraitPoster;
  final String? landscapePoster;
  final String type; // 'movie' | 'tv'
  final String category;
  final String? rate;
  final String? year;
  final String? overview;

  PosterItem({
    required this.id,
    required this.title,
    required this.poster,
    this.portraitPoster,
    this.landscapePoster,
    required this.type,
    required this.category,
    this.rate,
    this.year,
    this.overview,
  });
}

/// 全局海报数据服务
/// 登录时刷新一次，让用户每次登录看到不同的海报
class PosterService {
  // 单例模式
  static final PosterService _instance = PosterService._internal();
  factory PosterService() => _instance;
  PosterService._internal();

  // 缓存数据
  List<PosterItem> _cachedPosters = [];
  bool _isLoading = false;

  // 通知监听器
  final _controller = StreamController<void>.broadcast();
  Stream<void> get onRefresh => _controller.stream;

  /// 获取海报数据
  Future<List<PosterItem>> getPosters() async {
    // 有缓存直接返回
    if (_cachedPosters.isNotEmpty) {
      return _cachedPosters;
    }

    // 没有缓存，加载一次
    if (!_isLoading) {
      await refresh();
    }

    return _cachedPosters;
  }

  /// 是否已有数据
  bool get hasData => _cachedPosters.isNotEmpty;

  /// 是否正在加载
  bool get isLoading => _isLoading;

  /// 刷新海报数据（登录时调用）
  Future<void> refresh() async {
    if (_isLoading) return;

    _isLoading = true;

    try {
      // 并行获取电影和剧集周榜
      final movieResults = await ApiService.getWeeklyHot(type: 'movie', limit: 10);
      final tvResults = await ApiService.getWeeklyHot(type: 'tv', limit: 10);

      final List<PosterItem> posters = [];

      // 处理电影数据 - 随机选择2部
      if (movieResults.isNotEmpty) {
        final selectedMovies = _getRandomItems(movieResults, 2);
        for (final movie in selectedMovies) {
          // 优先尝试从 TMDB 获取海报和简介
          final tmdbData = await TMDBService.searchPoster(
            title: movie.title,
            category: 'movie',
            year: movie.year,
          );

          // 选择最佳海报
          String bestPoster = movie.cover;
          if (tmdbData != null && tmdbData.hasBackdrop) {
            bestPoster = tmdbData.backdrop;
          }

          // 选择最佳简介
          String bestOverview = movie.description ?? '';
          if (tmdbData != null && tmdbData.hasOverview) {
            bestOverview = tmdbData.overview;
          }

          posters.add(PosterItem(
            id: movie.id,
            title: movie.title,
            poster: bestPoster,
            type: 'movie',
            category: '热门电影',
            rate: movie.rating > 0 ? movie.rating.toStringAsFixed(1) : null,
            year: movie.year,
            overview: bestOverview.isNotEmpty ? bestOverview : null,
          ));
        }
      }

      // 处理剧集数据 - 随机选择2部
      if (tvResults.isNotEmpty) {
        final selectedTv = _getRandomItems(tvResults, 2);
        for (final tv in selectedTv) {
          // 优先尝试从 TMDB 获取海报和简介
          final tmdbData = await TMDBService.searchPoster(
            title: tv.title,
            category: 'tv',
            year: tv.year,
          );

          // 选择最佳海报
          String bestPoster = tv.cover;
          if (tmdbData != null && tmdbData.hasBackdrop) {
            bestPoster = tmdbData.backdrop;
          }

          // 选择最佳简介
          String bestOverview = tv.description ?? '';
          if (tmdbData != null && tmdbData.hasOverview) {
            bestOverview = tmdbData.overview;
          }

          posters.add(PosterItem(
            id: tv.id,
            title: tv.title,
            poster: bestPoster,
            type: 'tv',
            category: '热门剧集',
            rate: tv.rating > 0 ? tv.rating.toStringAsFixed(1) : null,
            year: tv.year,
            overview: bestOverview.isNotEmpty ? bestOverview : null,
          ));
        }
      }

      // 随机打乱顺序
      posters.shuffle();

      _cachedPosters = posters;

      // 通知监听器
      _controller.add(null);
    } catch (e) {
      print('加载海报数据失败: $e');
    } finally {
      _isLoading = false;
    }
  }

  /// 从列表中随机选择指定数量的元素
  List<T> _getRandomItems<T>(List<T> items, int count) {
    if (items.length <= count) return items;
    final shuffled = List<T>.from(items)..shuffle();
    return shuffled.take(count).toList();
  }

  /// 清除缓存（退出登录时调用）
  void clearCache() {
    _cachedPosters = [];
  }

  /// 释放资源
  void dispose() {
    _controller.close();
  }
}
