import 'dart:convert';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/api_service.dart';
import '../services/theme_service.dart';
import '../utils/font_utils.dart';
import 'package:provider/provider.dart';

/// 用户头像组件（仅展示）
/// 支持自定义头像、默认头像生成、本地缓存
class UserAvatar extends StatefulWidget {
  final double size;
  final String? username;
  final bool showBorder;

  const UserAvatar({
    super.key,
    this.size = 40,
    this.username,
    this.showBorder = true,
  });

  @override
  State<UserAvatar> createState() => _UserAvatarState();
}

class _UserAvatarState extends State<UserAvatar> {
  String? _avatarBase64;
  bool _isLoading = true;
  static const String _cacheKeyPrefix = 'user_avatar_cache_';
  static const Duration _cacheDuration = Duration(hours: 24);

  @override
  void initState() {
    super.initState();
    _loadAvatar();
  }

  @override
  void didUpdateWidget(UserAvatar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.username != widget.username) {
      _loadAvatar();
    }
  }

  Future<void> _loadAvatar() async {
    setState(() {
      _isLoading = true;
    });

    // 先尝试从本地缓存加载
    final cached = await _loadFromCache();
    if (cached != null) {
      if (mounted) {
        setState(() {
          _avatarBase64 = cached;
          _isLoading = false;
        });
      }
      return;
    }

    // 从服务器获取
    final response = await ApiService.getAvatar(
      username: widget.username,
    );

    if (mounted) {
      if (response.success && response.data != null && response.data!.isNotEmpty) {
        setState(() {
          _avatarBase64 = response.data;
          _isLoading = false;
        });
        // 保存到缓存
        _saveToCache(response.data!);
      } else {
        setState(() {
          _avatarBase64 = null;
          _isLoading = false;
        });
      }
    }
  }

  Future<String?> _loadFromCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final cacheKey = '$_cacheKeyPrefix${widget.username ?? 'current'}';
      final cachedJson = prefs.getString(cacheKey);
      if (cachedJson != null) {
        final cached = json.decode(cachedJson) as Map<String, dynamic>;
        final timestamp = DateTime.parse(cached['timestamp'] as String);
        if (DateTime.now().difference(timestamp) < _cacheDuration) {
          return cached['avatar'] as String;
        }
      }
    } catch (e) {
      // 缓存读取失败，忽略
    }
    return null;
  }

  Future<void> _saveToCache(String avatarBase64) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final cacheKey = '$_cacheKeyPrefix${widget.username ?? 'current'}';
      await prefs.setString(cacheKey, json.encode({
        'avatar': avatarBase64,
        'timestamp': DateTime.now().toIso8601String(),
      }));
    } catch (e) {
      // 缓存保存失败，忽略
    }
  }

  /// 清除头像缓存
  static Future<void> clearCache({String? username}) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (username != null) {
        await prefs.remove('$_cacheKeyPrefix$username');
      } else {
        // 清除所有头像缓存
        final keys = prefs.getKeys();
        for (final key in keys) {
          if (key.startsWith(_cacheKeyPrefix)) {
            await prefs.remove(key);
          }
        }
      }
    } catch (e) {
      // 忽略
    }
  }

  /// 生成基于用户名的默认头像颜色
  static List<Color> _generateGradientColors(String? username) {
    if (username == null || username.isEmpty) {
      return [const Color(0xFF60A5FA), const Color(0xFF3B82F6)];
    }

    // 预设的渐变色组合
    final gradients = [
      [const Color(0xFFF472B6), const Color(0xFFEC4899)], // 粉色
      [const Color(0xFFA78BFA), const Color(0xFF8B5CF6)], // 紫色
      [const Color(0xFF60A5FA), const Color(0xFF3B82F6)], // 蓝色
      [const Color(0xFF4ADE80), const Color(0xFF22C55E)], // 绿色
      [const Color(0xFFFBBF24), const Color(0xFFF59E0B)], // 黄色
      [const Color(0xFFFB923C), const Color(0xFFF97316)], // 橙色
      [const Color(0xFF38BDF8), const Color(0xFF0EA5E9)], // 青色
      [const Color(0xFFFB7185), const Color(0xFFE11D48)], // 红色
    ];

    // 根据用户名哈希选择颜色
    int hash = 0;
    for (int i = 0; i < username.length; i++) {
      hash = username.codeUnitAt(i) + ((hash << 5) - hash);
    }

    return gradients[hash.abs() % gradients.length];
  }

  /// 获取 DiceBear 默认头像 URL
  static String _getDiceBearUrl(String? username) {
    final seed = username ?? 'default';
    return 'https://api.dicebear.com/7.x/avataaars/svg?seed=${Uri.encodeComponent(seed)}&backgroundColor=b6e3f4,c0aede,d1d4f9,ffd5dc,ffdfbf';
  }

  @override
  Widget build(BuildContext context) {
    final themeService = Provider.of<ThemeService>(context, listen: false);
    
    return Container(
      width: widget.size,
      height: widget.size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: widget.showBorder
            ? Border.all(
                color: themeService.isDarkMode
                    ? Colors.white.withOpacity(0.2)
                    : Colors.black.withOpacity(0.1),
                width: 2,
              )
            : null,
        boxShadow: widget.showBorder
            ? [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ]
            : null,
      ),
      child: ClipOval(
        child: _buildAvatarContent(themeService),
      ),
    );
  }

  Widget _buildAvatarContent(ThemeService themeService) {
    // 加载中
    if (_isLoading) {
      return Container(
        color: themeService.isDarkMode
            ? const Color(0xFF374151)
            : const Color(0xFFE5E7EB),
        child: Center(
          child: SizedBox(
            width: widget.size * 0.5,
            height: widget.size * 0.5,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              valueColor: AlwaysStoppedAnimation<Color>(
                themeService.isDarkMode ? Colors.white54 : Colors.black45,
              ),
            ),
          ),
        ),
      );
    }

    // 有自定义头像
    if (_avatarBase64 != null && _avatarBase64!.isNotEmpty) {
      try {
        final bytes = base64Decode(_avatarBase64!);
        return Image.memory(
          bytes,
          width: widget.size,
          height: widget.size,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => _buildDefaultAvatar(themeService),
        );
      } catch (e) {
        return _buildDefaultAvatar(themeService);
      }
    }

    // 使用默认头像
    return _buildDefaultAvatar(themeService);
  }

  Widget _buildDefaultAvatar(ThemeService themeService) {
    final colors = _generateGradientColors(widget.username);
    final letter = (widget.username?.isNotEmpty ?? false)
        ? widget.username!.substring(0, 1).toUpperCase()
        : null;

    return Stack(
      children: [
        // 渐变背景
        Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: colors,
            ),
          ),
        ),
        // DiceBear 网络头像
        Positioned.fill(
          child: CachedNetworkImage(
            imageUrl: _getDiceBearUrl(widget.username),
            fit: BoxFit.cover,
            placeholder: (_, __) => const SizedBox.shrink(),
            errorWidget: (_, __, ___) => const SizedBox.shrink(),
            fadeInDuration: const Duration(milliseconds: 150),
          ),
        ),
        // 首字母作为备用
        if (letter != null)
          Center(
            child: Text(
              letter,
              style: FontUtils.poppins(
                fontSize: widget.size * 0.4,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
          ),
      ],
    );
  }
}
