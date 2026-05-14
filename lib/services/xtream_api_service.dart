import 'package:dio/dio.dart';
import '../models/channel.dart';

class XtreamApiService {
  final Dio _dio = Dio(BaseOptions(
    connectTimeout: const Duration(seconds: 30),
    receiveTimeout: const Duration(seconds: 120),
  ));

  late String _serverUrl;
  late String _username;
  late String _password;

  String get baseUrl {
    String url = _serverUrl.trim();
    if (!url.startsWith('http://') && !url.startsWith('https://')) {
      url = 'http://$url';
    }
    if (url.endsWith('/')) {
      url = url.substring(0, url.length - 1);
    }
    return url;
  }

  void setCredentials({
    required String serverUrl,
    required String username,
    required String password,
  }) {
    _serverUrl = serverUrl;
    _username = username;
    _password = password;
  }

  String get _apiBase =>
      '$baseUrl/player_api.php?username=$_username&password=$_password';

  /// Authenticate and get server info
  Future<Map<String, dynamic>> authenticate() async {
    final response = await _dio.get(_apiBase);

    if (response.statusCode == 200 && response.data != null) {
      final data = response.data;
      if (data is Map<String, dynamic> && data.containsKey('user_info')) {
        return data;
      }
      throw Exception('Invalid response from server');
    }
    throw Exception('Authentication failed: ${response.statusCode}');
  }

  // ═══════════════════════════════════════════
  // LIVE STREAMS
  // ═══════════════════════════════════════════

  /// Get live stream categories
  Future<List<Map<String, dynamic>>> getLiveCategories() async {
    final response = await _dio.get('$_apiBase&action=get_live_categories');
    if (response.statusCode == 200 && response.data is List) {
      return List<Map<String, dynamic>>.from(response.data);
    }
    return [];
  }

  /// Get live streams
  Future<List<Channel>> getLiveStreams({String? categoryId}) async {
    Map<String, String> categoryMap = {};
    if (categoryId == null) {
      try {
        final cats = await getLiveCategories();
        for (var c in cats) {
          categoryMap[c['category_id'].toString()] = c['category_name'].toString();
        }
      } catch (_) {}
    }

    String url = '$_apiBase&action=get_live_streams';
    if (categoryId != null) url += '&category_id=$categoryId';

    final response = await _dio.get(url);
    if (response.statusCode == 200 && response.data is List) {
      return _parseChannelList(response.data as List, 'live', categoryMap);
    }
    return [];
  }

  /// Alias for getLiveStreams
  Future<List<Channel>> getAllLiveStreams() => getLiveStreams();

  // ═══════════════════════════════════════════
  // VOD (MOVIES)
  // ═══════════════════════════════════════════

  /// Get VOD categories
  Future<List<Map<String, dynamic>>> getVodCategories() async {
    final response = await _dio.get('$_apiBase&action=get_vod_categories');
    if (response.statusCode == 200 && response.data is List) {
      return List<Map<String, dynamic>>.from(response.data);
    }
    return [];
  }

  /// Get VOD (movie) streams
  Future<List<Channel>> getVodStreams({String? categoryId}) async {
    Map<String, String> categoryMap = {};
    if (categoryId == null) {
      try {
        final cats = await getVodCategories();
        for (var c in cats) {
          categoryMap[c['category_id'].toString()] = c['category_name'].toString();
        }
      } catch (_) {}
    }

    String url = '$_apiBase&action=get_vod_streams';
    if (categoryId != null) url += '&category_id=$categoryId';

    final response = await _dio.get(url);
    if (response.statusCode == 200 && response.data is List) {
      return _parseChannelList(response.data as List, 'movie', categoryMap);
    }
    return [];
  }

  // ═══════════════════════════════════════════
  // SERIES
  // ═══════════════════════════════════════════

  /// Get series categories
  Future<List<Map<String, dynamic>>> getSeriesCategories() async {
    final response = await _dio.get('$_apiBase&action=get_series_categories');
    if (response.statusCode == 200 && response.data is List) {
      return List<Map<String, dynamic>>.from(response.data);
    }
    return [];
  }

  /// Get series list
  Future<List<Channel>> getSeriesStreams({String? categoryId}) async {
    Map<String, String> categoryMap = {};
    if (categoryId == null) {
      try {
        final cats = await getSeriesCategories();
        for (var c in cats) {
          categoryMap[c['category_id'].toString()] = c['category_name'].toString();
        }
      } catch (_) {}
    }

    String url = '$_apiBase&action=get_series';
    if (categoryId != null) url += '&category_id=$categoryId';

    final response = await _dio.get(url);
    if (response.statusCode == 200 && response.data is List) {
      return (response.data as List).map<Channel>((item) {
        final map = Map<String, dynamic>.from(item);
        final seriesId = map['series_id'];

        final catId = map['category_id']?.toString() ?? '';
        String catName = map['category_name']?.toString() ?? '';
        if ((catName.isEmpty || catName == 'null') && categoryMap.isNotEmpty && catId.isNotEmpty) {
          catName = categoryMap[catId] ?? '';
        }
        if (catName.isEmpty || catName == 'null') catName = 'Uncategorized';

        return Channel(
          name: map['name']?.toString() ?? 'Unknown',
          streamUrl: 'xtream_series://$seriesId', // placeholder — series need episode selection
          logoUrl: map['cover']?.toString() ?? '',
          group: catName.trim(),
          streamId: seriesId is int ? seriesId : int.tryParse(seriesId?.toString() ?? ''),
        );
      }).toList();
    }
    return [];
  }

  /// Get series episode info
  Future<Map<String, dynamic>?> getSeriesInfo(int seriesId) async {
    final response = await _dio.get('$_apiBase&action=get_series_info&series_id=$seriesId');
    if (response.statusCode == 200 && response.data is Map) {
      return Map<String, dynamic>.from(response.data);
    }
    return null;
  }

  // ═══════════════════════════════════════════
  // SHARED PARSER
  // ═══════════════════════════════════════════

  /// Construct episode streaming URL
  String getEpisodeStreamUrl(String extension, String episodeId) {
    return '$baseUrl/series/$_username/$_password/$episodeId.$extension';
  }

  /// Parse a list of stream items into Channel objects
  List<Channel> _parseChannelList(List items, String type, [Map<String, String>? categoryMap]) {
    return items.map<Channel>((item) {
      final map = Map<String, dynamic>.from(item);
      final streamId = map['stream_id'];
      final ext = map['container_extension']?.toString() ?? 'ts';

      // Build stream URL based on content type
      final String streamUrl;
      if (type == 'live') {
        streamUrl = '$baseUrl/live/$_username/$_password/$streamId.$ext';
      } else {
        streamUrl = '$baseUrl/movie/$_username/$_password/$streamId.$ext';
      }

      final catId = map['category_id']?.toString() ?? '';
      String catName = map['category_name']?.toString() ?? '';
      if ((catName.isEmpty || catName == 'null') && categoryMap != null && catId.isNotEmpty) {
        catName = categoryMap[catId] ?? '';
      }
      if (catName.isEmpty || catName == 'null') catName = 'Uncategorized';

      return Channel(
        name: map['name']?.toString() ?? 'Unknown',
        streamUrl: streamUrl,
        logoUrl: map['stream_icon']?.toString() ?? '',
        group: catName.trim(),
        streamId: streamId is int ? streamId : int.tryParse(streamId?.toString() ?? ''),
      );
    }).toList();
  }
}
