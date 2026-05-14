/// Channel model representing a single IPTV channel.
/// Supports metadata from M3U, M3U Plus, and Xtream Codes formats.
class Channel {
  final String name;
  final String streamUrl;
  final String logoUrl;
  final String group;
  final String tvgId;
  final String tvgName;
  final String language;
  final int? streamId;

  Channel({
    required this.name,
    required this.streamUrl,
    this.logoUrl = '',
    this.group = 'Uncategorized',
    this.tvgId = '',
    this.tvgName = '',
    this.language = '',
    this.streamId,
  });

  factory Channel.fromJson(Map<String, dynamic> json) {
    return Channel(
      name: json['name'] ?? json['stream_display_name'] ?? 'Unknown',
      streamUrl: json['stream_url'] ?? '',
      logoUrl: json['stream_icon'] ?? json['logo_url'] ?? '',
      group: json['category_name'] ?? json['group'] ?? 'Uncategorized',
      tvgId: json['tvg_id'] ?? '',
      tvgName: json['tvg_name'] ?? '',
      language: json['tvg_language'] ?? '',
      streamId: json['stream_id'] is int
          ? json['stream_id']
          : int.tryParse(json['stream_id']?.toString() ?? ''),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'stream_url': streamUrl,
      'logo_url': logoUrl,
      'group': group,
      'tvg_id': tvgId,
      'tvg_name': tvgName,
      'language': language,
      'stream_id': streamId,
    };
  }
}
