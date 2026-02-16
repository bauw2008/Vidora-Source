import 'dart:convert';
import 'package:http/http.dart' as http;
import 'user_data_service.dart';

/// 短剧分类
class ShortDramaCategory {
  final int id;
  final String name;
  final String? version;
  final List<ShortDramaSubCategory>? subCategories;

  ShortDramaCategory({
    required this.id,
    required this.name,
    this.version,
    this.subCategories,
  });

  factory ShortDramaCategory.fromJson(Map<String, dynamic> json) {
    return ShortDramaCategory(
      id: json['id'] is int ? json['id'] : int.tryParse(json['id']?.toString() ?? '0') ?? 0,
      name: json['name']?.toString() ?? '',
      version: json['version']?.toString(),
      subCategories: json['sub_categories'] != null
          ? (json['sub_categories'] as List)
              .map((e) => ShortDramaSubCategory.fromJson(e))
              .toList()
          : null,
    );
  }
}

/// 短剧子分类
class ShortDramaSubCategory {
  final int id;
  final String name;

  ShortDramaSubCategory({
    required this.id,
    required this.name,
  });

  factory ShortDramaSubCategory.fromJson(Map<String, dynamic> json) {
    return ShortDramaSubCategory(
      id: json['id'] is int ? json['id'] : int.tryParse(json['id']?.toString() ?? '0') ?? 0,
      name: json['name']?.toString() ?? '',
    );
  }
}

/// 短剧项目
class ShortDramaItem {
  final String id;
  final String title;
  final String poster;
  final String? rate;
  final String? year;
  final int? episodes;
  final String? remarks;
  final String? desc;
  final String source;
  final String? videoId;

  ShortDramaItem({
    required this.id,
    required this.title,
    required this.poster,
    this.rate,
    this.year,
    this.episodes,
    this.remarks,
    this.desc,
    this.source = 'shortdrama',
    this.videoId,
  });

  factory ShortDramaItem.fromJson(Map<String, dynamic> json) {
    return ShortDramaItem(
      id: json['id']?.toString() ?? '',
      title: json['name'] ?? json['title'] ?? '',
      poster: json['cover'] ?? json['poster'] ?? '',
      rate: json['rate']?.toString(),
      year: json['year']?.toString(),
      episodes: json['episode_count'] ?? json['episodes'],
      remarks: json['remarks'] ?? 
          (json['update_time'] != null 
              ? json['update_time'].toString().split(RegExp(r'[\sT]'))[0].replaceAll('-', '.')
              : null),
      desc: json['description'] ?? json['desc'],
      source: json['source'] ?? 'shortdrama',
      videoId: json['video_id'] ?? json['id']?.toString(),
    );
  }
}

/// 短剧列表结果
class ShortDramaListResult {
  final List<ShortDramaItem> list;
  final bool hasMore;
  final int? totalPages;

  ShortDramaListResult({
    required this.list,
    this.hasMore = false,
    this.totalPages,
  });

  factory ShortDramaListResult.fromJson(Map<String, dynamic> json) {
    return ShortDramaListResult(
      list: json['list'] != null
          ? (json['list'] as List).map((e) => ShortDramaItem.fromJson(e)).toList()
          : [],
      hasMore: json['hasMore'] == true || json['has_more'] == true,
      totalPages: json['totalPages'] is int 
          ? json['totalPages'] 
          : int.tryParse(json['totalPages']?.toString() ?? '0'),
    );
  }
}

/// 短剧解析结果
class ShortDramaParseResult {
  final int episode;
  final String url;

  ShortDramaParseResult({
    required this.episode,
    required this.url,
  });

  factory ShortDramaParseResult.fromJson(Map<String, dynamic> json) {
    return ShortDramaParseResult(
      episode: json['episode'] is int 
          ? json['episode'] 
          : int.tryParse(json['episode']?.toString() ?? '0') ?? 0,
      url: json['url']?.toString() ?? '',
    );
  }
}

/// 短剧详情
class ShortDramaDetail {
  final String id;
  final String title;
  final String poster;
  final int totalEpisodes;
  final List<String> episodes;
  final List<String> episodeTitles;
  final String? year;
  final String? desc;
  final String source;
  final double? score;
  final String? actor;
  final String? director;

  ShortDramaDetail({
    required this.id,
    required this.title,
    required this.poster,
    required this.totalEpisodes,
    required this.episodes,
    required this.episodeTitles,
    this.year,
    this.desc,
    this.source = 'shortdrama',
    this.score,
    this.actor,
    this.director,
  });

  factory ShortDramaDetail.fromJson(Map<String, dynamic> json) {
    return ShortDramaDetail(
      id: json['id']?.toString() ?? '',
      title: json['title']?.toString() ?? '',
      poster: json['poster']?.toString() ?? '',
      totalEpisodes: json['episodes'] is List 
          ? (json['episodes'] as List).length 
          : (json['totalEpisodes'] is int 
              ? json['totalEpisodes'] 
              : int.tryParse(json['totalEpisodes']?.toString() ?? '1') ?? 1),
      episodes: json['episodes'] != null
          ? (json['episodes'] as List).map((e) => e?.toString() ?? '').toList()
          : [],
      episodeTitles: json['episodes_titles'] != null
          ? (json['episodes_titles'] as List).map((e) => e?.toString() ?? '').toList()
          : [],
      year: json['year']?.toString(),
      desc: json['desc']?.toString(),
      source: json['source']?.toString() ?? 'shortdrama',
      score: json['vote_average'] is num 
          ? json['vote_average'].toDouble() 
          : double.tryParse(json['vote_average']?.toString() ?? ''),
      actor: json['author']?.toString(),
      director: json['director']?.toString(),
    );
  }
}

/// 短剧服务
class ShortDramaService {
  static const Duration _timeout = Duration(seconds: 30);

  /// 获取基础 URL
  static Future<String?> _getBaseUrl() async {
    return await UserDataService.getServerUrl();
  }

  /// 获取认证 cookies
  static Future<String?> _getCookies() async {
    return await UserDataService.getCookies();
  }

  /// 获取短剧分类列表
  /// 通过 Vidora 后端代理接口获取，后端会处理认证
  /// API 返回格式可能是:
  /// - 直接返回数组: [{ id, name, version, sub_categories: [...] }]
  /// - 或者包装格式: { data: [...], version: "..." }
  
  static Future<List<ShortDramaCategory>> getCategories() async {
    final baseUrl = await _getBaseUrl();
    if (baseUrl == null) {
      print('ShortDramaService: 服务器 URL 未配置');
      return [];
    }

    final cookies = await _getCookies();
    final headers = <String, String>{
      'Accept': 'application/json',
      'Content-Type': 'application/json',
    };
    
    // Vidora 后端使用 Cookie 认证
    if (cookies != null && cookies.isNotEmpty) {
      headers['Cookie'] = cookies;
    }

    try {
      // 调用 Vidora 后端的短剧分类代理接口
      final url = '$baseUrl/api/shortdrama/categories';
      print('ShortDramaService: 请求分类列表: $url');
      
      final response = await http.get(
        Uri.parse(url),
        headers: headers,
      ).timeout(_timeout);

      print('ShortDramaService: 分类列表响应状态码: ${response.statusCode}');
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        
        // 情况1: API 直接返回数组
        if (data is List) {
          final categories = data
              .map((e) => ShortDramaCategory.fromJson(e as Map<String, dynamic>))
              .toList();
          print('ShortDramaService: 解析到 ${categories.length} 个分类（数组格式）');
          return categories;
        }
        
        // 情况2: API 返回 { success: true, data: [...], version: ... } 格式
        if (data is Map) {
          // 检查是否有 data 字段
          if (data['data'] is List) {
            final categories = (data['data'] as List)
                .map((e) => ShortDramaCategory.fromJson(e as Map<String, dynamic>))
                .toList();
            print('ShortDramaService: 解析到 ${categories.length} 个分类（包装格式 - data字段）');
            return categories;
          }
          
          // 检查是否是错误响应
          if (data['error'] != null) {
            print('ShortDramaService: API 返回错误: ${data['error']}');
            return [];
          }
        }
        
        print('ShortDramaService: 响应格式错误，期望数组或{data:[...]}，实际: ${data.runtimeType}');
        return [];
      } else if (response.statusCode == 401 || response.statusCode == 403) {
        print('ShortDramaService: 认证失败，请重新登录');
        return [];
      } else {
        print('ShortDramaService: HTTP 错误 ${response.statusCode}');
        return [];
      }
    } catch (e) {
      print('ShortDramaService: 获取分类列表失败: $e');
      return [];
    }
  }

  /// 获取短剧列表
  /// API 返回: { list: [...], hasMore: true, totalPages: ... }
  static Future<ShortDramaListResult> getList({
    int page = 1,
    int size = 25,
    String? tag,
  }) async {
    final baseUrl = await _getBaseUrl();
    if (baseUrl == null) {
      return ShortDramaListResult(list: []);
    }

    final cookies = await _getCookies();
    final headers = <String, String>{
      'Accept': 'application/json',
    };
    if (cookies != null && cookies.isNotEmpty) {
      headers['Cookie'] = cookies;
    }

    try {
      var url = '$baseUrl/api/shortdrama/list?page=$page&size=$size';
      if (tag != null && tag.isNotEmpty) {
        url += '&tag=${Uri.encodeComponent(tag)}';
      }

      final response = await http.get(
        Uri.parse(url),
        headers: headers,
      ).timeout(_timeout);

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data is Map<String, dynamic>) {
          return ShortDramaListResult.fromJson(data);
        }
        return ShortDramaListResult(list: []);
      }
      return ShortDramaListResult(list: []);
    } catch (e) {
      print('ShortDramaService: 获取短剧列表失败: $e');
      return ShortDramaListResult(list: []);
    }
  }

  /// 搜索短剧
  /// API 返回: { list: [...], hasMore: true }
  static Future<ShortDramaListResult> search({
    required String query,
    int page = 1,
    int size = 25,
  }) async {
    final baseUrl = await _getBaseUrl();
    if (baseUrl == null) {
      return ShortDramaListResult(list: []);
    }

    final cookies = await _getCookies();
    final headers = <String, String>{
      'Accept': 'application/json',
    };
    if (cookies != null && cookies.isNotEmpty) {
      headers['Cookie'] = cookies;
    }

    try {
      final url = '$baseUrl/api/shortdrama/search?query=${Uri.encodeComponent(query)}&page=$page&size=$size';

      final response = await http.get(
        Uri.parse(url),
        headers: headers,
      ).timeout(_timeout);

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data is Map<String, dynamic>) {
          return ShortDramaListResult.fromJson(data);
        }
        return ShortDramaListResult(list: []);
      }
      return ShortDramaListResult(list: []);
    } catch (e) {
      print('ShortDramaService: 搜索短剧失败: $e');
      return ShortDramaListResult(list: []);
    }
  }

  /// 短剧详情
  static Future<ShortDramaDetail?> getDetail(String id) async {
    final baseUrl = await _getBaseUrl();
    if (baseUrl == null) return null;

    final cookies = await _getCookies();
    final headers = <String, String>{
      'Accept': 'application/json',
    };
    if (cookies != null && cookies.isNotEmpty) {
      headers['Cookie'] = cookies;
    }

    try {
      final url = '$baseUrl/api/shortdrama/detail?id=$id';
      print('ShortDramaService: 请求详情: $url');
      
      final response = await http.get(
        Uri.parse(url),
        headers: headers,
      ).timeout(_timeout);

      print('ShortDramaService: 详情响应状态码: ${response.statusCode}');
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data is Map<String, dynamic>) {
          return ShortDramaDetail.fromJson(data);
        }
      }
      return null;
    } catch (e) {
      print('ShortDramaService: 获取短剧详情失败: $e');
      return null;
    }
  }

  /// 解析单个短剧播放地址（用于播放器调用）
  static Future<String?> parsePlayUrl({
    required String id,
    required int episode,
  }) async {
    final baseUrl = await _getBaseUrl();
    if (baseUrl == null) return null;

    final cookies = await _getCookies();
    final headers = <String, String>{
      'Accept': 'application/json',
    };
    if (cookies != null && cookies.isNotEmpty) {
      headers['Cookie'] = cookies;
    }

    try {
      final url = '$baseUrl/api/shortdrama/parse?id=$id&episode=$episode';
      print('ShortDramaService: 解析播放地址: $url');
      
      final response = await http.get(
        Uri.parse(url),
        headers: headers,
      ).timeout(_timeout);

      print('ShortDramaService: 解析响应状态码: ${response.statusCode}');
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        // 后端返回格式: { url: "...", originalUrl: "...", ... }
        if (data is Map && data['url'] != null) {
          return data['url'] as String;
        }
      }
      return null;
    } catch (e) {
      print('ShortDramaService: 解析播放地址失败: $e');
      return null;
    }
  }

  /// 解析短剧播放地址（批量）
  static Future<List<ShortDramaParseResult>> parse({
    required String id,
    List<int>? episodes,
    bool useProxy = true,
  }) async {
    final baseUrl = await _getBaseUrl();
    if (baseUrl == null) return [];

    final cookies = await _getCookies();
    final headers = <String, String>{
      'Accept': 'application/json',
    };
    if (cookies != null && cookies.isNotEmpty) {
      headers['Cookie'] = cookies;
    }

    try {
      var url = '$baseUrl/api/shortdrama/parse?id=$id';
      if (episodes != null && episodes.isNotEmpty) {
        url += '&episodes=${episodes.join(',')}';
      }
      if (useProxy) {
        url += '&proxy=true';
      }

      final response = await http.get(
        Uri.parse(url),
        headers: headers,
      ).timeout(_timeout);

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['results'] != null) {
          return (data['results'] as List)
              .map((e) => ShortDramaParseResult.fromJson(e))
              .toList();
        }
      }
      return [];
    } catch (e) {
      print('解析短剧失败: $e');
      return [];
    }
  }
}
