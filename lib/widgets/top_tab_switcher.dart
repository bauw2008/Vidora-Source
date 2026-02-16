import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/theme_service.dart';
import '../utils/device_utils.dart';
import '../utils/font_utils.dart';

class TopTabSwitcher extends StatefulWidget {
  final String selectedTab;
  final Function(String) onTabChanged;

  const TopTabSwitcher({
    super.key,
    required this.selectedTab,
    required this.onTabChanged,
  });

  @override
  State<TopTabSwitcher> createState() => _TopTabSwitcherState();
}

class _TopTabSwitcherState extends State<TopTabSwitcher> {
  // 用于跟踪鼠标悬停状态
  bool _isHoveringHome = false;
  bool _isHoveringHistory = false;
  bool _isHoveringFavorites = false;

  // 内部跟踪当前选中的标签，用于动画
  String _currentTab = '首页';

  @override
  void initState() {
    super.initState();
    _currentTab = widget.selectedTab;
  }

  @override
  void didUpdateWidget(covariant TopTabSwitcher oldWidget) {
    super.didUpdateWidget(oldWidget);
    // 当 selectedTab 变化时，更新内部状态并触发重建
    if (oldWidget.selectedTab != widget.selectedTab) {
      _currentTab = widget.selectedTab;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<ThemeService>(
      builder: (context, themeService, child) {
        // 直接根据 selectedTab 计算胶囊位置
        final capsuleLeft = _getCapsuleLeft(_currentTab);

        return Center(
          child: Container(
            margin: const EdgeInsets.only(top: 20, bottom: 8),
            width: 240,
            height: 32,
            decoration: BoxDecoration(
              color: themeService.isDarkMode
                  ? const Color(0xFF333333)
                  : const Color(0xFFe0e0e0),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Stack(
              children: [
                // 动画背景胶囊 - 使用 AnimatedPositioned
                AnimatedPositioned(
                  duration: const Duration(milliseconds: 250),
                  curve: Curves.easeOut,
                  left: capsuleLeft,
                  top: 0,
                  child: Container(
                    width: 80,
                    height: 32,
                    decoration: BoxDecoration(
                      color: themeService.isDarkMode
                          ? const Color(0xFF1e1e1e)
                          : Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: themeService.isDarkMode
                              ? Colors.black.withValues(alpha: 0.3)
                              : Colors.black.withValues(alpha: 0.1),
                          blurRadius: 3,
                          offset: const Offset(0, 1),
                        ),
                      ],
                    ),
                  ),
                ),
                // 标签按钮
                Row(
                  children: [
                    Expanded(
                      child: _buildTabButton('首页', themeService),
                    ),
                    Expanded(
                      child: _buildTabButton('播放历史', themeService),
                    ),
                    Expanded(
                      child: _buildTabButton('收藏夹', themeService),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  double _getCapsuleLeft(String tab) {
    switch (tab) {
      case '首页':
        return 0.0;
      case '播放历史':
        return 80.0;
      case '收藏夹':
        return 160.0;
      default:
        return 0.0;
    }
  }

  Widget _buildTabButton(String label, ThemeService themeService) {
    final bool isPC = DeviceUtils.isPC();
    final bool isSelected = _currentTab == label;
    final bool isHovering = label == '首页'
        ? _isHoveringHome
        : label == '播放历史'
            ? _isHoveringHistory
            : _isHoveringFavorites;

    return GestureDetector(
      onTap: () {
        widget.onTabChanged(label);
      },
      behavior: HitTestBehavior.opaque,
      child: MouseRegion(
        cursor: isPC ? SystemMouseCursors.click : MouseCursor.defer,
        onEnter: isPC
            ? (_) {
                setState(() {
                  if (label == '首页') {
                    _isHoveringHome = true;
                  } else if (label == '播放历史') {
                    _isHoveringHistory = true;
                  } else {
                    _isHoveringFavorites = true;
                  }
                });
              }
            : null,
        onExit: isPC
            ? (_) {
                setState(() {
                  if (label == '首页') {
                    _isHoveringHome = false;
                  } else if (label == '播放历史') {
                    _isHoveringHistory = false;
                  } else {
                    _isHoveringFavorites = false;
                  }
                });
              }
            : null,
        child: Container(
          height: 32,
          alignment: Alignment.center,
          child: Text(
            label,
            style: FontUtils.poppins(
              fontSize: 11,
              fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
              color: (isPC && isHovering)
                  ? const Color(0xFF27AE60)
                  : isSelected
                      ? (themeService.isDarkMode
                          ? const Color(0xFFffffff)
                          : const Color(0xFF2c3e50))
                      : (themeService.isDarkMode
                          ? const Color(0xFFb0b0b0)
                          : const Color(0xFF7f8c8d)),
            ),
          ),
        ),
      ),
    );
  }
}