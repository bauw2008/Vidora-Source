import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../services/theme_service.dart';
import '../services/shortdrama_service.dart';
import '../models/video_info.dart';
import '../widgets/video_menu_bottom_sheet.dart';
import '../widgets/pulsing_dots_indicator.dart';
import '../widgets/custom_refresh_indicator.dart';
import '../widgets/capsule_tab_switcher.dart';
import '../utils/device_utils.dart';
import '../utils/font_utils.dart';
import 'player_screen.dart';

class ShortDramaScreen extends StatefulWidget {
  const ShortDramaScreen({super.key});

  @override
  State<ShortDramaScreen> createState() => _ShortDramaScreenState();
}

class _ShortDramaScreenState extends State<ShortDramaScreen> {
  // 分类数据
  List<ShortDramaCategory> _categories = [];
  int _selectedCategoryId = 0;
  String _selectedSubCategoryName = '';
  
  // 搜索状态
  bool _isSearchMode = false;
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  
  // 列表数据
  final List<ShortDramaItem> _dramaList = [];
  int _page = 1;
  final int _pageSize = 25;
  bool _isLoading = false;
  bool _isLoadingMore = false;
  bool _hasMore = true;
  String? _errorMessage;
  
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _loadCategories();
    _scrollController.addListener(_handleScroll);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  void _handleScroll() {
    if (_scrollController.hasClients) {
      final position = _scrollController.position;
      const double threshold = 50.0;
      if (position.pixels >= position.maxScrollExtent - threshold) {
        _loadMoreData();
      }
    }
  }

  Future<void> _loadCategories() async {
    try {
      final categories = await ShortDramaService.getCategories();
      if (mounted) {
        setState(() {
          _categories = categories;
          // 只要分类列表不为空，就设置第一个为默认值
          // 注意：分类 ID 可能为 0，这是有效值
          if (categories.isNotEmpty) {
            _selectedCategoryId = categories[0].id;
            if (categories[0].subCategories != null && 
                categories[0].subCategories!.isNotEmpty) {
              _selectedSubCategoryName = categories[0].subCategories![0].name;
            }
          }
        });
      }
    } catch (e) {
      // 静默处理错误，不影响列表加载
      print('加载短剧分类失败: $e');
    }
    
    // 无论分类是否加载成功，都尝试加载列表数据
    _fetchData(isRefresh: true);
  }

  Future<void> _fetchData({bool isRefresh = false}) async {
    if (_isSearchMode) {
      await _searchDramas(isRefresh: isRefresh);
    } else {
      await _fetchDramaList(isRefresh: isRefresh);
    }
  }

  Future<void> _fetchDramaList({bool isRefresh = false}) async {
    setState(() {
      _isLoading = true;
      if (isRefresh) {
        _dramaList.clear();
        _page = 1;
        _hasMore = true;
      }
      _errorMessage = null;
    });

    final result = await ShortDramaService.getList(
      page: _page,
      size: _pageSize,
      tag: _selectedSubCategoryName.isNotEmpty ? _selectedSubCategoryName : null,
    );

    if (mounted) {
      setState(() {
        if (result.list.isNotEmpty) {
          _dramaList.addAll(result.list);
          _page++;
          _hasMore = result.hasMore;
        } else {
          _hasMore = false;
        }
        _isLoading = false;
      });
    }
  }

  Future<void> _searchDramas({bool isRefresh = false}) async {
    if (_searchQuery.isEmpty) {
      setState(() {
        _isSearchMode = false;
      });
      _fetchData(isRefresh: true);
      return;
    }

    setState(() {
      _isLoading = true;
      if (isRefresh) {
        _dramaList.clear();
        _page = 1;
        _hasMore = true;
      }
      _errorMessage = null;
    });

    final result = await ShortDramaService.search(
      query: _searchQuery,
      page: _page,
      size: _pageSize,
    );

    if (mounted) {
      setState(() {
        if (result.list.isNotEmpty) {
          _dramaList.addAll(result.list);
          _page++;
          _hasMore = result.hasMore;
        } else {
          _hasMore = false;
        }
        _isLoading = false;
      });
    }
  }

  Future<void> _loadMoreData() async {
    if (_isLoading || _isLoadingMore || !_hasMore) return;

    setState(() {
      _isLoadingMore = true;
    });

    await _fetchData();

    setState(() {
      _isLoadingMore = false;
    });
  }

  Future<void> _refreshData() async {
    await _fetchData(isRefresh: true);
  }

  void _onVideoTap(ShortDramaItem item) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => PlayerScreen(
          title: item.title,
          source: 'shortdrama',
          id: item.id,
          stype: 'shortdrama',
          year: item.year,
        ),
      ),
    );
  }

  void _handleMenuAction(VideoInfo videoInfo, VideoMenuAction action) {
    switch (action) {
      case VideoMenuAction.play:
        _onVideoTap(ShortDramaItem(
          id: videoInfo.id,
          title: videoInfo.title,
          poster: videoInfo.cover,
          year: videoInfo.year,
        ));
        break;
      default:
        break;
    }
  }

  void _onCategoryChanged(int categoryId) {
    if (_selectedCategoryId != categoryId) {
      final category = _categories.firstWhere((c) => c.id == categoryId);
      String subCategoryName = '';
      if (category.subCategories != null && category.subCategories!.isNotEmpty) {
        subCategoryName = category.subCategories![0].name;
      }
      setState(() {
        _selectedCategoryId = categoryId;
        _selectedSubCategoryName = subCategoryName;
      });
      _fetchData(isRefresh: true);
    }
  }

  void _onSubCategoryChanged(String subCategoryName) {
    if (_selectedSubCategoryName != subCategoryName) {
      setState(() {
        _selectedSubCategoryName = subCategoryName;
      });
      _fetchData(isRefresh: true);
    }
  }

  void _toggleSearch() {
    setState(() {
      _isSearchMode = !_isSearchMode;
      if (!_isSearchMode) {
        _searchController.clear();
        _searchQuery = '';
        _fetchData(isRefresh: true);
      }
    });
  }

  void _onSearchSubmitted(String query) {
    if (query.trim().isNotEmpty) {
      setState(() {
        _searchQuery = query.trim();
        _isSearchMode = true;
      });
      _fetchData(isRefresh: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final themeService = Provider.of<ThemeService>(context);
    
    return StyledRefreshIndicator(
      onRefresh: _refreshData,
      refreshText: '刷新短剧数据...',
      primaryColor: const Color(0xFFE91E63),
      child: SingleChildScrollView(
        controller: _scrollController,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeader(themeService),
            // 显示分类选择器（只在有分类数据且不在搜索模式时显示）
            if (!_isSearchMode && _categories.isNotEmpty)
              _buildCategorySelector(themeService),
            if (_isSearchMode) _buildSearchBar(themeService),
            const SizedBox(height: 16),
            _buildDramaGrid(themeService),
            // 底部指示器
            if (_isLoadingMore)
              const Padding(
                padding: EdgeInsets.all(16.0),
                child: PulsingDotsIndicator(),
              )
            else if (!_hasMore && _dramaList.isNotEmpty && !_isLoading)
              _buildEndOfListIndicator(themeService)
            else
              const SizedBox(height: 50),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(ThemeService themeService) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 16, 8),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '短剧',
                  style: FontUtils.poppins(
                    fontSize: 28,
                    fontWeight: FontWeight.w600,
                    color: Theme.of(context).textTheme.titleLarge?.color,
                  ),
                ),
                const SizedBox(height: 4),
                SizedBox(
                  height: 20,
                  child: Text(
                    _isSearchMode 
                        ? '搜索"${_searchQuery}"的结果'
                        : '精选短剧内容',
                    style: FontUtils.poppins(
                      fontSize: 14,
                      color: Theme.of(context).textTheme.bodySmall?.color,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            icon: Icon(
              _isSearchMode ? Icons.close : Icons.search,
              color: themeService.isDarkMode ? Colors.white70 : Colors.black54,
            ),
            onPressed: _toggleSearch,
          ),
        ],
      ),
    );
  }
  
  Widget _buildCategorySelector(ThemeService themeService) {
    final selectedCategory = _categories.firstWhere(
      (c) => c.id == _selectedCategoryId,
      orElse: () => _categories.first,
    );
    
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
      decoration: BoxDecoration(
        color: themeService.isDarkMode
            ? Colors.white.withOpacity(0.1)
            : Colors.white.withOpacity(0.8),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 一级分类 - 分类
          if (_categories.isNotEmpty) ...[
            Text(
              '分类',
              style: FontUtils.poppins(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: Theme.of(context).textTheme.bodyMedium?.color,
              ),
            ),
            const SizedBox(height: 8),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: CapsuleTabSwitcher(
                tabs: _categories.map((c) => c.name).toList(),
                selectedTab: selectedCategory.name,
                onTabChanged: (newName) {
                  final category = _categories.firstWhere((c) => c.name == newName);
                  _onCategoryChanged(category.id);
                },
              ),
            ),
          ],
          // 二级分类 - 类型
          if (selectedCategory.subCategories != null && 
              selectedCategory.subCategories!.isNotEmpty) ...[
            const SizedBox(height: 16),
            Text(
              '类型',
              style: FontUtils.poppins(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: Theme.of(context).textTheme.bodyMedium?.color,
              ),
            ),
            const SizedBox(height: 8),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: CapsuleTabSwitcher(
                tabs: selectedCategory.subCategories!.map((s) => s.name).toList(),
                selectedTab: _selectedSubCategoryName,
                onTabChanged: _onSubCategoryChanged,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildSearchBar(ThemeService themeService) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: TextField(
        controller: _searchController,
        onSubmitted: _onSearchSubmitted,
        style: TextStyle(
          color: themeService.isDarkMode ? Colors.white : Colors.black87,
        ),
        decoration: InputDecoration(
          hintText: '搜索短剧...',
          hintStyle: TextStyle(
            color: themeService.isDarkMode ? Colors.white54 : Colors.black38,
          ),
          filled: true,
          fillColor: themeService.isDarkMode
              ? Colors.white.withOpacity(0.1)
              : Colors.grey[200],
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          suffixIcon: IconButton(
            icon: Icon(
              Icons.search,
              color: themeService.isDarkMode ? Colors.white54 : Colors.black38,
            ),
            onPressed: () => _onSearchSubmitted(_searchController.text),
          ),
        ),
      ),
    );
  }

  Widget _buildDramaGrid(ThemeService themeService) {
    if (_isLoading && _dramaList.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(32.0),
          child: PulsingDotsIndicator(),
        ),
      );
    }

    if (_errorMessage != null && _dramaList.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32.0),
          child: Column(
            children: [
              Icon(Icons.error_outline, size: 48, color: Colors.grey[400]),
              const SizedBox(height: 16),
              Text(
                _errorMessage!,
                style: TextStyle(color: Colors.grey[600]),
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: _refreshData,
                child: const Text('重试'),
              ),
            ],
          ),
        ),
      );
    }

    if (_dramaList.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32.0),
          child: Column(
            children: [
              Icon(Icons.movie_outlined, size: 48, color: Colors.grey[400]),
              const SizedBox(height: 16),
              Text(
                '暂无短剧数据',
                style: TextStyle(color: Colors.grey[600]),
              ),
            ],
          ),
        ),
      );
    }

    // 使用统一的设备工具类计算网格列数
    final int crossAxisCount = DeviceUtils.getTabletColumnCount(context);
    final bool isTablet = DeviceUtils.isTablet(context);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: crossAxisCount,
          childAspectRatio: isTablet ? 0.5 : 0.55,
          crossAxisSpacing: 12,
          mainAxisSpacing: isTablet ? 0 : 16,
        ),
        itemCount: _dramaList.length,
        itemBuilder: (context, index) {
          final item = _dramaList[index];
          return _buildDramaCard(item, themeService);
        },
      ),
    );
  }

  Widget _buildDramaCard(ShortDramaItem item, ThemeService themeService) {
    return GestureDetector(
      onTap: () => _onVideoTap(item),
      onSecondaryTap: () {
        // 显示菜单
        final videoInfo = VideoInfo(
          id: item.id,
          title: item.title,
          cover: item.poster,
          year: item.year ?? '',
          source: 'shortdrama',
          sourceName: '短剧',
          index: 0,
          totalEpisodes: item.episodes ?? 0,
          playTime: 0,
          totalTime: 0,
          saveTime: 0,
          searchTitle: item.title,
        );
        VideoMenuBottomSheet.show(
          context,
          videoInfo: videoInfo,
          isFavorited: false,
          onActionSelected: (action) => _handleMenuAction(videoInfo, action),
        );
      },
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 封面图
          AspectRatio(
            aspectRatio: 0.7,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  // 使用 CachedNetworkImage 进行图片缓存和加载优化
                  if (item.poster.isNotEmpty)
                    _ShortDramaImage(
                      imageUrl: item.poster,
                      isDarkMode: themeService.isDarkMode,
                    )
                  else
                    Container(
                      color: themeService.isDarkMode
                          ? Colors.grey[800]
                          : Colors.grey[300],
                      child: Icon(
                        Icons.movie,
                        size: 40,
                        color: themeService.isDarkMode
                            ? Colors.grey[600]
                            : Colors.grey[500],
                      ),
                    ),
                  // 集数标签 - 右上角显示数字（类似豆瓣评分样式）
                  if (item.episodes != null && item.episodes! > 0)
                    Positioned(
                      top: 4,
                      right: 4,
                      child: Container(
                        width: 26,
                        height: 26,
                        decoration: const BoxDecoration(
                          color: Color(0xFFE91E63),
                          shape: BoxShape.circle,
                        ),
                        child: Center(
                          child: Text(
                            '${item.episodes}',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 8),
          // 标题
          Text(
            item.title,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: themeService.isDarkMode ? Colors.white : Colors.black87,
            ),
          ),
          // 年份/备注
          if (item.year != null || item.remarks != null)
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Text(
                item.remarks ?? item.year ?? '',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 11,
                  color: themeService.isDarkMode ? Colors.white54 : Colors.black45,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildEndOfListIndicator(ThemeService themeService) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      child: Column(
        children: [
          Container(
            width: 60,
            height: 2,
            decoration: BoxDecoration(
              color: themeService.isDarkMode
                  ? Colors.white.withOpacity(0.3)
                  : Colors.grey.withOpacity(0.4),
              borderRadius: BorderRadius.circular(1),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            '已经到底啦~',
            style: FontUtils.poppins(
              fontSize: 14,
              color: themeService.isDarkMode
                  ? Colors.white.withOpacity(0.6)
                  : Colors.grey[600],
              fontWeight: FontWeight.w400,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '共 ${_dramaList.length} 部短剧',
            style: FontUtils.poppins(
              fontSize: 12,
              color: themeService.isDarkMode
                  ? Colors.white.withOpacity(0.4)
                  : Colors.grey[500],
              fontWeight: FontWeight.w300,
            ),
          ),
        ],
      ),
    );
  }
}

/// 短剧卡片图片组件 - 支持加载状态和淡入效果
class _ShortDramaImage extends StatefulWidget {
  final String imageUrl;
  final bool isDarkMode;

  const _ShortDramaImage({
    required this.imageUrl,
    required this.isDarkMode,
  });

  @override
  State<_ShortDramaImage> createState() => _ShortDramaImageState();
}

class _ShortDramaImageState extends State<_ShortDramaImage> {
  bool _imageLoaded = false;

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        // 骨架屏占位符 - 图片加载前显示
        AnimatedOpacity(
          opacity: _imageLoaded ? 0.0 : 1.0,
          duration: const Duration(milliseconds: 300),
          child: Container(
            color: widget.isDarkMode ? const Color(0xFF333333) : Colors.grey[300],
            child: Center(
              child: Container(
                width: 24,
                height: 24,
                decoration: BoxDecoration(
                  color: widget.isDarkMode ? const Color(0xFF444444) : Colors.grey[400],
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
            ),
          ),
        ),
        // 实际图片 - 加载完成后淡入显示
        AnimatedOpacity(
          opacity: _imageLoaded ? 1.0 : 0.0,
          duration: const Duration(milliseconds: 300),
          child: CachedNetworkImage(
            imageUrl: widget.imageUrl,
            fit: BoxFit.cover,
            memCacheWidth: 200,
            fadeInDuration: Duration.zero,
            fadeOutDuration: Duration.zero,
            placeholder: (context, url) => const SizedBox(),
            errorWidget: (context, url, error) {
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (mounted && !_imageLoaded) {
                  setState(() {
                    _imageLoaded = true;
                  });
                }
              });
              return Container(
                color: widget.isDarkMode ? Colors.grey[800] : Colors.grey[300],
                child: Icon(
                  Icons.movie,
                  size: 32,
                  color: widget.isDarkMode ? Colors.grey[600] : Colors.grey[500],
                ),
              );
            },
            imageBuilder: (context, imageProvider) {
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (mounted && !_imageLoaded) {
                  setState(() {
                    _imageLoaded = true;
                  });
                }
              });
              return Image(
                image: imageProvider,
                fit: BoxFit.cover,
              );
            },
          ),
        ),
      ],
    );
  }
}
