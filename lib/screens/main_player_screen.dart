import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';
import '../providers/playlist_provider.dart';
import '../theme/app_theme.dart';
import '../models/channel.dart';
import 'video_player_screen.dart';
import 'series_details_screen.dart';

/// IBO Pro Player style: forced landscape, 3-panel layout.
/// Left = categories, Center = channel list, Right = live video preview.
class MainPlayerScreen extends StatefulWidget {
  const MainPlayerScreen({super.key});

  @override
  State<MainPlayerScreen> createState() => _MainPlayerScreenState();
}

class _MainPlayerScreenState extends State<MainPlayerScreen> {
  int _currentTab = 0; // 0=Live, 1=Movies, 2=Series
  String _selectedGroup = 'All';
  int _selectedChannelIndex = 0;
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  // Video preview
  late final Player _player;
  late final VideoController _videoController;
  bool _isBuffering = false;
  String _previewChannelName = '';

  @override
  void initState() {
    super.initState();

    // Force landscape
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);

    // Init player
    _player = Player(
      configuration: const PlayerConfiguration(bufferSize: 32 * 1024 * 1024),
    );
    _videoController = VideoController(_player);

    _player.stream.buffering.listen((buffering) {
      if (mounted) setState(() => _isBuffering = buffering);
    });

    // Auto-play first channel after frame
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _autoPlayFirstChannel();
    });
  }

  void _autoPlayFirstChannel() {
    final provider = context.read<PlaylistProvider>();
    final channels = _getFilteredChannels(provider);
    if (channels.isNotEmpty) {
      _playPreview(channels[0]);
    }
  }

  @override
  void dispose() {
    _player.dispose();
    _searchController.dispose();
    // Restore portrait
    SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    super.dispose();
  }

  void _playPreview(Channel channel) {
    setState(() {
      _previewChannelName = channel.name;
    });

    if (_currentTab == 2) {
      // Do not attempt to play series URLs in preview
      _player.stop();
      return;
    }

    _player.open(Media(channel.streamUrl));
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(gradient: AppTheme.bgGradient),
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: SafeArea(
          child: Column(
            children: [
              // ── TOP NAV BAR ──
              _buildTopBar(),

              // ── 3 PANEL BODY ──
              Expanded(
                child: Consumer<PlaylistProvider>(
                  builder: (context, provider, _) {
                    if (provider.isLoading) {
                      return const Center(
                        child: CircularProgressIndicator(color: AppTheme.gold),
                      );
                    }
                    return Row(
                      children: [
                        // ── LEFT: Categories ──
                        SizedBox(
                          width: MediaQuery.of(context).size.width * 0.22,
                          child: _buildCategorySidebar(provider),
                        ),
                        Container(
                          width: 0.5,
                          color: AppTheme.surfaceBorder.withValues(alpha: 0.4),
                        ),

                        // ── CENTER: Channel List ──
                        SizedBox(
                          width: MediaQuery.of(context).size.width * 0.35,
                          child: _buildChannelList(provider),
                        ),
                        Container(
                          width: 0.5,
                          color: AppTheme.surfaceBorder.withValues(alpha: 0.4),
                        ),

                        // ── RIGHT: Live Video Preview ──
                        Expanded(child: _buildVideoPreview(provider)),
                      ],
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════
  // TOP BAR
  // ═══════════════════════════════════════════
  Widget _buildTopBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: AppTheme.bgCard.withValues(alpha: 0.6),
        border: Border(
          bottom: BorderSide(
            color: AppTheme.surfaceBorder.withValues(alpha: 0.4),
          ),
        ),
      ),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => Navigator.pop(context),
            child: const Icon(
              Icons.arrow_back_ios_rounded,
              color: AppTheme.textPrimary,
              size: 18,
            ),
          ),
          const SizedBox(width: 8),
          _buildTabItem('Home', -1),
          _buildTabDivider(),
          _buildTabItem('Live', 0),
          _buildTabDivider(),
          _buildTabItem('Movies', 1),
          _buildTabDivider(),
          _buildTabItem('Series', 2),
          const SizedBox(width: 12),
          // Search
          Expanded(
            child: Container(
              height: 30,
              decoration: BoxDecoration(
                color: AppTheme.bgDark.withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(15),
                border: Border.all(
                  color: AppTheme.surfaceBorder.withValues(alpha: 0.5),
                ),
              ),
              child: TextField(
                controller: _searchController,
                onChanged: (v) => setState(() => _searchQuery = v),
                style: GoogleFonts.inter(
                  color: AppTheme.textPrimary,
                  fontSize: 12,
                ),
                decoration: InputDecoration(
                  hintText: 'Search...',
                  hintStyle: GoogleFonts.inter(
                    color: AppTheme.textMuted,
                    fontSize: 12,
                    letterSpacing: 0.1,
                  ),
                  prefixIcon: const Icon(
                    Icons.search,
                    color: AppTheme.textMuted,
                    size: 16,
                  ),
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(vertical: 8),
                  isDense: true,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTabItem(String label, int tabIndex) {
    final isSelected = _currentTab == tabIndex;
    return GestureDetector(
      onTap: () {
        if (tabIndex == -1) {
          Navigator.pop(context);
          return;
        }
        setState(() {
          _currentTab = tabIndex;
          _selectedGroup = 'All';
          _selectedChannelIndex = 0;
          _searchQuery = '';
          _searchController.clear();
        });
        // Auto-play first channel of new tab
        WidgetsBinding.instance.addPostFrameCallback(
          (_) => _autoPlayFirstChannel(),
        );
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        child: Text(
          label,
          style: GoogleFonts.outfit(
            fontSize: 13,
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
            color: isSelected ? AppTheme.gold : AppTheme.textSecondary,
            letterSpacing: 0.2,
          ),
        ),
      ),
    );
  }

  Widget _buildTabDivider() {
    return Text(
      '|',
      style: GoogleFonts.inter(fontSize: 13, color: AppTheme.surfaceBorder),
    );
  }

  // ═══════════════════════════════════════════
  // LEFT: CATEGORY SIDEBAR
  // ═══════════════════════════════════════════
  Widget _buildCategorySidebar(PlaylistProvider provider) {
    final channels = _getBaseChannels(provider);
    final groupMap = <String, int>{};
    for (final ch in channels) {
      final g = ch.group.isEmpty ? 'Uncategorized' : ch.group;
      groupMap[g] = (groupMap[g] ?? 0) + 1;
    }
    final groups = groupMap.entries.toList()
      ..sort((a, b) => a.key.toLowerCase().compareTo(b.key.toLowerCase()));
    final totalCount = channels.length;

    final items = <_CategoryItem>[
      _CategoryItem('All', totalCount, isAll: true),
      _CategoryItem('Favorite', provider.favorites.length, isFavorite: true),
      ...groups.map((e) => _CategoryItem(e.key, e.value)),
    ];

    return Container(
      color: AppTheme.bgCard.withValues(alpha: 0.3),
      child: ListView.builder(
        itemCount: items.length,
        padding: const EdgeInsets.symmetric(vertical: 4),
        itemBuilder: (context, index) {
          final item = items[index];
          final isSelected =
              _selectedGroup == item.name ||
              (item.isAll && _selectedGroup == 'All') ||
              (item.isFavorite && _selectedGroup == 'Favorite');
          return GestureDetector(
            onTap: () {
              setState(() {
                _selectedGroup = item.isFavorite
                    ? 'Favorite'
                    : item.isAll
                    ? 'All'
                    : item.name;
                _selectedChannelIndex = 0;
              });
              // Play first channel of new category
              WidgetsBinding.instance.addPostFrameCallback((_) {
                final chs = _getFilteredChannels(provider);
                if (chs.isNotEmpty) {
                  _playPreview(chs[0]);
                }
              });
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
              decoration: BoxDecoration(
                color: isSelected
                    ? AppTheme.bgElevated.withValues(alpha: 0.6)
                    : Colors.transparent,
                border: isSelected
                    ? Border.all(
                        color: AppTheme.gold.withValues(alpha: 0.6),
                        width: 1,
                      )
                    : null,
                borderRadius: BorderRadius.circular(4),
              ),
              margin: const EdgeInsets.symmetric(horizontal: 3, vertical: 1),
              child: Row(
                children: [
                  if (item.isFavorite)
                    const Padding(
                      padding: EdgeInsets.only(right: 3),
                      child: Icon(
                        Icons.star_rounded,
                        color: AppTheme.gold,
                        size: 14,
                      ),
                    ),
                  Expanded(
                    child: Text(
                      item.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.inter(
                        fontSize: 11,
                        fontWeight: isSelected
                            ? FontWeight.w600
                            : FontWeight.w400,
                        color: isSelected
                            ? AppTheme.gold
                            : AppTheme.textPrimary,
                      ),
                    ),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    '${item.count}',
                    style: GoogleFonts.inter(
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                      color: isSelected
                          ? AppTheme.gold
                          : AppTheme.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  // ═══════════════════════════════════════════
  // CENTER: CHANNEL LIST
  // ═══════════════════════════════════════════
  Widget _buildChannelList(PlaylistProvider provider) {
    final channels = _getFilteredChannels(provider);

    if (channels.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.search_off_rounded,
              size: 40,
              color: AppTheme.textMuted,
            ),
            const SizedBox(height: 8),
            Text(
              _searchQuery.isNotEmpty ? 'No results' : 'No channels',
              style: GoogleFonts.outfit(
                fontSize: 14,
                color: AppTheme.textSecondary,
              ),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      itemCount: channels.length,
      padding: const EdgeInsets.symmetric(vertical: 2),
      itemBuilder: (context, index) {
        final ch = channels[index];
        final isSelected = index == _selectedChannelIndex;
        return GestureDetector(
          onTap: () {
            setState(() => _selectedChannelIndex = index);
            _playPreview(ch);
          },
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
            margin: const EdgeInsets.symmetric(horizontal: 3, vertical: 1),
            decoration: BoxDecoration(
              color: isSelected
                  ? AppTheme.bgElevated.withValues(alpha: 0.6)
                  : (index.isEven
                        ? AppTheme.bgCard.withValues(alpha: 0.15)
                        : Colors.transparent),
              border: isSelected
                  ? Border.all(
                      color: AppTheme.gold.withValues(alpha: 0.5),
                      width: 1,
                    )
                  : null,
              borderRadius: BorderRadius.circular(4),
            ),
            child: Row(
              children: [
                // Number
                SizedBox(
                  width: 24,
                  child: Text(
                    '${index + 1}',
                    style: GoogleFonts.outfit(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: isSelected
                          ? AppTheme.gold
                          : AppTheme.textSecondary,
                      letterSpacing: -0.2,
                    ),
                  ),
                ),
                // Logo
                Container(
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                    color: AppTheme.bgElevated,
                    borderRadius: BorderRadius.circular(5),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(5),
                    child: ch.logoUrl.isNotEmpty
                        ? CachedNetworkImage(
                            imageUrl: ch.logoUrl,
                            width: 28,
                            height: 28,
                            fit: BoxFit.cover,
                            placeholder: (_, __) => const Icon(
                              Icons.live_tv,
                              size: 14,
                              color: AppTheme.textMuted,
                            ),
                            errorWidget: (_, __, ___) => const Icon(
                              Icons.live_tv,
                              size: 14,
                              color: AppTheme.textMuted,
                            ),
                          )
                        : const Icon(
                            Icons.live_tv,
                            size: 14,
                            color: AppTheme.textMuted,
                          ),
                  ),
                ),
                const SizedBox(width: 8),
                // Name
                Expanded(
                  child: Text(
                    ch.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.outfit(
                      fontSize: 12,
                      fontWeight: isSelected
                          ? FontWeight.w500
                          : FontWeight.w400,
                      color: isSelected ? AppTheme.gold : AppTheme.textPrimary,
                      letterSpacing: 0.1,
                    ),
                  ),
                ),
                if (provider.isFavorite(ch.streamUrl))
                  const Icon(
                    Icons.star_rounded,
                    size: 14,
                    color: AppTheme.gold,
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  // ═══════════════════════════════════════════
  // RIGHT: VIDEO PREVIEW PANEL
  // ═══════════════════════════════════════════
  Widget _buildVideoPreview(PlaylistProvider provider) {
    final channels = _getFilteredChannels(provider);
    final hasChannels =
        channels.isNotEmpty && _selectedChannelIndex < channels.length;
    final selectedChannel = hasChannels
        ? channels[_selectedChannelIndex]
        : null;
    final isFav =
        selectedChannel != null &&
        provider.isFavorite(selectedChannel.streamUrl);

    return Container(
      color: Colors.black,
      child: Column(
        children: [
          // ── Video Area ──
          Expanded(
            child: _currentTab == 2 && selectedChannel != null
                ? Container(
                    width: double.infinity,
                    color: Colors.black,
                    child: selectedChannel.logoUrl.isNotEmpty
                        ? CachedNetworkImage(
                            imageUrl: selectedChannel.logoUrl,
                            fit: BoxFit.contain, // Fit to show whole poster
                            placeholder: (_, __) => const Center(
                              child: CircularProgressIndicator(color: AppTheme.gold),
                            ),
                            errorWidget: (_, __, ___) => const Center(
                              child: Icon(Icons.movie_rounded, color: AppTheme.textMuted, size: 64),
                            ),
                          )
                        : const Center(
                            child: Icon(Icons.movie_rounded, color: AppTheme.textMuted, size: 64),
                          ),
                  )
                : Stack(
                    children: [
                      // Video
                      Center(
                        child: Video(
                          controller: _videoController,
                          controls: NoVideoControls,
                          fill: Colors.black,
                        ),
                      ),
                      // Buffering
                      if (_isBuffering)
                        const Center(
                          child: CircularProgressIndicator(
                            color: AppTheme.gold,
                            strokeWidth: 2,
                          ),
                        ),
                    ],
                  ),
          ),

          // ── Channel Info + Actions ──
          Container(
            margin: const EdgeInsets.all(8),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: const Color(0xFF1E293B),
              borderRadius: BorderRadius.circular(12),
              boxShadow: const [
                BoxShadow(
                  color: Colors.black26,
                  blurRadius: 10,
                  offset: Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Channel name
                Text(
                  _previewChannelName.isNotEmpty
                      ? _previewChannelName
                      : 'Select a channel',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.outfit(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 6),
                // Action buttons
                Row(
                  children: [
                    // Full Screen button
                    Expanded(
                      child: GestureDetector(
                        onTap: () {
                          if (selectedChannel != null) {
                            _player.pause();
                            if (_currentTab == 2) {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => SeriesDetailsScreen(
                                    seriesChannel: selectedChannel,
                                  ),
                                ),
                              ).then((_) {
                                // Return orientation correctly
                                SystemChrome.setPreferredOrientations([
                                  DeviceOrientation.landscapeLeft,
                                  DeviceOrientation.landscapeRight,
                                ]);
                              });
                            } else {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => VideoPlayerScreen(
                                    channels: channels,
                                    initialIndex: _selectedChannelIndex,
                                    isLive: _currentTab == 0,
                                    restoreToLandscape: true,
                                  ),
                                ),
                              ).then((_) {
                                _player.play();
                              });
                            }
                          }
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [
                                Color(0xFF00C6FF),
                                Color(0xFF0072FF),
                              ], // Cyan to Deep Blue
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            borderRadius: BorderRadius.circular(8),
                            boxShadow: [
                              BoxShadow(
                                color: const Color(
                                  0xFF0072FF,
                                ).withValues(alpha: 0.3),
                                blurRadius: 6,
                                offset: const Offset(0, 3),
                              ),
                            ],
                          ),
                          child: Center(
                            child: Text(
                              _currentTab == 2 ? 'View Episodes' : 'Full Screen',
                              style: GoogleFonts.outfit(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    // Add to Favorite
                    Expanded(
                      child: GestureDetector(
                        onTap: () {
                          if (selectedChannel != null) {
                            provider.toggleFavorite(selectedChannel);
                          }
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          decoration: BoxDecoration(
                            color: isFav
                                ? AppTheme.gold.withValues(alpha: 0.1)
                                : Colors.transparent,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: isFav
                                  ? AppTheme.gold
                                  : const Color(0xFF475569), // Slate 600
                              width: 1.5,
                            ),
                          ),
                          child: Center(
                            child: Text(
                              isFav ? 'Favorited' : 'Add to Favorite',
                              style: GoogleFonts.outfit(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: isFav ? AppTheme.gold : Colors.white,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════
  // DATA HELPERS
  // ═══════════════════════════════════════════
  List<Channel> _getBaseChannels(PlaylistProvider provider) {
    switch (_currentTab) {
      case 0:
        return provider.liveChannels;
      case 1:
        return provider.vodChannels;
      case 2:
        return provider.seriesChannels;
      default:
        return provider.liveChannels;
    }
  }

  List<Channel> _getFilteredChannels(PlaylistProvider provider) {
    List<Channel> channels;
    if (_selectedGroup == 'Favorite') {
      channels = provider.favorites;
    } else {
      channels = _getBaseChannels(provider);
      if (_selectedGroup != 'All') {
        channels = channels.where((c) => c.group == _selectedGroup).toList();
      }
    }
    if (_searchQuery.isNotEmpty) {
      final q = _searchQuery.toLowerCase();
      channels = channels
          .where(
            (c) =>
                c.name.toLowerCase().contains(q) ||
                c.group.toLowerCase().contains(q),
          )
          .toList();
    }
    return channels;
  }
}

// Helper model
class _CategoryItem {
  final String name;
  final int count;
  final bool isAll;
  final bool isFavorite;
  _CategoryItem(
    this.name,
    this.count, {
    this.isAll = false,
    this.isFavorite = false,
  });
}
