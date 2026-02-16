import 'package:flutter/material.dart';
import '../models/video_info.dart';
import '../services/api_service.dart';
import 'recommendation_section.dart';
import 'video_menu_bottom_sheet.dart';

/// 周榜类型
enum WeeklyHotType {
  movie, // 电影周榜
  tv, // 剧集周榜
}

// 静态缓存：避免重复加载
List<WeeklyHotItem> _cachedMovieItems = [];
List<WeeklyHotItem> _cachedTvItems = [];

/// 周榜组件（电影周榜/剧集周榜）
class WeeklyHotSection extends StatefulWidget {
  final WeeklyHotType type;
  final Function(VideoInfo)? onItemTap;
  final Function(VideoInfo, VideoMenuAction)? onGlobalMenuAction;
  final int limit;

  const WeeklyHotSection({
    super.key,
    required this.type,
    this.onItemTap,
    this.onGlobalMenuAction,
    this.limit = 10,
  });

  /// 静态方法：刷新周榜数据
  static Future<void> refresh({WeeklyHotType? type}) async {
    // 清除对应的缓存，下次构建时会重新加载
    if (type == WeeklyHotType.movie) {
      _cachedMovieItems = [];
    } else if (type == WeeklyHotType.tv) {
      _cachedTvItems = [];
    } else {
      _cachedMovieItems = [];
      _cachedTvItems = [];
    }
  }

  @override
  State<WeeklyHotSection> createState() => _WeeklyHotSectionState();
}

class _WeeklyHotSectionState extends State<WeeklyHotSection> {
  List<WeeklyHotItem> _items = [];
  bool _isLoading = true;
  bool _hasError = false;

  @override
  void initState() {
    super.initState();
    // 使用缓存数据
    final cachedItems = widget.type == WeeklyHotType.movie 
        ? _cachedMovieItems 
        : _cachedTvItems;
    
    if (cachedItems.isNotEmpty) {
      _items = cachedItems;
      _isLoading = false;
    } else {
      _loadData();
    }
  }

  @override
  void dispose() {
    super.dispose();
  }

  Future<void> _loadData() async {
    // 只有在没有数据时才显示加载状态
    if (_items.isEmpty) {
      setState(() {
        _isLoading = true;
        _hasError = false;
      });
    }

    try {
      final typeStr = widget.type == WeeklyHotType.movie ? 'movie' : 'tv';
      final items = await ApiService.getWeeklyHot(
        type: typeStr,
        limit: widget.limit,
      );

      if (mounted) {
        setState(() {
          _items = items;
          _isLoading = false;
        });
        
        // 更新静态缓存
        if (widget.type == WeeklyHotType.movie) {
          _cachedMovieItems = items;
        } else {
          _cachedTvItems = items;
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _hasError = true;
          _isLoading = false;
        });
      }
    }
  }

  /// 转换为VideoInfo列表
  List<VideoInfo> _convertToVideoInfos() {
    return _items.map((item) {
      return VideoInfo(
        id: item.id,
        source: 'douban',
        title: item.title,
        sourceName: widget.type == WeeklyHotType.movie ? '电影周榜' : '剧集周榜',
        year: item.year ?? '',
        cover: item.cover,
        index: 0,
        totalEpisodes: 0,
        playTime: 0,
        totalTime: 0,
        saveTime: DateTime.now().millisecondsSinceEpoch,
        searchTitle: item.title,
        rate: item.rating > 0 ? item.rating.toStringAsFixed(1) : null,
        doubanId: item.id,
      );
    }).toList();
  }

  String get _title => widget.type == WeeklyHotType.movie ? '电影周榜' : '剧集周榜';

  @override
  Widget build(BuildContext context) {
    // 如果没有数据且不加载中，不显示
    if (!_isLoading && _items.isEmpty && !_hasError) {
      return const SizedBox.shrink();
    }

    return RecommendationSection(
      title: _title,
      videoInfos: _convertToVideoInfos(),
      onItemTap: widget.onItemTap,
      onGlobalMenuAction: widget.onGlobalMenuAction,
      isLoading: _isLoading,
      hasError: _hasError,
      onRetry: _loadData,
      cardCount: 2.75,
    );
  }
}
