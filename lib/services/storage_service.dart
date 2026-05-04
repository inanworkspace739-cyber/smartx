import 'package:hive_flutter/hive_flutter.dart';
import '../models/playlist.dart';
import '../models/channel.dart';

class StorageService {
  static const String _playlistsBoxName = 'playlists';
  static const String _favoritesBoxName = 'favorites';

  late Box _playlistsBox;
  late Box _favoritesBox;

  Future<void> init() async {
    await Hive.initFlutter();
    _playlistsBox = await Hive.openBox(_playlistsBoxName);
    _favoritesBox = await Hive.openBox(_favoritesBoxName);
  }

  // ═══════════════════════════════════════════
  // PLAYLISTS
  // ═══════════════════════════════════════════

  Future<void> savePlaylist(Playlist playlist) async {
    await _playlistsBox.put(playlist.id, playlist.toMap());
  }

  List<Playlist> getPlaylists() {
    final List<Playlist> playlists = [];
    for (var key in _playlistsBox.keys) {
      final data = _playlistsBox.get(key);
      if (data != null) {
        playlists.add(Playlist.fromMap(Map<dynamic, dynamic>.from(data)));
      }
    }
    playlists.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return playlists;
  }

  Future<void> deletePlaylist(String id) async {
    await _playlistsBox.delete(id);
  }

  bool playlistExists(String id) {
    return _playlistsBox.containsKey(id);
  }

  Future<void> clearAll() async {
    await _playlistsBox.clear();
  }

  Future<void> renamePlaylist(String id, String newName) async {
    final data = _playlistsBox.get(id);
    if (data != null) {
      final map = Map<String, dynamic>.from(data);
      map['name'] = newName;
      await _playlistsBox.put(id, map);
    }
  }
  // ═══════════════════════════════════════════
  // FAVORITES
  // ═══════════════════════════════════════════

  Future<void> addFavorite(Channel channel) async {
    await _favoritesBox.put(channel.streamUrl, {
      'name': channel.name,
      'stream_url': channel.streamUrl,
      'logo_url': channel.logoUrl,
      'group': channel.group,
      'tvg_id': channel.tvgId,
      'tvg_name': channel.tvgName,
      'language': channel.language,
      'stream_id': channel.streamId,
    });
  }

  Future<void> removeFavorite(String streamUrl) async {
    await _favoritesBox.delete(streamUrl);
  }

  bool isFavorite(String streamUrl) {
    return _favoritesBox.containsKey(streamUrl);
  }

  List<Channel> getFavorites() {
    final List<Channel> favorites = [];
    for (var key in _favoritesBox.keys) {
      final data = _favoritesBox.get(key);
      if (data != null) {
        final map = Map<String, dynamic>.from(data);
        favorites.add(
          Channel(
            name: map['name'] ?? 'Unknown',
            streamUrl: map['stream_url'] ?? '',
            logoUrl: map['logo_url'] ?? '',
            group: map['group'] ?? 'Uncategorized',
            tvgId: map['tvg_id'] ?? '',
            tvgName: map['tvg_name'] ?? '',
            language: map['language'] ?? '',
            streamId: map['stream_id'],
          ),
        );
      }
    }
    return favorites;
  }

  Future<void> clearFavorites() async {
    await _favoritesBox.clear();
  }
}
