import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../services/poster_service.dart';
import '../models/video_info.dart';
import '../utils/font_utils.dart';

/// 海报轮播组件
/// 使用全局 PosterService 获取数据，页面切换时不会重复加载
class PosterCarousel extends StatefulWidget {
  final Function(VideoInfo)? onPosterTap;

  const PosterCarousel({
    super.key,
    this.onPosterTap,
  });

  @override
  State<PosterCarousel> createState() => _PosterCarouselState();
}

class _PosterCarouselState extends State<PosterCarousel> {
  final PosterService _posterService = PosterService();
  List<PosterItem> _posters = [];
  bool _isLoading = true;
  int _currentIndex = 0;
  Timer? _autoPlayTimer;
  final PageController _pageController = PageController();
  StreamSubscription<void>? _refreshSubscription;

  @override
  void initState() {
    super.initState();
    _loadPosters();
    // 监听数据刷新
    _refreshSubscription = _posterService.onRefresh.listen((_) {
      _loadPosters();
    });
  }

  @override
  void dispose() {
    _autoPlayTimer?.cancel();
    _pageController.dispose();
    _refreshSubscription?.cancel();
    super.dispose();
  }

  /// 加载海报数据
  Future<void> _loadPosters() async {
    // 先检查是否已有缓存数据
    if (_posterService.hasData && !_posterService.isLoading) {
      final posters = await _posterService.getPosters();
      if (mounted && posters.isNotEmpty) {
        setState(() {
          _posters = posters;
          _isLoading = false;
        });
        _startAutoPlay();
      }
      return;
    }

    // 没有缓存，显示加载状态
    setState(() {
      _isLoading = true;
    });

    // 获取数据
    final posters = await _posterService.getPosters();

    if (mounted) {
      setState(() {
        _posters = posters;
        _isLoading = false;
      });
      if (posters.isNotEmpty) {
        _startAutoPlay();
      }
    }
  }

  /// 开始自动播放
  void _startAutoPlay() {
    _autoPlayTimer?.cancel();
    _autoPlayTimer = Timer.periodic(const Duration(seconds: 5), (timer) {
      if (_posters.isEmpty) return;
      final nextIndex = (_currentIndex + 1) % _posters.length;
      _pageController.animateToPage(
        nextIndex,
        duration: const Duration(milliseconds: 500),
        curve: Curves.easeInOut,
      );
    });
  }

  /// 转换为 VideoInfo
  VideoInfo _toVideoInfo(PosterItem poster) {
    return VideoInfo(
      id: poster.id,
      source: 'douban',
      title: poster.title,
      sourceName: poster.category,
      year: poster.year ?? '',
      cover: poster.poster,
      index: 0,
      totalEpisodes: 0,
      playTime: 0,
      totalTime: 0,
      saveTime: DateTime.now().millisecondsSinceEpoch,
      searchTitle: poster.title,
      rate: poster.rate,
      doubanId: poster.id,
    );
  }

  @override
  Widget build(BuildContext context) {
    // 加载中或没有海报数据时，不显示任何内容
    if (_isLoading || _posters.isEmpty) {
      return const SizedBox.shrink();
    }

    return Column(
      children: [
        // 海报轮播
        AspectRatio(
          aspectRatio: 16 / 9,
          child: PageView.builder(
            controller: _pageController,
            onPageChanged: (index) {
              setState(() {
                _currentIndex = index;
              });
            },
            itemCount: _posters.length,
            itemBuilder: (context, index) {
              final poster = _posters[index];
              return _buildPosterItem(poster);
            },
          ),
        ),
        const SizedBox(height: 12),
        // 指示器
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(_posters.length, (index) {
            return Container(
              width: 8,
              height: 8,
              margin: const EdgeInsets.symmetric(horizontal: 4),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: _currentIndex == index
                    ? const Color(0xFF27AE60)
                    : Colors.grey.withOpacity(0.3),
              ),
            );
          }),
        ),
      ],
    );
  }

  Widget _buildPosterItem(PosterItem poster) {
    return GestureDetector(
      onTap: () {
        widget.onPosterTap?.call(_toVideoInfo(poster));
      },
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.3),
              blurRadius: 10,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: Stack(
            fit: StackFit.expand,
            children: [
              // 海报图片 - 加载完成后才显示
              _PosterImage(url: poster.poster),
              // 渐变遮罩
              Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.transparent,
                      Colors.black.withOpacity(0.7),
                    ],
                    stops: const [0.6, 1.0],
                  ),
                ),
              ),
              // 内容信息
              Positioned(
                left: 16,
                right: 16,
                bottom: 16,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // 分类标签
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFF27AE60),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        poster.category,
                        style: FontUtils.poppins(
                          fontSize: 12,
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    // 标题
                    Text(
                      poster.title,
                      style: FontUtils.poppins(
                        fontSize: 20,
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    // 评分和年份
                    Row(
                      children: [
                        if (poster.rate != null) ...[
                          const Icon(
                            Icons.star,
                            color: Colors.amber,
                            size: 16,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            poster.rate!,
                            style: FontUtils.poppins(
                              fontSize: 14,
                              color: Colors.amber,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(width: 12),
                        ],
                        if (poster.year != null)
                          Text(
                            poster.year!,
                            style: FontUtils.poppins(
                              fontSize: 14,
                              color: Colors.white70,
                            ),
                          ),
                      ],
                    ),
                    // 简介
                    if (poster.overview != null && poster.overview!.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Text(
                        poster.overview!,
                        style: FontUtils.poppins(
                          fontSize: 12,
                          color: Colors.white.withValues(alpha: 0.85),
                          height: 1.4,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 海报图片组件 - 支持加载完成后淡入显示
class _PosterImage extends StatefulWidget {
  final String url;
  
  const _PosterImage({required this.url});
  
  @override
  State<_PosterImage> createState() => _PosterImageState();
}

class _PosterImageState extends State<_PosterImage> {
  bool _loaded = false;
  
  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        // 图片 - 加载完成后淡入显示
        AnimatedOpacity(
          opacity: _loaded ? 1.0 : 0.0,
          duration: const Duration(milliseconds: 500),
          child: CachedNetworkImage(
            imageUrl: widget.url,
            fit: BoxFit.cover,
            fadeInDuration: Duration.zero,
            fadeOutDuration: Duration.zero,
            placeholder: (context, url) => const SizedBox.shrink(),
            errorWidget: (context, url, error) {
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (mounted && !_loaded) {
                  setState(() => _loaded = true);
                }
              });
              return Container(
                color: Colors.grey[800],
              );
            },
            imageBuilder: (context, imageProvider) {
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (mounted && !_loaded) {
                  setState(() => _loaded = true);
                }
              });
              return Image(image: imageProvider, fit: BoxFit.cover);
            },
          ),
        ),
      ],
    );
  }
}