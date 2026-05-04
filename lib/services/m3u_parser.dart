import 'dart:convert';
import '../models/channel.dart';

/// Invincible & Universal M3U/M3U8 Parser.
///
/// Handles ALL known M3U variations:
/// - Standard M3U with #EXTINF
/// - M3U Plus (tvg-id, tvg-name, tvg-logo, tvg-language, group-title)
/// - Xtream Codes output
/// - Broken/malformed files (missing commas, extra whitespace, BOM markers)
/// - Mixed line-endings (\r\n, \n, \r)
/// - Attributes with single or double quotes
/// - #EXTVLCOPT and #KODIPROP directives (skipped gracefully)
class M3uParser {
  // ── Regex patterns (compiled once, reused) ──

  /// Matches: key="value" OR key='value'
  static final RegExp _doubleQuoteAttr = RegExp(
    r'([\w-]+)\s*=\s*"([^"]*)"',
    caseSensitive: false,
  );

  static final RegExp _singleQuoteAttr = RegExp(
    r"([\w-]+)\s*=\s*'([^']*)'",
    caseSensitive: false,
  );

  /// Matches valid stream URL protocols.
  static final RegExp _urlPattern = RegExp(
    r'^(https?://|rtsp://|rtmp://|rtp://|mms://|mmsh://|udp://|/)',
    caseSensitive: false,
  );

  /// Parse raw bytes into a list of Channel objects.
  /// Tries UTF-8 first (with allowMalformed), then Latin-1 fallback.
  static List<Channel> parseBytes(List<int> bytes) {
    String content;
    try {
      content = utf8.decode(bytes, allowMalformed: true);
    } catch (_) {
      content = latin1.decode(bytes);
    }
    return parse(content);
  }

  /// Parse M3U content string into a list of Channel objects.
  static List<Channel> parse(String content) {
    if (content.isEmpty) return [];

    final List<Channel> channels = [];

    // ── Normalize the content ──
    // Remove BOM (Byte Order Mark) if present
    String normalized = content;
    if (normalized.codeUnitAt(0) == 0xFEFF) {
      normalized = normalized.substring(1);
    }

    // Normalize all line endings to \n
    normalized = normalized.replaceAll('\r\n', '\n').replaceAll('\r', '\n');

    final lines = normalized.split('\n');

    // ── State machine for parsing ──
    String? pendingName;
    String pendingLogo = '';
    String pendingGroup = '';
    String pendingTvgId = '';
    String pendingTvgName = '';
    String pendingLanguage = '';

    for (int i = 0; i < lines.length; i++) {
      final line = lines[i].trim();

      // Skip empty lines and the #EXTM3U header
      if (line.isEmpty) continue;
      if (line.toUpperCase().startsWith('#EXTM3U')) continue;

      // Skip known directives we don't need
      if (line.startsWith('#EXTVLCOPT') ||
          line.startsWith('#KODIPROP') ||
          line.startsWith('#EXT-X-')) {
        continue;
      }

      if (line.startsWith('#EXTINF:') || line.startsWith('#EXTINF :')) {
        // ── Parse the #EXTINF line ──

        // Extract all key="value" attributes
        final attrs = _extractAllAttributes(line);
        pendingTvgId = attrs['tvg-id'] ?? '';
        pendingTvgName = attrs['tvg-name'] ?? '';
        pendingLogo = attrs['tvg-logo'] ?? '';
        pendingGroup = attrs['group-title'] ?? '';
        pendingLanguage = attrs['tvg-language'] ?? '';

        // Extract channel name: everything after the LAST comma
        // We need to find the last comma that's NOT inside quotes
        pendingName = _extractChannelName(line);

        // If no name found via comma, try tvg-name, then fallback
        if (pendingName.isEmpty && pendingTvgName.isNotEmpty) {
          pendingName = pendingTvgName;
        }
      } else if (line.startsWith('#')) {
        // Skip any other comment/directive line
        continue;
      } else if (_urlPattern.hasMatch(line)) {
        // ── This line is a stream URL ──
        String channelName = (pendingName != null && pendingName.isNotEmpty)
            ? pendingName
            : _guessNameFromUrl(line);

        if (channelName.isNotEmpty) {
          // Fallback: If group is empty, try to extract it from the channel name (e.g. "Category: Channel")
          if (pendingGroup.isEmpty) {
            final match = RegExp(r'^([^:|]+?)\s*[:|]\s*(.+)$').firstMatch(channelName);
            if (match != null) {
              final possibleGroup = match.group(1)?.trim();
              final possibleName = match.group(2)?.trim();
              if (possibleGroup != null && possibleGroup.isNotEmpty && possibleName != null && possibleName.isNotEmpty) {
                // If the suspected group name is reasonably short (prevents capturing half a sentence)
                if (possibleGroup.length <= 30) {
                  pendingGroup = possibleGroup;
                  channelName = possibleName;
                }
              }
            }
          }
          channels.add(
            Channel(
              name: channelName,
              streamUrl: line,
              logoUrl: pendingLogo,
              group: pendingGroup.isNotEmpty ? pendingGroup : 'Uncategorized',
              tvgId: pendingTvgId,
              tvgName: pendingTvgName,
              language: pendingLanguage,
            ),
          );
        }

        // Reset state for next entry
        pendingName = null;
        pendingLogo = '';
        pendingGroup = '';
        pendingTvgId = '';
        pendingTvgName = '';
        pendingLanguage = '';
      }
    }

    return channels;
  }

  /// Extract the channel name from the #EXTINF line.
  /// The name is everything after the LAST comma that's outside quotes.
  static String _extractChannelName(String line) {
    // Walk the string to find the last comma that is NOT inside quotes
    bool inDoubleQuote = false;
    bool inSingleQuote = false;
    int lastCommaIndex = -1;

    for (int i = 0; i < line.length; i++) {
      final char = line[i];
      if (char == '"' && !inSingleQuote) {
        inDoubleQuote = !inDoubleQuote;
      } else if (char == "'" && !inDoubleQuote) {
        inSingleQuote = !inSingleQuote;
      } else if (char == ',' && !inDoubleQuote && !inSingleQuote) {
        lastCommaIndex = i;
      }
    }

    if (lastCommaIndex >= 0 && lastCommaIndex < line.length - 1) {
      return line.substring(lastCommaIndex + 1).trim();
    }
    return '';
  }

  /// Extract ALL key="value" or key='value' attribute pairs from a line.
  static Map<String, String> _extractAllAttributes(String line) {
    final Map<String, String> attrs = {};

    // Match double-quoted attributes: key="value"
    for (final match in _doubleQuoteAttr.allMatches(line)) {
      final key = match.group(1)?.toLowerCase() ?? '';
      final value = match.group(2) ?? '';
      if (key.isNotEmpty) attrs[key] = value;
    }

    // Match single-quoted attributes: key='value'
    for (final match in _singleQuoteAttr.allMatches(line)) {
      final key = match.group(1)?.toLowerCase() ?? '';
      final value = match.group(2) ?? '';
      if (key.isNotEmpty && !attrs.containsKey(key)) {
        attrs[key] = value;
      }
    }

    return attrs;
  }

  /// Attempt to guess a channel name from its URL (last path segment).
  static String _guessNameFromUrl(String url) {
    try {
      final uri = Uri.parse(url);
      final segments = uri.pathSegments.where((s) => s.isNotEmpty).toList();
      if (segments.isNotEmpty) {
        String name = segments.last;
        // Remove file extension
        final dotIndex = name.lastIndexOf('.');
        if (dotIndex > 0) {
          name = name.substring(0, dotIndex);
        }
        // Replace underscores/dashes with spaces
        name = name.replaceAll(RegExp(r'[_-]'), ' ');
        return name.trim();
      }
    } catch (_) {}
    return 'Unknown Channel';
  }
}
