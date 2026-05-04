import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../models/channel.dart';
import '../providers/playlist_provider.dart';
import '../theme/app_theme.dart';
import 'video_player_screen.dart';

class SeriesDetailsScreen extends StatefulWidget {
  final Channel seriesChannel;

  const SeriesDetailsScreen({super.key, required this.seriesChannel});

  @override
  State<SeriesDetailsScreen> createState() => _SeriesDetailsScreenState();
}

class _SeriesDetailsScreenState extends State<SeriesDetailsScreen> {
  bool _isLoading = true;
  String? _error;

  Map<String, dynamic>? _info;
  List<String> _seasons = [];
  Map<String, List<dynamic>> _episodesBySeason = {};
  String? _selectedSeason;

  @override
  void initState() {
    super.initState();
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
    _fetchSeriesInfo();
  }

  @override
  void dispose() {
    super.dispose();
  }

  Future<void> _fetchSeriesInfo() async {
    try {
      final provider = context.read<PlaylistProvider>();
      final seriesId = widget.seriesChannel.streamId;

      if (seriesId == null) {
        setState(() {
          _error = 'Invalid series ID.';
          _isLoading = false;
        });
        return;
      }

      final data = await provider.getSeriesInfo(seriesId);

      if (data != null && mounted) {
        setState(() {
          _info = data['info'] is Map ? Map<String, dynamic>.from(data['info']) : null;

          final rawEpisodes = data['episodes'];
          if (rawEpisodes is Map) {
            _episodesBySeason = rawEpisodes.map(
              (key, value) => MapEntry(key.toString(), List<dynamic>.from(value as List)),
            );
            _seasons = _episodesBySeason.keys.toList()
              ..sort((a, b) {
                final aInt = int.tryParse(a) ?? 0;
                final bInt = int.tryParse(b) ?? 0;
                return aInt.compareTo(bInt);
              });

            if (_seasons.isNotEmpty) {
              _selectedSeason = _seasons.first;
            }
          }
          _isLoading = false;
        });
      } else {
        setState(() {
          _error = 'Failed to load series details.';
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = 'Error loading series details.';
          _isLoading = false;
        });
      }
    }
  }

  void _playEpisode(int index, List<dynamic> episodes) {
    final provider = context.read<PlaylistProvider>();

    final channels = episodes.map((ep) {
      final map = Map<String, dynamic>.from(ep);
      final ext = map['container_extension']?.toString() ?? 'mp4';
      final epId = map['id']?.toString() ?? '';
      final title = map['title']?.toString() ?? 'Episode ${map['episode_num']}';

      final streamUrl = provider.getEpisodeStreamUrl(ext, epId);

      return Channel(
        name: '${widget.seriesChannel.name} - $title',
        streamUrl: streamUrl,
        logoUrl: map['info']?['movie_image']?.toString() ??
            _info?['cover']?.toString() ??
            widget.seriesChannel.logoUrl,
        group: widget.seriesChannel.group,
      );
    }).toList();

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => VideoPlayerScreen(
          channels: channels,
          initialIndex: index,
          isLive: false,
          restoreToLandscape: true,
        ),
      ),
    ).then((_) {
      SystemChrome.setPreferredOrientations([
        DeviceOrientation.landscapeLeft,
        DeviceOrientation.landscapeRight,
      ]);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(gradient: AppTheme.bgGradient),
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: SafeArea(
          child: _isLoading
              ? const Center(
                  child: CircularProgressIndicator(color: AppTheme.accent),
                )
              : _error != null
                  ? _buildErrorState()
                  : _buildSplitLayout(),
        ),
      ),
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.error_outline_rounded, color: AppTheme.error, size: 48),
          const SizedBox(height: 16),
          Text(
            _error!,
            style: GoogleFonts.inter(color: Colors.white, fontSize: 16),
          ),
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: () {
              setState(() {
                _isLoading = true;
                _error = null;
              });
              _fetchSeriesInfo();
            },
            child: const Text('Retry'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Go Back', style: TextStyle(color: Colors.white70)),
          ),
        ],
      ),
    );
  }

  Widget _buildSplitLayout() {
    final coverUrl = _info?['cover']?.toString() ?? widget.seriesChannel.logoUrl;
    final plot = _info?['plot']?.toString() ?? 'No description available.';
    final cast = _info?['cast']?.toString() ?? 'Unknown cast';
    final rating = _info?['rating']?.toString() ?? 'N/A';
    final releaseDate = _info?['releaseDate']?.toString() ?? '';

    return Row(
      children: [
        // ── LEFT SIDE: INFO PANE ──
        Expanded(
          flex: 2,
          child: Container(
            color: Colors.black.withValues(alpha: 0.4),
            child: CustomScrollView(
              slivers: [
                SliverAppBar(
                  backgroundColor: Colors.transparent,
                  expandedHeight: 250,
                  pinned: true,
                  leading: IconButton(
                    icon: const Icon(Icons.arrow_back_ios_rounded, color: Colors.white),
                    onPressed: () => Navigator.pop(context),
                  ),
                  flexibleSpace: FlexibleSpaceBar(
                    background: Stack(
                      fit: StackFit.expand,
                      children: [
                        if (coverUrl.isNotEmpty) ...[
                          CachedNetworkImage(
                            imageUrl: coverUrl,
                            fit: BoxFit.cover,
                            errorWidget: (context, url, error) => const SizedBox(),
                          ),
                          Container(
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                                colors: [
                                  Colors.transparent,
                                  Colors.black.withValues(alpha: 0.9),
                                ],
                              ),
                            ),
                          ),
                        ],
                        Positioned(
                          bottom: 16,
                          left: 16,
                          right: 16,
                          child: Text(
                            widget.seriesChannel.name,
                            style: GoogleFonts.outfit(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                              shadows: [
                                const Shadow(color: Colors.black, blurRadius: 8),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                SliverPadding(
                  padding: const EdgeInsets.all(20),
                  sliver: SliverList(
                    delegate: SliverChildListDelegate([
                      Row(
                        children: [
                          const Icon(Icons.star_rounded, color: AppTheme.gold, size: 18),
                          const SizedBox(width: 4),
                          Text(
                            rating,
                            style: GoogleFonts.inter(color: Colors.white, fontSize: 14),
                          ),
                          if (releaseDate.isNotEmpty) ...[
                            const SizedBox(width: 16),
                            const Icon(Icons.calendar_today_rounded,
                                color: AppTheme.textMuted, size: 14),
                            const SizedBox(width: 4),
                            Text(
                              releaseDate,
                              style: GoogleFonts.inter(color: Colors.white70, fontSize: 13),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 20),
                      Text(
                        'Synopsis',
                        style: GoogleFonts.outfit(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.accent,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        plot,
                        style: GoogleFonts.inter(
                          fontSize: 14,
                          color: AppTheme.textSecondary,
                          height: 1.5,
                        ),
                      ),
                      const SizedBox(height: 20),
                      Text(
                        'Cast',
                        style: GoogleFonts.outfit(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.accent,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        cast,
                        style: GoogleFonts.inter(
                          fontSize: 14,
                          color: AppTheme.textSecondary,
                          height: 1.5,
                        ),
                      ),
                    ]),
                  ),
                ),
              ],
            ),
          ),
        ),

        // ── RIGHT SIDE: SEASONS & EPISODES ──
        Expanded(
          flex: 3,
          child: Column(
            children: [
              // Season Selector
              Container(
                height: 60,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                decoration: BoxDecoration(
                  border: Border(
                    bottom: BorderSide(color: AppTheme.surfaceBorder.withValues(alpha: 0.5)),
                  ),
                ),
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  itemCount: _seasons.length,
                  itemBuilder: (context, index) {
                    final season = _seasons[index];
                    final isSelected = season == _selectedSeason;
                    return GestureDetector(
                      onTap: () => setState(() => _selectedSeason = season),
                      child: Container(
                        margin: const EdgeInsets.only(right: 12, top: 12, bottom: 12),
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? AppTheme.accent.withValues(alpha: 0.2)
                              : AppTheme.bgCard,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: isSelected ? AppTheme.accent : AppTheme.surfaceBorder,
                          ),
                        ),
                        child: Center(
                          child: Text(
                            'Season $season',
                            style: GoogleFonts.inter(
                              color: isSelected ? AppTheme.accent : Colors.white,
                              fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),

              // Episodes List
              Expanded(
                child: _selectedSeason == null
                    ? const Center(child: Text('No episodes found.', style: TextStyle(color: Colors.white)))
                    : ListView.builder(
                        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
                        itemCount: _episodesBySeason[_selectedSeason!]!.length,
                        itemBuilder: (context, index) {
                          final episode = _episodesBySeason[_selectedSeason!]![index];
                          final epMap = Map<String, dynamic>.from(episode);
                          
                          final title = epMap['title']?.toString() ?? 'Episode ${epMap['episode_num']}';
                          final duration = epMap['info']?['duration']?.toString() ?? '';
                          // We could parse cover string from `info.movie_image` but fallback to series cover
                          final epCover = epMap['info']?['movie_image']?.toString();

                          return Container(
                            margin: const EdgeInsets.only(bottom: 8),
                            decoration: BoxDecoration(
                              color: AppTheme.bgCard.withValues(alpha: 0.5),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: AppTheme.surfaceBorder.withValues(alpha: 0.3)),
                            ),
                            child: ListTile(
                              contentPadding: const EdgeInsets.all(8),
                              leading: ClipRRect(
                                borderRadius: BorderRadius.circular(8),
                                child: epCover != null && epCover.isNotEmpty
                                    ? CachedNetworkImage(
                                        imageUrl: epCover,
                                        width: 80,
                                        height: 50,
                                        fit: BoxFit.cover,
                                        errorWidget: (_, __, ___) => _buildFallbackCover(),
                                      )
                                    : _buildFallbackCover(),
                              ),
                              title: Text(
                                title,
                                style: GoogleFonts.outfit(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w500,
                                  color: Colors.white,
                                ),
                              ),
                              subtitle: RichText(
                                text: TextSpan(
                                  children: [
                                    TextSpan(
                                      text: 'Ep ${epMap['episode_num']} ',
                                      style: GoogleFonts.inter(color: AppTheme.accent, fontSize: 12),
                                    ),
                                    if (duration.isNotEmpty)
                                      TextSpan(
                                        text: ' • $duration',
                                        style: GoogleFonts.inter(color: AppTheme.textMuted, fontSize: 12),
                                      ),
                                  ],
                                ),
                              ),
                              trailing: IconButton(
                                icon: const Icon(Icons.play_circle_fill_rounded, color: AppTheme.accent, size: 36),
                                onPressed: () => _playEpisode(index, _episodesBySeason[_selectedSeason!]!),
                              ),
                              onTap: () => _playEpisode(index, _episodesBySeason[_selectedSeason!]!),
                            ),
                          );
                        },
                      ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildFallbackCover() {
    return Container(
      width: 80,
      height: 50,
      color: Colors.white10,
      child: const Icon(Icons.movie_rounded, color: Colors.white30),
    );
  }
}
