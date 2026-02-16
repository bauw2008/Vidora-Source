import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:provider/provider.dart';
import 'package:vidora/services/search_service.dart';
import 'package:vidora/services/user_data_service.dart';
import '../services/theme_service.dart';
import '../services/api_service.dart';
import '../services/menu_config_service.dart';
import '../utils/device_utils.dart';
import '../utils/font_utils.dart';
import 'user_menu.dart';
import 'dart:io' show Platform;
import 'dart:async';
import 'dart:ui';


class MainLayout extends StatefulWidget {
  final Widget content;
  final int currentBottomNavIndex;
  final Function(int) onBottomNavChanged;
  final String selectedTopTab;
  final Function(String) onTopTabChanged;
  final bool isSearchMode;
  final VoidCallback? onSearchTap;
  final VoidCallback? onHomeTap;
  final TextEditingController? searchController;
  final FocusNode? searchFocusNode;
  final String? searchQuery;
  final Function(String)? onSearchQueryChanged;
  final Function(String)? onSearchSubmitted;
  final VoidCallback? onClearSearch;
  final bool showBottomNav;

  const MainLayout({
    super.key,
    required this.content,
    required this.currentBottomNavIndex,
    required this.onBottomNavChanged,
    required this.selectedTopTab,
    required this.onTopTabChanged,
    this.isSearchMode = false,
    this.onSearchTap,
    this.onHomeTap,
    this.searchController,
    this.searchFocusNode,
    this.searchQuery,
    this.onSearchQueryChanged,
    this.onSearchSubmitted,
    this.onClearSearch,
    this.showBottomNav = true,
  });

  @override
  State<MainLayout> createState() => _MainLayoutState();
}

class _MainLayoutState extends State<MainLayout> {
  bool _isSearchButtonPressed = false;
  bool _showUserMenu = false;

  // 用于跟踪底部导航栏按钮的 hover 状态
  int? _hoveredNavIndex;

  // 用于跟踪搜索按钮的 hover 状态
  bool _isSearchButtonHovered = false;

  // 用于跟踪主题切换按钮的 hover 状态
  bool _isThemeButtonHovered = false;

  // 用于跟踪用户按钮的 hover 状态
  bool _isUserButtonHovered = false;

  // 用于跟踪返回按钮的 hover 状态
  bool _isBackButtonHovered = false;

  // 用于跟踪搜索框内清除按钮的 hover 状态
  bool _isClearButtonHovered = false;

  // 用于跟踪搜索框内搜索按钮的 hover 状态
  bool _isSearchSubmitButtonHovered = false;

  // 搜索建议相关状态
  List<String> _searchSuggestions = [];
  Timer? _debounceTimer;
  final LayerLink _layerLink = LayerLink();
  OverlayEntry? _overlayEntry;

  // 菜单配置
  MenuSettings _menuSettings = MenuSettings();
  bool _isLoadingMenuConfig = true;

  @override
  void initState() {
    super.initState();
    _loadMenuConfig();
  }

  /// 加载菜单配置
  Future<void> _loadMenuConfig() async {
    final settings = await MenuConfigService.getMenuSettings();
    if (mounted) {
      setState(() {
        _menuSettings = settings;
        _isLoadingMenuConfig = false;
      });
    }
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _removeOverlay();
    super.dispose();
  }

  void _removeOverlay() {
    _overlayEntry?.remove();
    _overlayEntry = null;
  }

  void _fetchSearchSuggestions(String query) async {
    if (query.trim().isEmpty) {
      if (mounted) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            setState(() {
              _searchSuggestions = [];
            });
            _removeOverlay();
          }
        });
      }
      return;
    }

    final currentQuery = query;
    final isLocalMode = await UserDataService.getIsLocalMode();
    final isLocalSearch = await UserDataService.getLocalSearch();

    List<String> suggestionResults;
    if (isLocalMode || isLocalSearch) {
      suggestionResults = await SearchService.searchRecommand(query.trim());
    } else {
      suggestionResults = await ApiService.getSearchSuggestions(query.trim());
    }

    // 检查搜索框内容是否已变化
    if (!mounted ||
        widget.searchQuery != currentQuery ||
        suggestionResults.isEmpty) {
      return;
    }

    // 使用 post-frame callback 确保在正确的时机更新状态
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || widget.searchQuery != currentQuery) {
        return;
      }

      if (suggestionResults.isNotEmpty) {
        setState(() {
          _searchSuggestions = suggestionResults.take(8).toList();
        });
        // 再次使用 post-frame callback 显示 overlay
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted && _searchSuggestions.isNotEmpty) {
            _showSuggestionsOverlay();
          }
        });
      } else {
        setState(() {
          _searchSuggestions = [];
        });
        _removeOverlay();
      }
    });
  }

  void _onSearchQueryChanged(String query) {
    // 使用 post-frame callback 来调用父组件回调，避免在 build 期间触发 setState
    WidgetsBinding.instance.addPostFrameCallback((_) {
      widget.onSearchQueryChanged?.call(query);
    });

    // 取消之前的防抖计时器
    _debounceTimer?.cancel();

    if (query.trim().isEmpty) {
      // 使用 post-frame callback 来清除建议
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          setState(() {
            _searchSuggestions = [];
          });
          _removeOverlay();
        }
      });
      return;
    }

    // 设置新的防抖计时器（500ms）
    _debounceTimer = Timer(const Duration(milliseconds: 500), () {
      if (mounted && query == widget.searchQuery) {
        _fetchSearchSuggestions(query);
      }
    });
  }

  void _showSuggestionsOverlay() {
    _removeOverlay();

    if (_searchSuggestions.isEmpty) {
      return;
    }

    final themeService = Provider.of<ThemeService>(context, listen: false);
    final isTablet = DeviceUtils.isTablet(context);

    // 计算建议框宽度
    // 平板模式：屏幕宽度的 50%
    // 移动端：屏幕宽度 - 左右padding(32) - 右侧按钮宽度(32*2) - 按钮间距(12) - 按钮与搜索框间距(16)
    final screenWidth = MediaQuery.of(context).size.width;
    final suggestionWidth =
        isTablet ? screenWidth * 0.5 : screenWidth - 32 - 16 - 32 - 12 - 32;

    _overlayEntry = OverlayEntry(
      builder: (context) => Positioned(
        width: suggestionWidth,
        child: CompositedTransformFollower(
          link: _layerLink,
          showWhenUnlinked: false,
          offset: const Offset(0, 42), // 紧贴搜索框
          child: Material(
            elevation: 8,
            borderRadius: BorderRadius.circular(12),
            color: themeService.isDarkMode
                ? const Color(0xFF1e1e1e)
                : Colors.white,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 320),
              child: ListView.builder(
                padding: const EdgeInsets.symmetric(vertical: 4),
                shrinkWrap: true,
                itemCount: _searchSuggestions.length,
                itemBuilder: (context, index) {
                  final suggestion = _searchSuggestions[index];
                  return InkWell(
                    onTap: () {
                      widget.searchController?.text = suggestion;
                      widget.onSearchSubmitted?.call(suggestion);
                      _removeOverlay();
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            LucideIcons.search,
                            size: 16,
                            color: themeService.isDarkMode
                                ? const Color(0xFF666666)
                                : const Color(0xFF95a5a6),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              suggestion,
                              style: FontUtils.poppins(
                                fontSize: 14,
                                color: themeService.isDarkMode
                                    ? const Color(0xFFffffff)
                                    : const Color(0xFF2c3e50),
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );

    Overlay.of(context).insert(_overlayEntry!);
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<ThemeService>(
      builder: (context, themeService, child) {
        return Theme(
          data: themeService.isDarkMode
              ? themeService.darkTheme
              : themeService.lightTheme,
          child: Scaffold(
            resizeToAvoidBottomInset: !widget.isSearchMode,
            body: Stack(
              children: [
                // 主要内容区域
                Column(
                  children: [
                    // 主内容区域（包含header和content）
                    Expanded(
                      child: Container(
                        decoration: BoxDecoration(
                          color: themeService.isDarkMode
                              ? const Color(0xFF000000) // 深色模式纯黑色
                              : null,
                          gradient: themeService.isDarkMode
                              ? null
                              : const LinearGradient(
                                  begin: Alignment.topCenter,
                                  end: Alignment.bottomCenter,
                                  colors: [
                                    Color(0xFFe6f3fb), // 浅色模式渐变
                                    Color(0xFFeaf3f7),
                                    Color(0xFFf7f7f3),
                                    Color(0xFFe9ecef),
                                    Color(0xFFdbe3ea),
                                    Color(0xFFd3dde6),
                                  ],
                                  stops: [0.0, 0.18, 0.38, 0.60, 0.80, 1.0],
                                ),
                        ),
                        child: Column(
                          children: [
                            // 固定 Header
                            _buildHeader(context, themeService),
                            // 主要内容区域
                            Expanded(
                              child: widget.content,
                            ),
                          ],
                        ),
                      ),
                    ),
                    // 底部导航栏已移除，改为顶部汉堡菜单
                  ],
                ),
                // 点击外部关闭汉堡菜单
                if (_isMenuOpen)
                  GestureDetector(
                    onTap: () {
                      setState(() {
                        _isMenuOpen = false;
                      });
                    },
                    child: Container(
                      color: Colors.transparent,
                      width: double.infinity,
                      height: double.infinity,
                    ),
                  ),
                // 用户菜单覆盖层 - 现在会覆盖整个屏幕包括navbar
                if (_showUserMenu)
                  UserMenu(
                    isDarkMode: themeService.isDarkMode,
                    onClose: () {
                      setState(() {
                        _showUserMenu = false;
                      });
                    },
                  ),
                // 汉堡菜单面板 - 与 UserMenu 同级，确保层级正确
                if (_isMenuOpen) _buildHamburgerMenuOverlay(themeService),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildHeader(BuildContext context, ThemeService themeService) {
    final isTablet = DeviceUtils.isTablet(context);

    // 顶部 padding
    final topPadding = MediaQuery.of(context).padding.top + 8;

    return Container(
      padding: EdgeInsets.only(
        top: topPadding,
        left: 16,
        right: 16,
        bottom: 8,
      ),
      decoration: BoxDecoration(
        color: widget.isSearchMode
            ? themeService.isDarkMode
                ? const Color(0xFF121212)
                : const Color(0xFFf5f5f5)
            : themeService.isDarkMode
                ? const Color(0xFF1e1e1e).withOpacity(0.9)
                : Colors.white.withOpacity(0.8),
      ),
      child: widget.isSearchMode
          ? _buildSearchHeader(context, themeService, isTablet)
          : _buildNormalHeader(context, themeService),
    );
  }

  Widget _buildNormalHeader(BuildContext context, ThemeService themeService) {
    return SizedBox(
      height: 40, // 固定高度，与搜索框高度一致
      child: Row(
        children: [
          // 左侧站名
          GestureDetector(
            onTap: widget.onHomeTap,
            behavior: HitTestBehavior.opaque,
            child: Text(
              'Vidora',
              style: FontUtils.sourceCodePro(
                fontSize: 24,
                fontWeight: FontWeight.w400,
                color: themeService.isDarkMode
                    ? Colors.white
                    : const Color(0xFF2c3e50),
                letterSpacing: 1.5,
              ),
            ),
          ),
          const Spacer(),
          // 右侧按钮组：搜索、主题切换、头像、汉堡菜单
          _buildRightButtonsWithMenu(themeService),
        ],
      ),
    );
  }
  
  Widget _buildSearchHeader(
      BuildContext context, ThemeService themeService, bool isTablet) {
    final searchBoxWidget = CompositedTransformTarget(
      link: _layerLink,
      child: Container(
        decoration: BoxDecoration(
          color:
              themeService.isDarkMode ? const Color(0xFF1e1e1e) : Colors.white,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Focus(
          onFocusChange: (hasFocus) {
            if (!hasFocus) {
              // 失焦时关闭建议框
              _removeOverlay();
            }
          },
          child: TextField(
            controller: widget.searchController,
            focusNode: widget.searchFocusNode,
            autofocus: false,
            textInputAction: TextInputAction.search,
            keyboardType: TextInputType.text,
            textAlignVertical: TextAlignVertical.center,
            decoration: InputDecoration(
              hintText: '搜索电影、剧集、动漫...',
              hintStyle: FontUtils.poppins(
                color: themeService.isDarkMode
                    ? const Color(0xFF666666)
                    : const Color(0xFF95a5a6),
                fontSize: 14,
              ),
              suffixIcon: SizedBox(
                width: isTablet ? 80 : 80, // 固定宽度确保按钮位置一致
                child: Stack(
                  alignment: Alignment.centerRight,
                  children: [
                    // 搜索按钮 - 固定在右侧
                    Positioned(
                      right: isTablet ? 8 : 12,
                      child: MouseRegion(
                        cursor:
                            (widget.searchQuery?.trim().isNotEmpty ?? false) &&
                                    DeviceUtils.isPC()
                                ? SystemMouseCursors.click
                                : MouseCursor.defer,
                        onEnter: DeviceUtils.isPC() &&
                                (widget.searchQuery?.trim().isNotEmpty ?? false)
                            ? (_) {
                                setState(() {
                                  _isSearchSubmitButtonHovered = true;
                                });
                              }
                            : null,
                        onExit: DeviceUtils.isPC() &&
                                (widget.searchQuery?.trim().isNotEmpty ?? false)
                            ? (_) {
                                setState(() {
                                  _isSearchSubmitButtonHovered = false;
                                });
                              }
                            : null,
                        child: GestureDetector(
                          onTap:
                              (widget.searchQuery?.trim().isNotEmpty ?? false)
                                  ? () {
                                      _removeOverlay();
                                      widget.onSearchSubmitted
                                          ?.call(widget.searchQuery!);
                                    }
                                  : null,
                          behavior: HitTestBehavior.opaque,
                          child: Container(
                            padding: EdgeInsets.all(isTablet ? 6 : 8),
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: DeviceUtils.isPC() &&
                                      _isSearchSubmitButtonHovered &&
                                      (widget.searchQuery?.trim().isNotEmpty ??
                                          false)
                                  ? (themeService.isDarkMode
                                      ? const Color(0xFF333333)
                                      : const Color(0xFFe0e0e0))
                                  : Colors.transparent,
                            ),
                            child: Icon(
                              LucideIcons.search,
                              color: (widget.searchQuery?.trim().isNotEmpty ??
                                      false)
                                  ? const Color(0xFF27ae60)
                                  : themeService.isDarkMode
                                      ? const Color(0xFFb0b0b0)
                                      : const Color(0xFF7f8c8d),
                              size: isTablet ? 18 : 16,
                            ),
                          ),
                        ),
                      ),
                    ),
                    // 清除按钮 - 在搜索按钮左侧（仅在有内容时显示）
                    Positioned(
                      right: isTablet ? 42 : 44,
                      child: Visibility(
                        visible: widget.searchQuery?.isNotEmpty ?? false,
                        maintainSize: true,
                        maintainAnimation: true,
                        maintainState: true,
                        child: MouseRegion(
                          cursor: DeviceUtils.isPC()
                              ? SystemMouseCursors.click
                              : MouseCursor.defer,
                          onEnter: DeviceUtils.isPC()
                              ? (_) {
                                  setState(() {
                                    _isClearButtonHovered = true;
                                  });
                                }
                              : null,
                          onExit: DeviceUtils.isPC()
                              ? (_) {
                                  setState(() {
                                    _isClearButtonHovered = false;
                                  });
                                }
                              : null,
                          child: GestureDetector(
                            onTap: () {
                              _removeOverlay();
                              widget.onClearSearch?.call();
                            },
                            behavior: HitTestBehavior.opaque,
                            child: Container(
                              padding: EdgeInsets.all(isTablet ? 6 : 8),
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color:
                                    DeviceUtils.isPC() && _isClearButtonHovered
                                        ? (themeService.isDarkMode
                                            ? const Color(0xFF333333)
                                            : const Color(0xFFe0e0e0))
                                        : Colors.transparent,
                              ),
                              child: Icon(
                                LucideIcons.x,
                                color: themeService.isDarkMode
                                    ? const Color(0xFFb0b0b0)
                                    : const Color(0xFF7f8c8d),
                                size: isTablet ? 18 : 16,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 6,
              ),
              isDense: true,
            ),
            style: FontUtils.poppins(
              fontSize: 14,
              color: themeService.isDarkMode
                  ? const Color(0xFFffffff)
                  : const Color(0xFF2c3e50),
              height: 1.2,
            ),
            onSubmitted: (value) {
              _removeOverlay();
              widget.onSearchSubmitted?.call(value);
            },
            onChanged: _onSearchQueryChanged,
            onTap: () {
              // 聚焦时如果有内容，显示建议
              if (widget.searchQuery?.trim().isNotEmpty ?? false) {
                _fetchSearchSuggestions(widget.searchQuery!);
              }
            },
          ),
        ),
      ),
    );

    // 平板模式下居中
    if (isTablet) {
      return SizedBox(
        height: 40, // 固定高度
        child: Stack(
          alignment: Alignment.center,
          children: [
            // 左侧返回按钮
            Positioned(
              left: 0,
              child: MouseRegion(
                cursor: DeviceUtils.isPC()
                    ? SystemMouseCursors.click
                    : MouseCursor.defer,
                onEnter: DeviceUtils.isPC()
                    ? (_) {
                        setState(() {
                          _isBackButtonHovered = true;
                        });
                      }
                    : null,
                onExit: DeviceUtils.isPC()
                    ? (_) {
                        setState(() {
                          _isBackButtonHovered = false;
                        });
                      }
                    : null,
                child: GestureDetector(
                  onTap: () {
                    Navigator.pop(context);
                  },
                  behavior: HitTestBehavior.opaque,
                  child: Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: DeviceUtils.isPC() && _isBackButtonHovered
                          ? (themeService.isDarkMode
                              ? const Color(0xFF333333)
                              : const Color(0xFFe0e0e0))
                          : Colors.transparent,
                    ),
                    child: Center(
                      child: Icon(
                        LucideIcons.arrowLeft,
                        color: themeService.isDarkMode
                            ? const Color(0xFFffffff)
                            : const Color(0xFF2c3e50),
                        size: 24,
                        weight: 1.0,
                      ),
                    ),
                  ),
                ),
              ),
            ),
            // 搜索框在整个屏幕水平居中
            Center(
              child: SizedBox(
                width: MediaQuery.of(context).size.width * 0.5,
                child: searchBoxWidget,
              ),
            ),
            // 右侧按钮 - 垂直居中
            Positioned(
              right: 0,
              child: _buildRightButtons(themeService),
            ),
          ],
        ),
      );
    }

    // 非平板模式下，搜索框居左，右侧留出按钮空间
    return SizedBox(
      height: 40, // 固定高度
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(child: searchBoxWidget),
          const SizedBox(width: 16),
          _buildRightButtons(themeService),
        ],
      ),
    );
  }

  Widget _buildRightButtons(ThemeService themeService) {
    return _buildRightButtonsWithMenu(themeService);
  }

  // 汉堡菜单状态
  bool _isMenuOpen = false;

  Widget _buildRightButtonsWithMenu(ThemeService themeService) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        // 搜索按钮
        MouseRegion(
          cursor:
              DeviceUtils.isPC() ? SystemMouseCursors.click : MouseCursor.defer,
          onEnter: DeviceUtils.isPC()
              ? (_) {
                  setState(() {
                    _isSearchButtonHovered = true;
                  });
                }
              : null,
          onExit: DeviceUtils.isPC()
              ? (_) {
                  setState(() {
                    _isSearchButtonHovered = false;
                  });
                }
              : null,
          child: GestureDetector(
            onTap: () {
              if (_isSearchButtonPressed) return;
              setState(() {
                _isSearchButtonPressed = true;
              });
              widget.onSearchTap?.call();
              Future.delayed(const Duration(milliseconds: 300), () {
                if (mounted) {
                  setState(() {
                    _isSearchButtonPressed = false;
                  });
                }
              });
            },
            behavior: HitTestBehavior.opaque,
            child: Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: DeviceUtils.isPC() && _isSearchButtonHovered
                    ? (themeService.isDarkMode
                        ? const Color(0xFF333333)
                        : const Color(0xFFe0e0e0))
                    : Colors.transparent,
              ),
              child: Center(
                child: Icon(
                  LucideIcons.search,
                  color: themeService.isDarkMode
                      ? const Color(0xFFffffff)
                      : const Color(0xFF2c3e50),
                  size: 22,
                  weight: 1.0,
                ),
              ),
            ),
          ),
        ),
        const SizedBox(width: 8),
        // 主题切换按钮
        MouseRegion(
          cursor:
              DeviceUtils.isPC() ? SystemMouseCursors.click : MouseCursor.defer,
          onEnter: DeviceUtils.isPC()
              ? (_) {
                  setState(() {
                    _isThemeButtonHovered = true;
                  });
                }
              : null,
          onExit: DeviceUtils.isPC()
              ? (_) {
                  setState(() {
                    _isThemeButtonHovered = false;
                  });
                }
              : null,
          child: GestureDetector(
            onTap: () {
              themeService.toggleTheme(context);
            },
            behavior: HitTestBehavior.opaque,
            child: Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: DeviceUtils.isPC() && _isThemeButtonHovered
                    ? (themeService.isDarkMode
                        ? const Color(0xFF333333)
                        : const Color(0xFFe0e0e0))
                    : Colors.transparent,
              ),
              child: Center(
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 300),
                  transitionBuilder:
                      (Widget child, Animation<double> animation) {
                    return ScaleTransition(
                      scale: animation,
                      child: child,
                    );
                  },
                  child: Icon(
                    themeService.isDarkMode
                        ? LucideIcons.sun
                        : LucideIcons.moon,
                    key: ValueKey(themeService.isDarkMode),
                    color: themeService.isDarkMode
                        ? const Color(0xFFffffff)
                        : const Color(0xFF2c3e50),
                    size: 22,
                    weight: 1.0,
                  ),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(width: 8),
        // 用户头像按钮
        MouseRegion(
          cursor:
              DeviceUtils.isPC() ? SystemMouseCursors.click : MouseCursor.defer,
          onEnter: DeviceUtils.isPC()
              ? (_) {
                  setState(() {
                    _isUserButtonHovered = true;
                  });
                }
              : null,
          onExit: DeviceUtils.isPC()
              ? (_) {
                  setState(() {
                    _isUserButtonHovered = false;
                  });
                }
              : null,
          child: GestureDetector(
            onTap: () {
              setState(() {
                _showUserMenu = true;
              });
            },
            behavior: HitTestBehavior.opaque,
            child: Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: DeviceUtils.isPC() && _isUserButtonHovered
                    ? (themeService.isDarkMode
                        ? const Color(0xFF333333)
                        : const Color(0xFFe0e0e0))
                    : Colors.transparent,
              ),
              child: Center(
                child: Icon(
                  LucideIcons.user,
                  color: themeService.isDarkMode
                      ? const Color(0xFFffffff)
                      : const Color(0xFF2c3e50),
                  size: 22,
                  weight: 1.0,
                ),
              ),
            ),
          ),
        ),
        const SizedBox(width: 8),
        // 汉堡菜单按钮
        _buildHamburgerMenu(themeService),
      ],
    );
  }

  Widget _buildHamburgerMenu(ThemeService themeService) {
    // 汉堡菜单按钮 - 始终显示菜单图标，不变X
    return MouseRegion(
      cursor: DeviceUtils.isPC() ? SystemMouseCursors.click : MouseCursor.defer,
      child: GestureDetector(
        onTap: () {
          setState(() {
            _isMenuOpen = !_isMenuOpen;
          });
        },
        behavior: HitTestBehavior.opaque,
        child: Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: _isMenuOpen
                ? (themeService.isDarkMode
                    ? const Color(0xFF333333)
                    : const Color(0xFFe0e0e0))
                : Colors.transparent,
          ),
          child: Center(
            child: Icon(
              LucideIcons.menu,
              color: themeService.isDarkMode
                  ? const Color(0xFFffffff)
                  : const Color(0xFF2c3e50),
              size: 22,
              weight: 1.0,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHamburgerMenuOverlay(ThemeService themeService) {
    // 计算每个菜单项的实际索引（根据显示顺序）
    int currentMenuIndex = 1; // 首页是 0
    
    // 导航菜单项 - 根据配置动态生成
    final List<Map<String, dynamic>> menuItems = [
      {'icon': LucideIcons.house, 'label': '首页', 'index': 0, 'key': 'home'},
    ];
    
    if (_menuSettings.showMovies) {
      menuItems.add({
        'icon': LucideIcons.video, 
        'label': '电影', 
        'index': currentMenuIndex, 
        'key': 'showMovies'
      });
      currentMenuIndex++;
    }
    if (_menuSettings.showTVShows) {
      menuItems.add({
        'icon': LucideIcons.tv, 
        'label': '剧集', 
        'index': currentMenuIndex, 
        'key': 'showTVShows'
      });
      currentMenuIndex++;
    }
    if (_menuSettings.showAnime) {
      menuItems.add({
        'icon': LucideIcons.cat, 
        'label': '动漫', 
        'index': currentMenuIndex, 
        'key': 'showAnime'
      });
      currentMenuIndex++;
    }
    if (_menuSettings.showVariety) {
      menuItems.add({
        'icon': LucideIcons.clover, 
        'label': '综艺', 
        'index': currentMenuIndex, 
        'key': 'showVariety'
      });
      currentMenuIndex++;
    }
    if (_menuSettings.showShortDrama) {
      menuItems.add({
        'icon': LucideIcons.clapperboard, 
        'label': '短剧', 
        'index': currentMenuIndex, 
        'key': 'showShortDrama'
      });
      currentMenuIndex++;
    }
    if (_menuSettings.showLive) {
      menuItems.add({
        'icon': LucideIcons.radio, 
        'label': '直播', 
        'index': currentMenuIndex, 
        'key': 'showLive'
      });
      currentMenuIndex++;
    }

    // 菜单弹窗 - Vidora 风格
    return Positioned(
      top: 40,
      right: 16,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
          child: Container(
            width: 180,
            decoration: BoxDecoration(
              color: themeService.isDarkMode
                  ? const Color(0xFF1a1a1a).withValues(alpha: 0.9)
                  : Colors.white.withValues(alpha: 0.9),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: themeService.isDarkMode
                    ? Colors.white.withValues(alpha: 0.1)
                    : Colors.black.withValues(alpha: 0.1),
                width: 1,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.2),
                  blurRadius: 20,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: menuItems.asMap().entries.map((entry) {
                final index = entry.key;
                final item = entry.value;
                final isSelected = widget.currentBottomNavIndex == item['index'];
                // 彩色图标映射
                final iconColors = <String, Color>{
                  'home': const Color(0xFF8b5cf6),      // 紫色
                  'showMovies': const Color(0xFFef4444), // 红色
                  'showTVShows': const Color(0xFF3b82f6), // 蓝色
                  'showAnime': const Color(0xFF6366f1),   // 靛蓝
                  'showVariety': const Color(0xFFf97316), // 橙色
                  'showShortDrama': const Color(0xFFec4899), // 粉色
                  'showLive': const Color(0xFF22c55e),   // 绿色
                };
                final iconColor = iconColors[item['key']] ?? const Color(0xFF6b7280);
                
                return TweenAnimationBuilder<double>(
                  key: ValueKey(item['key']),
                  tween: Tween(begin: 0.0, end: 1.0),
                  duration: Duration(milliseconds: 200 + (index * 30)),
                  curve: Curves.easeOutCubic,
                  builder: (context, value, child) {
                    return Transform.translate(
                      offset: Offset(20 * (1 - value), 0),
                      child: Opacity(
                        opacity: value,
                        child: child,
                      ),
                    );
                  },
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: () {
                        setState(() {
                          _isMenuOpen = false;
                        });
                        widget.onBottomNavChanged(item['index']);
                      },
                      borderRadius: BorderRadius.circular(12),
                      child: Container(
                        margin: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 10,
                        ),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? iconColor.withValues(alpha: 0.15)
                              : Colors.transparent,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          children: [
                            // 图标容器
                            Container(
                              width: 28,
                              height: 28,
                              decoration: BoxDecoration(
                                color: isSelected
                                    ? iconColor.withValues(alpha: 0.2)
                                    : (themeService.isDarkMode
                                        ? const Color(0xFF333333)
                                        : const Color(0xFFf3f4f6)),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Icon(
                                item['icon'],
                                size: 16,
                                color: isSelected
                                    ? iconColor
                                    : iconColor.withValues(alpha: 0.8),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Text(
                              item['label'],
                              style: FontUtils.poppins(
                                fontSize: 14,
                                fontWeight: isSelected
                                    ? FontWeight.w600
                                    : FontWeight.w400,
                                color: isSelected
                                    ? iconColor
                                    : (themeService.isDarkMode
                                        ? const Color(0xFFffffff)
                                        : const Color(0xFF2c3e50)),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
        ),
      ),
    );
  }

  // 底部导航栏已移除，使用顶部汉堡菜单代替
}
