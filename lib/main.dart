import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'screens/login_screen.dart';
import 'services/theme_service.dart';
import 'services/douban_cache_service.dart';
import 'services/poster_service.dart';
import 'package:media_kit/media_kit.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 初始化 media_kit (用于播放器)
  MediaKit.ensureInitialized();

  // 初始化豆瓣缓存服务
  final cacheService = DoubanCacheService();
  await cacheService.init();

  // 启动定期清理
  cacheService.startPeriodicCleanup();

  // 预加载海报数据（异步，不阻塞启动）
  PosterService().refresh();

  runApp(const VidoraApp());
}

class VidoraApp extends StatelessWidget {
  const VidoraApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (context) => ThemeService(),
      child: Consumer<ThemeService>(
        builder: (context, themeService, child) {
          return MaterialApp(
            title: 'Vidora',
            debugShowCheckedModeBanner: false,
            theme: themeService.lightTheme,
            darkTheme: themeService.darkTheme,
            themeMode: themeService.themeMode,
            home: const AppWrapper(),
            builder: (context, child) {
              return child!;
            },
          );
        },
      ),
    );
  }
}

class AppWrapper extends StatefulWidget {
  const AppWrapper({super.key});

  @override
  State<AppWrapper> createState() => _AppWrapperState();
}

class _AppWrapperState extends State<AppWrapper> {
  @override
  void initState() {
    super.initState();
    // 直接进入登录页，让登录页自己处理自动登录逻辑
    // 登录页有完整的加载动画，不需要在这里重复检查
  }

  @override
  Widget build(BuildContext context) {
    return const LoginScreen();
  }
}
