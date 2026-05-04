import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../providers/playlist_provider.dart';
import '../models/channel.dart';
import '../theme/app_theme.dart';
import '../widgets/channel_card.dart';
import '../widgets/category_chips.dart';
import 'video_player_screen.dart';

class ChannelsListScreen extends StatefulWidget {
  const ChannelsListScreen({super.key});

  @override
  State<ChannelsListScreen> createState() => _ChannelsListScreenState();
}

class _ChannelsListScreenState extends State<ChannelsListScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  bool _isGridView = true;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Consumer<PlaylistProvider>(
          builder: (_, provider, __) => Text(
            provider.currentPlaylist?.name ?? 'Channels',
            style: GoogleFonts.outfit(fontWeight: FontWeight.w600),
          ),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_rounded),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(
            icon: Icon(
              _isGridView ? Icons.view_list_rounded : Icons.grid_view_rounded,
              color: AppTheme.textSecondary,
            ),
            onPressed: () => setState(() => _isGridView = !_isGridView),
          ),
        ],
      ),
      body: Column(
        children: [
          // ── Search Bar ──
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
            child: Container(
              decoration: BoxDecoration(
                color: AppTheme.bgInput,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppTheme.surfaceBorder),
              ),
              child: TextField(
                controller: _searchController,
                onChanged: (value) => setState(() => _searchQuery = value),
                decoration: InputDecoration(
                  hintText: 'Search channels...',
                  prefixIcon: const Icon(Icons.search_rounded, color: AppTheme.textMuted),
                  suffixIcon: _searchQuery.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear_rounded, color: AppTheme.textMuted),
                          onPressed: () {
                            _searchController.clear();
                            setState(() => _searchQuery = '');
                          },
                        )
                      : null,
                  border: InputBorder.none,
                  enabledBorder: InputBorder.none,
                  focusedBorder: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 14,
                  ),
                ),
                style: GoogleFonts.inter(color: AppTheme.textPrimary, fontSize: 15),
              ),
            ),
          ),

          // ── Category Chips ──
          Consumer<PlaylistProvider>(
            builder: (context, provider, _) {
              if (provider.categories.length <= 1) return const SizedBox.shrink();
              return CategoryChips(
                categories: provider.categories,
                selected: provider.selectedCategory,
                onSelected: (cat) => provider.setCategory(cat),
              );
            },
          ),

          const SizedBox(height: 8),

          // ── Channel Count ──
          Consumer<PlaylistProvider>(
            builder: (context, provider, _) {
              final channels = provider.searchChannels(_searchQuery);
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      '${channels.length} channels',
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        color: AppTheme.textMuted,
                      ),
                    ),
                    if (provider.selectedCategory != 'All')
                      GestureDetector(
                        onTap: () => provider.setCategory('All'),
                        child: Text(
                          'Show all',
                          style: GoogleFonts.inter(
                            fontSize: 13,
                            color: AppTheme.accent,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                  ],
                ),
              );
            },
          ),

          const SizedBox(height: 12),

          // ── Channel Grid/List ──
          Expanded(
            child: Consumer<PlaylistProvider>(
              builder: (context, provider, _) {
                if (provider.isLoading) {
                  return const Center(
                    child: CircularProgressIndicator(color: AppTheme.primary),
                  );
                }

                final channels = provider.searchChannels(_searchQuery);

                if (channels.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.search_off_rounded,
                          size: 64,
                          color: AppTheme.textMuted,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'No channels found',
                          style: GoogleFonts.outfit(
                            fontSize: 18,
                            fontWeight: FontWeight.w500,
                            color: AppTheme.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  );
                }

                if (_isGridView) {
                  return GridView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      childAspectRatio: 1.1,
                      crossAxisSpacing: 12,
                      mainAxisSpacing: 12,
                    ),
                    itemCount: channels.length,
                    itemBuilder: (context, index) {
                      return ChannelCard(
                        channel: channels[index],
                        isGrid: true,
                        onTap: () => _playChannel(context, channels, index),
                      );
                    },
                  );
                } else {
                  return ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    itemCount: channels.length,
                    itemBuilder: (context, index) {
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: ChannelCard(
                          channel: channels[index],
                          isGrid: false,
                          onTap: () => _playChannel(context, channels, index),
                        ),
                      );
                    },
                  );
                }
              },
            ),
          ),
        ],
      ),
    );
  }

  void _playChannel(BuildContext context, List<Channel> channels, int index) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => VideoPlayerScreen(
          channels: channels,
          initialIndex: index,
          isLive: true,
        ),
      ),
    );
  }
}
