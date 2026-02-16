import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:cached_network_image/cached_network_image.dart';
import 'dart:convert';
import 'dart:io' show Platform;
import 'dart:async';
import 'dart:ui';
import '../services/user_data_service.dart';
import '../services/local_mode_storage_service.dart';
import '../services/subscription_service.dart';
import '../services/api_service.dart';
import '../services/poster_service.dart';
import '../utils/device_utils.dart';
import '../utils/font_utils.dart';
import 'home_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> with TickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _urlController = TextEditingController();
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  final _subscriptionUrlController = TextEditingController();
  bool _isPasswordVisible = false;
  bool _isLoading = false;
  bool _isFormValid = false;
  bool _isLocalMode = false;

  // 点击计数器相关
  int _logoTapCount = 0;
  Timer? _tapTimer;

  // Vidora 风格新增
  String _backgroundImageUrl = '';
  bool _showLoginForm = false;
  bool _isAnimating = false;
  bool _isBackgroundLoading = true;
  late AnimationController _outerRotationController;
  late AnimationController _innerRotationController;
  late AnimationController _pulseController;
  late AnimationController _formScaleController;
  late Animation<double> _formScaleAnimation;
  late Animation<double> _formOpacityAnimation;

  @override
  void initState() {
    super.initState();
    _urlController.addListener(_validateForm);
    _usernameController.addListener(_validateForm);
    _passwordController.addListener(_validateForm);
    _subscriptionUrlController.addListener(_validateForm);
    _loadSavedUserData();
    _initAnimations();
    _loadBackgroundImage();
  }

  void _initAnimations() {
    // 外圈旋转动画
    _outerRotationController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    );

    // 内圈反向旋转动画
    _innerRotationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );

    // 脉冲动画
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );

    // 登录框缩放动画
    _formScaleController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );

    _formScaleAnimation = Tween<double>(begin: 0.9, end: 1.0).animate(
      CurvedAnimation(
        parent: _formScaleController,
        curve: Curves.easeOutCubic,
      ),
    );

    _formOpacityAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _formScaleController,
        curve: Curves.easeOut,
      ),
    );

    // 启动旋转和脉冲动画
    _outerRotationController.repeat();
    _innerRotationController.repeat(reverse: false);
    _pulseController.repeat(reverse: true);
  }

  void _loadBackgroundImage() {
    // 生成带时间戳的 URL 避免缓存
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    setState(() {
      _backgroundImageUrl = 'https://picture.bauw.dpdns.org/api/random?t=$timestamp';
    });
  }

  void _onBackgroundLoaded() {
    if (mounted) {
      setState(() {
        _isBackgroundLoading = false;
      });
      // 延迟一点显示登录框
      Future.delayed(const Duration(milliseconds: 300), () {
        if (mounted) {
          setState(() {
            _showLoginForm = true;
          });
          _formScaleController.forward();
        }
      });
    }
  }

  void _handleInteraction() {
    if (!_showLoginForm && !_isBackgroundLoading) {
      setState(() {
        _showLoginForm = true;
        _isAnimating = true;
      });
      _formScaleController.forward();
    }
  }

  void _loadSavedUserData() async {
    final userData = await UserDataService.getAllUserData();
    bool hasData = false;

    if (userData['serverUrl'] != null) {
      _urlController.text = userData['serverUrl']!;
      hasData = true;
    }
    if (userData['username'] != null) {
      _usernameController.text = userData['username']!;
      hasData = true;
    }
    if (userData['password'] != null) {
      _passwordController.text = userData['password']!;
      hasData = true;
    }

    // 加载订阅链接（用于回填）
    final subscriptionUrl = await LocalModeStorageService.getSubscriptionUrl();
    if (subscriptionUrl != null && subscriptionUrl.isNotEmpty) {
      _subscriptionUrlController.text = subscriptionUrl;
      hasData = true;
    }

    // 如果有数据被加载，更新UI状态
    if (hasData && mounted) {
      setState(() {
        // 触发表单验证
        _validateForm();
      });
    }

    // 尝试自动登录
    _tryAutoLogin();
  }

  /// 尝试自动登录
  void _tryAutoLogin() async {
    // 检查是否是本地模式
    final isLocalMode = await UserDataService.getIsLocalMode();

    if (isLocalMode) {
      // 本地模式：尝试刷新订阅内容后直接进入首页
      try {
        final subscriptionUrl = await LocalModeStorageService.getSubscriptionUrl();
        if (subscriptionUrl != null && subscriptionUrl.isNotEmpty) {
          final response = await http.get(Uri.parse(subscriptionUrl));
          if (response.statusCode == 200) {
            final content = await SubscriptionService.parseSubscriptionContent(response.body);
            if (content != null) {
              if (content.searchResources != null && content.searchResources!.isNotEmpty) {
                await LocalModeStorageService.saveSearchSources(content.searchResources!);
              }
              if (content.liveSources != null && content.liveSources!.isNotEmpty) {
                await LocalModeStorageService.saveLiveSources(content.liveSources!);
              }
            }
          }
        }
      } catch (e) {
        // 刷新失败也继续进入首页
      }

      if (mounted) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (context) => const HomeScreen()),
        );
      }
      return;
    }

    // 服务器模式：检查是否有自动登录数据
    final hasAutoLoginData = await UserDataService.hasAutoLoginData();
    if (!hasAutoLoginData) {
      return; // 没有自动登录数据，显示登录界面
    }

    // 尝试自动登录
    try {
      final loginResult = await ApiService.autoLogin();
      if (loginResult.success && mounted) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (context) => const HomeScreen()),
        );
      }
    } catch (e) {
      // 自动登录失败，显示登录界面
    }
  }

  @override
  void dispose() {
    _urlController.dispose();
    _usernameController.dispose();
    _passwordController.dispose();
    _subscriptionUrlController.dispose();
    _tapTimer?.cancel();
    _outerRotationController.dispose();
    _innerRotationController.dispose();
    _pulseController.dispose();
    _formScaleController.dispose();
    super.dispose();
  }

  void _handleLogoTap() {
    _logoTapCount++;

    // 取消之前的计时器
    _tapTimer?.cancel();

    // 如果达到10次，切换到本地模式
    if (_logoTapCount >= 10) {
      setState(() {
        _isLocalMode = !_isLocalMode;
        _validateForm();
        _logoTapCount = 0;
      });
      _showToast(
        _isLocalMode ? '已切换到本地模式' : '已切换到服务器模式',
        const Color(0xFF27ae60),
      );
    } else {
      // 设置新的计时器，2秒后重置计数
      _tapTimer = Timer(const Duration(seconds: 1), () {
        setState(() {
          _logoTapCount = 0;
        });
      });
    }
  }

  void _validateForm() {
    setState(() {
      if (_isLocalMode) {
        _isFormValid = _subscriptionUrlController.text.isNotEmpty;
      } else {
        _isFormValid = _urlController.text.isNotEmpty &&
            _usernameController.text.isNotEmpty &&
            _passwordController.text.isNotEmpty;
      }
    });
  }

  // 处理回车键提交
  void _handleSubmit() {
    if (_isLocalMode) {
      _handleLocalModeLogin();
    } else {
      _handleLogin();
    }
  }

  String _processUrl(String url) {
    // 去除尾部斜杠
    String processedUrl = url.trim();
    if (processedUrl.endsWith('/')) {
      processedUrl = processedUrl.substring(0, processedUrl.length - 1);
    }
    return processedUrl;
  }

  String _parseCookies(http.Response response) {
    // 解析 Set-Cookie 头部
    List<String> cookies = [];

    // 获取所有 Set-Cookie 头部
    final setCookieHeaders = response.headers['set-cookie'];
    if (setCookieHeaders != null) {
      // HTTP 头部通常是 String 类型
      final cookieParts = setCookieHeaders.split(';');
      if (cookieParts.isNotEmpty) {
        cookies.add(cookieParts[0].trim());
      }
    }

    return cookies.join('; ');
  }

  void _showToast(String message, Color backgroundColor) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          message,
          style: FontUtils.poppins(
            color: Colors.white,
            fontSize: 14,
          ),
        ),
        backgroundColor: backgroundColor,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
        margin: const EdgeInsets.all(16),
        duration: const Duration(seconds: 3),
      ),
    );
  }

  void _handleLogin() async {
    if (_formKey.currentState!.validate() && _isFormValid) {
      setState(() {
        _isLoading = true;
      });

      try {
        // 处理 URL
        String baseUrl = _processUrl(_urlController.text);
        String loginUrl = '$baseUrl/api/login';

        // 发送登录请求
        final response = await http.post(
          Uri.parse(loginUrl),
          headers: {
            'Content-Type': 'application/json',
          },
          body: json.encode({
            'username': _usernameController.text,
            'password': _passwordController.text,
          }),
        );

        setState(() {
          _isLoading = false;
        });

        // 根据状态码显示不同的消息
        switch (response.statusCode) {
          case 200:
            // 解析并保存 cookies
            String cookies = _parseCookies(response);

            // 保存用户数据
            await UserDataService.saveUserData(
              serverUrl: baseUrl,
              username: _usernameController.text,
              password: _passwordController.text,
              cookies: cookies,
            );

            // 保存模式状态为服务器模式
            await UserDataService.saveIsLocalMode(false);

            // 刷新海报数据（让用户每次登录看到不同的海报）
            PosterService().refresh();

            // _showToast('登录成功！', const Color(0xFF27ae60));

            // 跳转到首页，并清除所有路由栈（强制销毁所有旧页面）
            if (mounted) {
              Navigator.of(context).pushAndRemoveUntil(
                MaterialPageRoute(builder: (context) => const HomeScreen()),
                (route) => false,
              );
            }
            break;
          case 401:
            _showToast('用户名或密码错误', const Color(0xFFe74c3c));
            break;
          case 500:
            _showToast('服务器错误', const Color(0xFFe74c3c));
            break;
          default:
            _showToast('网络异常', const Color(0xFFe74c3c));
        }
      } catch (e) {
        setState(() {
          _isLoading = false;
        });
        _showToast('网络异常', const Color(0xFFe74c3c));
      }
    }
  }

  void _handleLocalModeLogin() async {
    if (_formKey.currentState!.validate()) {
      setState(() {
        _isLoading = true;
      });

      try {
        final newUrl = _subscriptionUrlController.text.trim();

        // 获取并解析订阅内容
        final response = await http.get(Uri.parse(newUrl));

        if (response.statusCode != 200) {
          setState(() {
            _isLoading = false;
          });
          _showToast('获取订阅内容失败', const Color(0xFFe74c3c));
          return;
        }

        final content =
            await SubscriptionService.parseSubscriptionContent(response.body);

        if (content == null || 
            (content.searchResources == null || content.searchResources!.isEmpty) &&
            (content.liveSources == null || content.liveSources!.isEmpty)) {
          setState(() {
            _isLoading = false;
          });
          _showToast('解析订阅内容失败', const Color(0xFFe74c3c));
          return;
        }

        // 检查是否已有订阅 URL
        final existingUrl = await LocalModeStorageService.getSubscriptionUrl();

        if (existingUrl != null &&
            existingUrl.isNotEmpty &&
            existingUrl != newUrl) {
          // 弹窗询问是否清空
          setState(() {
            _isLoading = false;
          });

          if (!mounted) return;

          final shouldClear = await showDialog<bool>(
            context: context,
            builder: (context) => AlertDialog(
              title: Text(
                '提示',
                style: FontUtils.poppins(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: const Color(0xFF2c3e50),
                ),
              ),
              content: Text(
                '检测到已有本地模式内容且订阅链接不一致，是否清空全部本地模式存储？',
                style: FontUtils.poppins(
                  fontSize: 14,
                  color: const Color(0xFF2c3e50),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(false),
                  child: Text(
                    '否',
                    style: FontUtils.poppins(
                      fontSize: 14,
                      color: const Color(0xFF7f8c8d),
                    ),
                  ),
                ),
                TextButton(
                  onPressed: () => Navigator.of(context).pop(true),
                  child: Text(
                    '是',
                    style: FontUtils.poppins(
                      fontSize: 14,
                      color: const Color(0xFFe74c3c),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          );

          if (shouldClear == true) {
            await LocalModeStorageService.clearAllLocalModeData();
          } else if (shouldClear == null) {
            // 用户取消了对话框
            return;
          }

          setState(() {
            _isLoading = true;
          });
        }

        // 保存订阅链接和内容
        await LocalModeStorageService.saveSubscriptionUrl(newUrl);
        if (content.searchResources != null && content.searchResources!.isNotEmpty) {
          await LocalModeStorageService.saveSearchSources(content.searchResources!);
        }
        if (content.liveSources != null && content.liveSources!.isNotEmpty) {
          await LocalModeStorageService.saveLiveSources(content.liveSources!);
        }

        // 保存模式状态为本地模式
        await UserDataService.saveIsLocalMode(true);

        setState(() {
          _isLoading = false;
        });

        // 刷新海报数据（让用户每次登录看到不同的海报）
        PosterService().refresh();

        // _showToast('本地模式登录成功！', const Color(0xFF27ae60));

        // 跳转到首页，并清除所有路由栈（强制销毁所有旧页面）
        if (mounted) {
          Navigator.of(context).pushAndRemoveUntil(
            MaterialPageRoute(builder: (context) => const HomeScreen()),
            (route) => false,
          );
        }
      } catch (e) {
        setState(() {
          _isLoading = false;
        });
        _showToast('登录失败：${e.toString()}', const Color(0xFFe74c3c));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isTablet = DeviceUtils.isTablet(context);

    return Scaffold(
      body: GestureDetector(
        onTap: _handleInteraction,
        behavior: HitTestBehavior.translucent,
        child: Stack(
          fit: StackFit.expand,
          children: [
            // 底层：海洋蓝色渐变 - 营造深海氛围
            Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Color(0xFFa5f3fc), // cyan-100
                    Color(0xFF7dd3fc), // sky-300
                    Color(0xFF60a5fa), // blue-400
                    Color(0xFF3b82f6), // blue-500
                  ],
                  stops: [0.0, 0.3, 0.6, 1.0],
                ),
              ),
            ),

            // 中层：背景图片（带加载动画）
            if (_backgroundImageUrl.isNotEmpty)
              CachedNetworkImage(
                imageUrl: _backgroundImageUrl,
                fit: BoxFit.cover,
                fadeInDuration: const Duration(milliseconds: 700),
                fadeOutDuration: const Duration(milliseconds: 300),
                imageBuilder: (context, imageProvider) {
                  // 图片加载完成后回调
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    _onBackgroundLoaded();
                  });
                  return Container(
                    decoration: BoxDecoration(
                      image: DecorationImage(
                        image: imageProvider,
                        fit: BoxFit.cover,
                        colorFilter: ColorFilter.mode(
                          Colors.black.withValues(alpha: 0.3),
                          BlendMode.darken,
                        ),
                      ),
                    ),
                  );
                },
                placeholder: (context, url) => Container(
                  color: Colors.transparent,
                ),
                errorWidget: (context, url, error) {
                  // 加载失败也显示渐变背景
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    _onBackgroundLoaded();
                  });
                  return Container(
                    color: Colors.transparent,
                  );
                },
              ),

            // 半透明遮罩层
            Container(
              color: Colors.black.withValues(alpha: 0.2),
            ),

            // 毛玻璃效果层（背景加载时显示）
            if (_isBackgroundLoading)
                        BackdropFilter(
                          filter: ImageFilter.blur(sigmaX: 30, sigmaY: 30),
                          child: Container(
                            color: Colors.white.withValues(alpha: 0.1),
                          ),
                        ),
            // 加载动画 - 双层旋转圆圈
            if (_isBackgroundLoading)
              Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // 双层旋转动画
                    SizedBox(
                      width: 80,
                      height: 80,
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          // 外圈旋转
                          AnimatedBuilder(
                            animation: _outerRotationController,
                            builder: (context, child) {
                              return Transform.rotate(
                                angle: _outerRotationController.value * 2 * 3.14159,
                                child: Container(
                                  width: 80,
                                  height: 80,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                      color: Colors.white.withValues(alpha: 0.1),
                                      width: 4,
                                    ),
                                  ),
                                  child: CircularProgressIndicator(
                                    value: 0.25,
                                    strokeWidth: 4,
                                    valueColor: const AlwaysStoppedAnimation(
                                      Color(0xFF60a5fa), // blue-400
                                    ),
                                    backgroundColor: Colors.transparent,
                                  ),
                                ),
                              );
                            },
                          ),
                          // 内圈反向旋转
                          AnimatedBuilder(
                            animation: _innerRotationController,
                            builder: (context, child) {
                              return Transform.rotate(
                                angle: -_innerRotationController.value * 2 * 3.14159,
                                child: Container(
                                  width: 56,
                                  height: 56,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                      color: Colors.white.withValues(alpha: 0.1),
                                      width: 3,
                                    ),
                                  ),
                                  child: CircularProgressIndicator(
                                    value: 0.3,
                                    strokeWidth: 3,
                                    valueColor: const AlwaysStoppedAnimation(
                                      Color(0xFF34d399), // emerald-400
                                    ),
                                    backgroundColor: Colors.transparent,
                                  ),
                                ),
                              );
                            },
                          ),
                          // 中心脉冲圆点
                          AnimatedBuilder(
                            animation: _pulseController,
                            builder: (context, child) {
                              return Container(
                                width: 16 + (_pulseController.value * 4),
                                height: 16 + (_pulseController.value * 4),
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  gradient: const LinearGradient(
                                    colors: [
                                      Color(0xFF60a5fa), // blue-400
                                      Color(0xFF34d399), // emerald-400
                                    ],
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color: const Color(0xFF60a5fa).withValues(alpha: 0.5 + (_pulseController.value * 0.3)),
                                      blurRadius: 10 + (_pulseController.value * 10),
                                      spreadRadius: 2,
                                    ),
                                  ],
                                ),
                              );
                            },
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),
                    // 加载文字
                    Text(
                      'LOADING',
                      style: FontUtils.poppins(
                        fontSize: 12,
                        color: Colors.white.withValues(alpha: 0.6),
                        letterSpacing: 4,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),

            // 登录表单
            if (!_isBackgroundLoading)
              SafeArea(
                child: Center(
                  child: SingleChildScrollView(
                    padding: EdgeInsets.symmetric(
                      horizontal: isTablet ? 0 : 32.0,
                      vertical: 24.0,
                    ),
                    child: AnimatedBuilder(
                      animation: _formScaleController,
                      builder: (context, child) {
                        return Opacity(
                          opacity: _formOpacityAnimation.value,
                          child: Transform.scale(
                            scale: _formScaleAnimation.value,
                            child: child,
                          ),
                        );
                      },
                      child: isTablet
                          ? _buildTabletLayout()
                          : _buildMobileLayout(),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  // 手机端布局 - Vidora 风格毛玻璃卡片
  Widget _buildMobileLayout() {
    return ClipRRect(
      borderRadius: BorderRadius.circular(24),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: Container(
          width: double.infinity,
          constraints: const BoxConstraints(maxWidth: 400),
          padding: const EdgeInsets.all(28),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.2),
              width: 1,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.2),
                blurRadius: 30,
                spreadRadius: 5,
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Vidora 标题 - 可点击
              GestureDetector(
                onTap: _handleLogoTap,
                child: Text(
                  'Vidora',
                  style: FontUtils.sourceCodePro(
                    fontSize: 36,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                    letterSpacing: 2,
                  ),
                ),
              ),
              const SizedBox(height: 32),

              // 登录表单
              Form(
                key: _formKey,
                child: _isLocalMode
                    ? _buildVidoraLocalModeForm()
                    : _buildVidoraServerForm(),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Vidora 风格服务器登录表单
  Widget _buildVidoraServerForm() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // URL 输入框
        _buildVidoraTextField(
          controller: _urlController,
          label: '服务器地址',
          hint: 'https://example.com',
          icon: Icons.link,
          validator: (value) {
            if (value == null || value.isEmpty) {
              return '请输入服务器地址';
            }
            final uri = Uri.tryParse(value);
            if (uri == null || uri.scheme.isEmpty || uri.host.isEmpty) {
              return '请输入有效的URL地址';
            }
            return null;
          },
        ),
        const SizedBox(height: 16),

        // 用户名输入框
        _buildVidoraTextField(
          controller: _usernameController,
          label: '用户名',
          hint: '请输入用户名',
          icon: Icons.person,
          validator: (value) {
            if (value == null || value.isEmpty) {
              return '请输入用户名';
            }
            return null;
          },
        ),
        const SizedBox(height: 16),

        // 密码输入框
        _buildVidoraPasswordField(),
        const SizedBox(height: 28),

        // 登录按钮 - 渐变绿色
        _buildVidoraLoginButton(
          onPressed: _isLoading || !_isFormValid ? null : _handleLogin,
          isLoading: _isLoading,
          text: '登录',
        ),
      ],
    );
  }

  // Vidora 风格本地模式表单
  Widget _buildVidoraLocalModeForm() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // 订阅链接输入框
        _buildVidoraTextField(
          controller: _subscriptionUrlController,
          label: '订阅链接',
          hint: '请输入订阅链接',
          icon: Icons.link,
          validator: (value) {
            if (value == null || value.isEmpty) {
              return '请输入订阅链接';
            }
            return null;
          },
        ),
        const SizedBox(height: 28),

        // 登录按钮
        _buildVidoraLoginButton(
          onPressed: _isLoading || !_isFormValid ? null : _handleLocalModeLogin,
          isLoading: _isLoading,
          text: '登录',
        ),
      ],
    );
  }

  // Vidora 风格文本输入框
  Widget _buildVidoraTextField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    required String? Function(String?) validator,
  }) {
    return TextFormField(
      controller: controller,
      style: FontUtils.poppins(
        fontSize: 15,
        color: Colors.white,
      ),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: FontUtils.poppins(
          color: Colors.white.withValues(alpha: 0.8),
          fontSize: 13,
        ),
        hintText: hint,
        hintStyle: FontUtils.poppins(
          color: Colors.white.withValues(alpha: 0.4),
          fontSize: 14,
        ),
        prefixIcon: Icon(
          icon,
          color: Colors.white.withValues(alpha: 0.7),
          size: 20,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(
            color: Colors.white.withValues(alpha: 0.5),
            width: 1,
          ),
        ),
        filled: true,
        fillColor: Colors.white.withValues(alpha: 0.1),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 16,
        ),
      ),
      validator: validator,
      onFieldSubmitted: (_) => _handleSubmit(),
    );
  }

  // Vidora 风格密码输入框
  Widget _buildVidoraPasswordField() {
    return TextFormField(
      controller: _passwordController,
      obscureText: !_isPasswordVisible,
      style: FontUtils.poppins(
        fontSize: 15,
        color: Colors.white,
      ),
      decoration: InputDecoration(
        labelText: '密码',
        labelStyle: FontUtils.poppins(
          color: Colors.white.withValues(alpha: 0.8),
          fontSize: 13,
        ),
        hintText: '请输入密码',
        hintStyle: FontUtils.poppins(
          color: Colors.white.withValues(alpha: 0.4),
          fontSize: 14,
        ),
        prefixIcon: Icon(
          Icons.lock,
          color: Colors.white.withValues(alpha: 0.7),
          size: 20,
        ),
        suffixIcon: IconButton(
          icon: Icon(
            _isPasswordVisible ? Icons.visibility : Icons.visibility_off,
            color: Colors.white.withValues(alpha: 0.7),
            size: 20,
          ),
          onPressed: () {
            setState(() {
              _isPasswordVisible = !_isPasswordVisible;
            });
          },
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(
            color: Colors.white.withValues(alpha: 0.5),
            width: 1,
          ),
        ),
        filled: true,
        fillColor: Colors.white.withValues(alpha: 0.1),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 16,
        ),
      ),
      validator: (value) {
        if (value == null || value.isEmpty) {
          return '请输入密码';
        }
        return null;
      },
      onFieldSubmitted: (_) => _handleSubmit(),
    );
  }

  // Vidora 风格登录按钮 - 渐变绿色
  Widget _buildVidoraLoginButton({
    required VoidCallback? onPressed,
    required bool isLoading,
    required String text,
  }) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        gradient: onPressed != null
            ? const LinearGradient(
                colors: [
                  Color(0xFF16a34a), // green-600
                  Color(0xFF059669), // emerald-600
                ],
              )
            : LinearGradient(
                colors: [
                  Colors.grey.withValues(alpha: 0.5),
                  Colors.grey.withValues(alpha: 0.3),
                ],
              ),
        boxShadow: onPressed != null
            ? [
                BoxShadow(
                  color: const Color(0xFF16a34a).withValues(alpha: 0.4),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ]
            : null,
      ),
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.transparent,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          elevation: 0,
          shadowColor: Colors.transparent,
        ),
        child: isLoading
            ? Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  SizedBox(
                    height: 18,
                    width: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(
                        Colors.white.withValues(alpha: 0.9),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    '登录中...',
                    style: FontUtils.poppins(
                      fontSize: 15,
                      fontWeight: FontWeight.w500,
                      color: Colors.white.withValues(alpha: 0.9),
                    ),
                  ),
                ],
              )
            : Text(
                text,
                style: FontUtils.poppins(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 1,
                  color: Colors.white,
                ),
              ),
      ),
    );
  }

  // 平板端布局 - 简单调用手机端布局并限制宽度
  Widget _buildTabletLayout() {
    return Container(
      constraints: const BoxConstraints(maxWidth: 480),
      padding: const EdgeInsets.symmetric(horizontal: 32.0),
      child: _buildMobileLayout(),
    );
  }
}