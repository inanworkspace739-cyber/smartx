import 'dart:io';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:dio/dio.dart';
import 'package:file_picker/file_picker.dart';
import '../models/channel.dart';
import '../models/playlist.dart';
import '../services/m3u_parser.dart';
import '../services/xtream_api_service.dart';
import '../services/storage_service.dart';
import 'package:uuid/uuid.dart';

class PlaylistProvider extends ChangeNotifier {
  final StorageService _storageService = StorageService();
  final XtreamApiService _xtreamService = XtreamApiService();
  final Uuid _uuid = const Uuid();

  final Dio _dio = Dio(
    BaseOptions(
      connectTimeout: const Duration(seconds: 30),
      receiveTimeout: const Duration(seconds: 120),
      followRedirects: true,
      maxRedirects: 5,
      headers: {
        'User-Agent': 'VLC/3.0.20 LibVLC/3.0.20',
        'Accept': '*/*',
        'Connection': 'keep-alive',
      },
      validateStatus: (status) => status != null && status < 1000,
      responseType: ResponseType.bytes,
    ),
  );

  // ═══════════════════════════════════════════
  // STATE
  // ═══════════════════════════════════════════

  List<Playlist> _playlists = [];
  List<Channel> _liveChannels = [];
  List<Channel> _vodChannels = [];
  List<Channel> _seriesChannels = [];
  List<Channel> _favorites = [];

  List<String> _liveCategories = [];
  List<String> _vodCategories = [];
  List<String> _seriesCategories = [];

  String _selectedLiveCategory = 'All';
  String _selectedVodCategory = 'All';
  String _selectedSeriesCategory = 'All';

  bool _isLoading = false;
  String? _error;
  Playlist? _currentPlaylist;

  // ═══════════════════════════════════════════
  // GETTERS
  // ═══════════════════════════════════════════

  List<Playlist> get playlists => _playlists;
  List<Channel> get liveChannels => _liveChannels;
  List<Channel> get vodChannels => _vodChannels;
  List<Channel> get seriesChannels => _seriesChannels;
  List<Channel> get favorites => _favorites;

  List<String> get liveCategories => _liveCategories;
  List<String> get vodCategories => _vodCategories;
  List<String> get seriesCategories => _seriesCategories;

  String get selectedLiveCategory => _selectedLiveCategory;
  String get selectedVodCategory => _selectedVodCategory;
  String get selectedSeriesCategory => _selectedSeriesCategory;

  bool get isLoading => _isLoading;
  String? get error => _error;
  Playlist? get currentPlaylist => _currentPlaylist;

  // Backwards compat
  List<Channel> get channels => _liveChannels;
  List<String> get categories => _liveCategories;
  String get selectedCategory => _selectedLiveCategory;

  /// Filtered channels by selected category for each type
  List<Channel> get filteredLiveChannels {
    if (_selectedLiveCategory == 'All') return _liveChannels;
    return _liveChannels
        .where((ch) => ch.group == _selectedLiveCategory)
        .toList();
  }

  List<Channel> get filteredVodChannels {
    if (_selectedVodCategory == 'All') return _vodChannels;
    return _vodChannels
        .where((ch) => ch.group == _selectedVodCategory)
        .toList();
  }

  List<Channel> get filteredSeriesChannels {
    if (_selectedSeriesCategory == 'All') return _seriesChannels;
    return _seriesChannels
        .where((ch) => ch.group == _selectedSeriesCategory)
        .toList();
  }

  List<Channel> get filteredChannels => filteredLiveChannels;

  // ═══════════════════════════════════════════
  // INIT
  // ═══════════════════════════════════════════

  Future<void> init() async {
    await _storageService.init();
    _playlists = _storageService.getPlaylists();
    _favorites = _storageService.getFavorites();
    notifyListeners();
  }

  // ═══════════════════════════════════════════
  // CATEGORY SELECTION
  // ═══════════════════════════════════════════

  void setCategory(String category) {
    _selectedLiveCategory = category;
    notifyListeners();
  }

  void setLiveCategory(String category) {
    _selectedLiveCategory = category;
    notifyListeners();
  }

  void setVodCategory(String category) {
    _selectedVodCategory = category;
    notifyListeners();
  }

  void setSeriesCategory(String category) {
    _selectedSeriesCategory = category;
    notifyListeners();
  }

  // ═══════════════════════════════════════════
  // FAVORITES
  // ═══════════════════════════════════════════

  bool isFavorite(String streamUrl) {
    return _storageService.isFavorite(streamUrl);
  }

  Future<void> toggleFavorite(Channel channel) async {
    if (_storageService.isFavorite(channel.streamUrl)) {
      await _storageService.removeFavorite(channel.streamUrl);
    } else {
      await _storageService.addFavorite(channel);
    }
    _favorites = _storageService.getFavorites();
    notifyListeners();
  }

  // ═══════════════════════════════════════════
  // DOWNLOAD HELPER
  // ═══════════════════════════════════════════

  Future<String> _downloadM3uContent(String url) async {
    final response = await _dio.get<List<int>>(url);
    final bytes = response.data;
    if (bytes == null || bytes.isEmpty) {
      throw Exception('Server returned an empty response.');
    }
    String content;
    try {
      content = utf8.decode(bytes, allowMalformed: true);
    } catch (_) {
      content = latin1.decode(bytes);
    }
    return content;
  }

  // ═══════════════════════════════════════════
  // ADD PLAYLIST — M3U URL
  // ═══════════════════════════════════════════

  Future<void> addM3uUrl({required String name, required String url}) async {
    _setLoading(true);
    _clearError();

    try {
      final xtreamInfo = _parseXtreamUrl(url);
      bool xtreamSuccess = false;

      // 1. Try Xtream API FIRST if valid credentials exist
      if (xtreamInfo != null) {
        try {
          _xtreamService.setCredentials(
            serverUrl: xtreamInfo['server']!,
            username: xtreamInfo['username']!,
            password: xtreamInfo['password']!,
          );
          await _xtreamService.authenticate();
          await _loadAllXtreamContent();

          if (_liveChannels.isNotEmpty ||
              _vodChannels.isNotEmpty ||
              _seriesChannels.isNotEmpty) {
            xtreamSuccess = true;
          }
        } catch (_) {
          // Fallback to M3U
        }
      }

      // 2. Fallback: Try M3U download if Xtream failed or not applicable
      if (!xtreamSuccess) {
        try {
          final content = await _downloadM3uContent(url);
          final trimmed = content.trimLeft();
          if (trimmed.startsWith('#EXTM3U') || trimmed.contains('#EXTINF')) {
            final allChannels = M3uParser.parse(content);
            if (allChannels.isNotEmpty) {
              // Separate into Live / VOD / Series by URL patterns
              _liveChannels = [];
              _vodChannels = [];
              _seriesChannels = [];
              for (final ch in allChannels) {
                final chUrl = ch.streamUrl.toLowerCase();
                if (chUrl.contains('/movie/') || chUrl.contains('/vod/')) {
                  _vodChannels.add(ch);
                } else if (chUrl.contains('/series/')) {
                  _seriesChannels.add(ch);
                } else {
                  _liveChannels.add(ch);
                }
              }
            }
          }
        } catch (_) {}
      }

      if (_liveChannels.isEmpty &&
          _vodChannels.isEmpty &&
          _seriesChannels.isEmpty) {
        _error =
            'No channels found. The server may be unavailable or the URL is incorrect.';
      } else {
        _extractAllCategories();

        final playlist = Playlist(
          id: _uuid.v4(),
          name: name.isEmpty ? 'M3U Playlist' : name,
          type: xtreamSuccess ? PlaylistType.xtream : PlaylistType.m3uUrl,
          url: url,
          serverUrl: xtreamInfo?['server'],
          username: xtreamInfo?['username'],
          password: xtreamInfo?['password'],
        );
        await _storageService.savePlaylist(playlist);
        _playlists = _storageService.getPlaylists();
        _currentPlaylist = playlist;
      }
    } on DioException catch (e) {
      if (e.type == DioExceptionType.connectionTimeout ||
          e.type == DioExceptionType.receiveTimeout) {
        _error =
            'Connection timed out. The playlist may be very large — please try again.';
      } else if (e.type == DioExceptionType.connectionError) {
        _error =
            'Could not connect. Please check the URL or your internet connection.';
      } else {
        _error =
            'Could not download the playlist. Please verify the URL and try again.';
      }
    } catch (e) {
      _error = 'Something went wrong. Please check the URL and try again.';
    }

    _setLoading(false);
  }

  Map<String, String>? _parseXtreamUrl(String url) {
    try {
      final uri = Uri.parse(url);
      final username = uri.queryParameters['username'];
      final password = uri.queryParameters['password'];
      if (username != null &&
          password != null &&
          username.isNotEmpty &&
          password.isNotEmpty) {
        final server =
            '${uri.scheme}://${uri.host}${uri.port != 80 && uri.port != 443 ? ':${uri.port}' : ''}';
        return {'server': server, 'username': username, 'password': password};
      }
      final segments = uri.pathSegments;
      if (segments.length >= 3 && segments[0] == 'live') {
        final server =
            '${uri.scheme}://${uri.host}${uri.port != 80 && uri.port != 443 ? ':${uri.port}' : ''}';
        return {
          'server': server,
          'username': segments[1],
          'password': segments[2],
        };
      }
    } catch (_) {}
    return null;
  }

  // ═══════════════════════════════════════════
  // ADD PLAYLIST — LOCAL FILE
  // ═══════════════════════════════════════════

  Future<void> addLocalFile() async {
    _clearError();

    // Open the file picker FIRST — no loading overlay while user browses
    final result = await FilePicker.platform.pickFiles(
      type: FileType.any,
      allowMultiple: false,
    );

    // User cancelled — do nothing
    if (result == null || result.files.isEmpty) return;

    // Only show loading overlay now that a file has been chosen
    _setLoading(true);

    try {
      if (result.files.isNotEmpty) {
        final file = result.files.first;
        String content;

        if (kIsWeb) {
          content = String.fromCharCodes(file.bytes!);
        } else {
          final bytes = await File(file.path!).readAsBytes();
          try {
            content = utf8.decode(bytes, allowMalformed: true);
          } catch (_) {
            content = latin1.decode(bytes);
          }
        }

        _liveChannels = M3uParser.parse(content);
        _vodChannels = [];
        _seriesChannels = [];
        _extractAllCategories();

        final playlist = Playlist(
          id: _uuid.v4(),
          name: file.name.replaceAll('.m3u', '').replaceAll('.m3u8', ''),
          type: PlaylistType.localFile,
          filePath: file.path,
        );
        await _storageService.savePlaylist(playlist);
        _playlists = _storageService.getPlaylists();
        _currentPlaylist = playlist;
      } else {
        _error = null;
      }
    } catch (e) {
      _error = 'Could not read the file. Make sure it is a valid M3U playlist.';
    }

    _setLoading(false);
  }

  // ═══════════════════════════════════════════
  // ADD PLAYLIST — XTREAM
  // ═══════════════════════════════════════════

  Future<void> addXtreamPlaylist({
    required String name,
    required String serverUrl,
    required String username,
    required String password,
  }) async {
    _setLoading(true);
    _clearError();

    try {
      _xtreamService.setCredentials(
        serverUrl: serverUrl,
        username: username,
        password: password,
      );

      await _xtreamService.authenticate();
      await _loadAllXtreamContent();
      _extractAllCategories();

      final playlist = Playlist(
        id: _uuid.v4(),
        name: name.isEmpty ? 'Xtream Playlist' : name,
        type: PlaylistType.xtream,
        serverUrl: serverUrl,
        username: username,
        password: password,
      );
      await _storageService.savePlaylist(playlist);
      _playlists = _storageService.getPlaylists();
      _currentPlaylist = playlist;
    } catch (e) {
      _error =
          'Could not connect to the Xtream server. Please verify your credentials.';
    }

    _setLoading(false);
  }

  // ═══════════════════════════════════════════
  // LOAD SAVED PLAYLIST
  // ═══════════════════════════════════════════

  Future<void> loadPlaylist(Playlist playlist) async {
    _setLoading(true);
    _clearError();
    _currentPlaylist = playlist;

    try {
      switch (playlist.type) {
        case PlaylistType.m3uUrl:
          // If it was saved as xtream type with credentials, use API
          if (playlist.serverUrl != null &&
              playlist.username != null &&
              playlist.password != null) {
            _xtreamService.setCredentials(
              serverUrl: playlist.serverUrl!,
              username: playlist.username!,
              password: playlist.password!,
            );
            await _xtreamService.authenticate();
            await _loadAllXtreamContent();
          } else {
            final content = await _downloadM3uContent(playlist.url!);
            _liveChannels = M3uParser.parse(content);
            _vodChannels = [];
            _seriesChannels = [];
          }
          break;

        case PlaylistType.localFile:
          if (playlist.filePath != null) {
            final bytes = await File(playlist.filePath!).readAsBytes();
            String content;
            try {
              content = utf8.decode(bytes, allowMalformed: true);
            } catch (_) {
              content = latin1.decode(bytes);
            }
            _liveChannels = M3uParser.parse(content);
            _vodChannels = [];
            _seriesChannels = [];
          }
          break;

        case PlaylistType.xtream:
          _xtreamService.setCredentials(
            serverUrl: playlist.serverUrl!,
            username: playlist.username!,
            password: playlist.password!,
          );
          await _xtreamService.authenticate();
          await _loadAllXtreamContent();
          break;
      }

      _extractAllCategories();
    } catch (e) {
      _error = 'Could not load this playlist. Please try again.';
    }

    _setLoading(false);
  }

  /// Load all Xtream content types in parallel
  Future<void> _loadAllXtreamContent() async {
    final results = await Future.wait([
      _xtreamService.getAllLiveStreams(),
      _xtreamService.getVodStreams(),
      _xtreamService.getSeriesStreams(),
    ]);

    _liveChannels = results[0];
    _vodChannels = results[1];
    _seriesChannels = results[2];
  }

  // ═══════════════════════════════════════════
  // SERIES INFO
  // ═══════════════════════════════════════════

  Future<Map<String, dynamic>?> getSeriesInfo(int seriesId) async {
    return _xtreamService.getSeriesInfo(seriesId);
  }

  String getEpisodeStreamUrl(String extension, String episodeId) {
    return _xtreamService.getEpisodeStreamUrl(extension, episodeId);
  }

  // ═══════════════════════════════════════════
  // DELETE
  // ═══════════════════════════════════════════

  Future<void> deletePlaylist(String id) async {
    await _storageService.deletePlaylist(id);
    _playlists = _storageService.getPlaylists();
    if (_currentPlaylist?.id == id) {
      _currentPlaylist = null;
      _liveChannels = [];
      _vodChannels = [];
      _seriesChannels = [];
      _liveCategories = [];
      _vodCategories = [];
      _seriesCategories = [];
    }
    notifyListeners();
  }

  Future<void> renamePlaylist(String id, String newName) async {
    await _storageService.renamePlaylist(id, newName);
    _playlists = _storageService.getPlaylists();
    if (_currentPlaylist?.id == id) {
      try {
        _currentPlaylist = _playlists.firstWhere((p) => p.id == id);
      } catch (_) {}
    }
    notifyListeners();
  }

  // ═══════════════════════════════════════════
  // SEARCH
  // ═══════════════════════════════════════════

  List<Channel> searchChannels(String query) {
    return searchLiveChannels(query);
  }

  List<Channel> searchLiveChannels(String query) {
    final filtered = filteredLiveChannels;
    if (query.isEmpty) return filtered;
    return filtered
        .where((ch) => ch.name.toLowerCase().contains(query.toLowerCase()))
        .toList();
  }

  List<Channel> searchVodChannels(String query) {
    final filtered = filteredVodChannels;
    if (query.isEmpty) return filtered;
    return filtered
        .where((ch) => ch.name.toLowerCase().contains(query.toLowerCase()))
        .toList();
  }

  List<Channel> searchSeriesChannels(String query) {
    final filtered = filteredSeriesChannels;
    if (query.isEmpty) return filtered;
    return filtered
        .where((ch) => ch.name.toLowerCase().contains(query.toLowerCase()))
        .toList();
  }

  List<Channel> searchFavorites(String query) {
    if (query.isEmpty) return _favorites;
    return _favorites
        .where((ch) => ch.name.toLowerCase().contains(query.toLowerCase()))
        .toList();
  }

  // ═══════════════════════════════════════════
  // PRIVATE HELPERS
  // ═══════════════════════════════════════════

  void _extractAllCategories() {
    _liveCategories = _extractCategoriesFrom(_liveChannels);
    _vodCategories = _extractCategoriesFrom(_vodChannels);
    _seriesCategories = _extractCategoriesFrom(_seriesChannels);
    _selectedLiveCategory = 'All';
    _selectedVodCategory = 'All';
    _selectedSeriesCategory = 'All';
  }

  List<String> _extractCategoriesFrom(List<Channel> channels) {
    // Using a List and checking for duplicates instead of a Set to strictly maintain order of appearance
    final List<String> cats = ['All'];
    for (var channel in channels) {
      if (channel.group.isNotEmpty && !cats.contains(channel.group)) {
        cats.add(channel.group);
      }
    }
    return cats;
  }

  void _setLoading(bool value) {
    _isLoading = value;
    notifyListeners();
  }

  void _clearError() {
    _error = null;
  }
}
