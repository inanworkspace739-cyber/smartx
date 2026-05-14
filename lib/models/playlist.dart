

enum PlaylistType { m3uUrl, localFile, xtream }

class Playlist {
  final String id;
  final String name;
  final PlaylistType type;
  final String? url;
  final String? filePath;
  final String? username;
  final String? password;
  final String? serverUrl;
  final DateTime createdAt;

  Playlist({
    required this.id,
    required this.name,
    required this.type,
    this.url,
    this.filePath,
    this.username,
    this.password,
    this.serverUrl,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'type': type.index,
      'url': url,
      'filePath': filePath,
      'username': username,
      'password': password,
      'serverUrl': serverUrl,
      'createdAt': createdAt.toIso8601String(),
    };
  }

  factory Playlist.fromMap(Map<dynamic, dynamic> map) {
    return Playlist(
      id: map['id'] ?? '',
      name: map['name'] ?? '',
      type: PlaylistType.values[map['type'] ?? 0],
      url: map['url'],
      filePath: map['filePath'],
      username: map['username'],
      password: map['password'],
      serverUrl: map['serverUrl'],
      createdAt: map['createdAt'] != null
          ? DateTime.parse(map['createdAt'])
          : DateTime.now(),
    );
  }
}
