import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:provider/provider.dart';
import '../providers/playlist_provider.dart';
import '../services/ad_manager.dart';
import '../theme/app_theme.dart';
import '../models/playlist.dart';
import '../widgets/pro_loading_overlay.dart';
import 'add_playlist_screen.dart';
import 'main_player_screen.dart';
import 'settings_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with TickerProviderStateMixin {
  late AnimationController _fadeController;
  late Animation<double> _fadeAnimation;
  BannerAd? _bannerAd;
  bool _isBannerAdLoaded = false;

  @override
  void initState() {
    super.initState();
    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _fadeAnimation = CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeOut,
    );
    _fadeController.forward();

    // Enforce portrait mode initially
    SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);

    _loadBannerAd();
  }

  void _loadBannerAd() {
    final String adUnitId = 'ca-app-pub-9283129936552011/8716013901';

    _bannerAd = BannerAd(
      adUnitId: adUnitId,
      size: AdSize.banner,
      request: const AdRequest(),
      listener: BannerAdListener(
        onAdLoaded: (_) {
          if (mounted) {
            setState(() {
              _isBannerAdLoaded = true;
            });
          }
        },
        onAdFailedToLoad: (ad, error) {
          debugPrint('BannerAd failed to load: $error');
          ad.dispose();
        },
      ),
    )..load();
  }

  @override
  void dispose() {
    _fadeController.dispose();
    _bannerAd?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      bottomNavigationBar: _isBannerAdLoaded && _bannerAd != null
          ? SafeArea(
              child: SizedBox(
                width: _bannerAd!.size.width.toDouble(),
                height: _bannerAd!.size.height.toDouble(),
                child: AdWidget(ad: _bannerAd!),
              ),
            )
          : null,
      body: SafeArea(
        child: FadeTransition(
          opacity: _fadeAnimation,
          child: CustomScrollView(
            slivers: [
              // ── Header ──
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(24, 24, 24, 8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              gradient: AppTheme.primaryGradient,
                              borderRadius: BorderRadius.circular(16),
                              boxShadow: [
                                BoxShadow(
                                  color: AppTheme.primary.withValues(
                                    alpha: 0.3,
                                  ),
                                  blurRadius: 20,
                                  offset: const Offset(0, 8),
                                ),
                              ],
                            ),
                            child: const Icon(
                              Icons.live_tv_rounded,
                              color: Colors.white,
                              size: 28,
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Smarters Pro: Premium IPTV',
                                  style: GoogleFonts.outfit(
                                    fontSize: 22,
                                    fontWeight: FontWeight
                                        .w600, // Medium/SemiBold often looks more "pro" than Bold
                                    color: AppTheme.textPrimary,
                                    letterSpacing:
                                        -0.5, // Tight letter spacing for modern headings
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'Stream your favorite channels',
                                  style: GoogleFonts.outfit(
                                    // Using Outfit here too for consistency
                                    fontSize: 14,
                                    fontWeight: FontWeight.w400,
                                    color: AppTheme.textSecondary.withValues(
                                      alpha: 0.8,
                                    ),
                                    letterSpacing:
                                        0.2, // Slightly more open for sub-text
                                  ),
                                ),
                              ],
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.settings_rounded, color: Colors.white),
                            onPressed: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => const SettingsScreen(),
                                ),
                              );
                            },
                          ),
                        ],
                      ),
                      const SizedBox(height: 32),

                      // ── Quick Actions ──
                      Text(
                        'Add Playlist',
                        style: GoogleFonts.outfit(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],
                  ),
                ),
              ),

              // ── 3 Input Options ──
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Column(
                    children: [
                      _buildOptionCard(
                        icon: Icons.link_rounded,
                        title: 'M3U URL',
                        subtitle: 'Load playlist from web URL',
                        gradient: const LinearGradient(
                          colors: [Color(0xFF6C5CE7), Color(0xFF8B7FF0)],
                        ),
                        onTap: () => _navigateToAddPlaylist(context, 0),
                      ),
                      const SizedBox(height: 12),
                      _buildOptionCard(
                        icon: Icons.folder_open_rounded,
                        title: 'Local File',
                        subtitle: 'Import .m3u file from device',
                        gradient: const LinearGradient(
                          colors: [Color(0xFF00D2FF), Color(0xFF00F5A0)],
                        ),
                        onTap: () => _navigateToAddPlaylist(context, 1),
                      ),
                      const SizedBox(height: 12),
                      _buildOptionCard(
                        icon: Icons.dns_rounded,
                        title: 'Xtream Codes',
                        subtitle: 'Connect with server credentials',
                        gradient: const LinearGradient(
                          colors: [Color(0xFFFF6B6B), Color(0xFFFF8E53)],
                        ),
                        onTap: () => _navigateToAddPlaylist(context, 2),
                      ),
                    ],
                  ),
                ),
              ),

              const SliverToBoxAdapter(child: SizedBox(height: 32)),

              // ── Saved Playlists ──
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'My Playlists',
                        style: GoogleFonts.outfit(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.textPrimary,
                        ),
                      ),
                      Consumer<PlaylistProvider>(
                        builder: (_, provider, __) => Text(
                          '${provider.playlists.length} saved',
                          style: GoogleFonts.inter(
                            fontSize: 14,
                            color: AppTheme.textMuted,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              const SliverToBoxAdapter(child: SizedBox(height: 12)),

              // ── Playlist List ──
              Consumer<PlaylistProvider>(
                builder: (context, provider, child) {
                  if (provider.playlists.isEmpty) {
                    return SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.all(40),
                        child: Column(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(24),
                              decoration: BoxDecoration(
                                color: AppTheme.bgElevated,
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.playlist_add_rounded,
                                size: 48,
                                color: AppTheme.textMuted,
                              ),
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'No playlists yet',
                              style: GoogleFonts.outfit(
                                fontSize: 18,
                                fontWeight: FontWeight.w500,
                                color: AppTheme.textSecondary,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Add a playlist to start streaming',
                              style: GoogleFonts.inter(
                                fontSize: 14,
                                color: AppTheme.textMuted,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  }

                  return SliverList(
                    delegate: SliverChildBuilderDelegate((context, index) {
                      final playlist = provider.playlists[index];
                      return Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 24,
                          vertical: 4,
                        ),
                        child: _buildPlaylistTile(context, playlist),
                      );
                    }, childCount: provider.playlists.length),
                  );
                },
              ),

              const SliverToBoxAdapter(child: SizedBox(height: 100)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildOptionCard({
    required IconData icon,
    required String title,
    required String subtitle,
    required LinearGradient gradient,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: AppTheme.bgCard,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppTheme.surfaceBorder),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  gradient: gradient,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: gradient.colors.first.withValues(alpha: 0.3),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Icon(icon, color: Colors.white, size: 24),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: GoogleFonts.outfit(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        color: AppTheme.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(
                Icons.arrow_forward_ios_rounded,
                size: 16,
                color: AppTheme.textMuted,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPlaylistTile(BuildContext context, Playlist playlist) {
    final IconData typeIcon;
    final Color iconColor;

    switch (playlist.type) {
      case PlaylistType.m3uUrl:
        typeIcon = Icons.link_rounded;
        iconColor = AppTheme.primary;
        break;
      case PlaylistType.localFile:
        typeIcon = Icons.folder_open_rounded;
        iconColor = AppTheme.accent;
        break;
      case PlaylistType.xtream:
        typeIcon = Icons.dns_rounded;
        iconColor = const Color(0xFFFF6B6B);
        break;
    }

    return Dismissible(
      key: Key(playlist.id),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        decoration: BoxDecoration(
          color: AppTheme.error.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(16),
        ),
        child: const Icon(Icons.delete_rounded, color: AppTheme.error),
      ),
      onDismissed: (_) {
        context.read<PlaylistProvider>().deletePlaylist(playlist.id);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('${playlist.name} deleted')));
      },
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () => _openPlaylist(context, playlist),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppTheme.bgCard,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppTheme.surfaceBorder),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: iconColor.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(typeIcon, color: iconColor, size: 22),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        playlist.name,
                        style: GoogleFonts.outfit(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.textPrimary,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 3),
                      Text(
                        playlist.type == PlaylistType.xtream
                            ? 'Xtream Codes'
                            : playlist.type == PlaylistType.m3uUrl
                            ? 'M3U URL'
                            : 'Local File',
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          color: AppTheme.textMuted,
                        ),
                      ),
                    ],
                  ),
                ),
                PopupMenuButton<String>(
                  icon: const Icon(
                    Icons.more_vert_rounded,
                    color: AppTheme.textSecondary,
                  ),
                  color: AppTheme.bgElevated,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                    side: const BorderSide(color: AppTheme.surfaceBorder),
                  ),
                  onSelected: (value) {
                    if (value == 'rename') {
                      _showRenameDialog(context, playlist);
                    } else if (value == 'delete') {
                      _showDeleteDialog(context, playlist);
                    }
                  },
                  itemBuilder: (context) => [
                    PopupMenuItem(
                      value: 'rename',
                      child: Row(
                        children: [
                          const Icon(
                            Icons.edit_rounded,
                            color: AppTheme.textPrimary,
                            size: 20,
                          ),
                          const SizedBox(width: 12),
                          Text(
                            'Rename',
                            style: GoogleFonts.inter(
                              color: AppTheme.textPrimary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    PopupMenuItem(
                      value: 'delete',
                      child: Row(
                        children: [
                          const Icon(
                            Icons.delete_rounded,
                            color: AppTheme.error,
                            size: 20,
                          ),
                          const SizedBox(width: 12),
                          Text(
                            'Delete',
                            style: GoogleFonts.inter(color: AppTheme.error),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _navigateToAddPlaylist(BuildContext context, int initialTab) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => AddPlaylistScreen(initialTab: initialTab),
      ),
    );
  }

  void _showDeleteDialog(BuildContext context, Playlist playlist) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.bgElevated,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          'Delete Playlist',
          style: GoogleFonts.outfit(color: Colors.white),
        ),
        content: Text(
          'Are you sure you want to delete "${playlist.name}"?',
          style: GoogleFonts.inter(color: AppTheme.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(
              'Cancel',
              style: GoogleFonts.inter(color: AppTheme.textPrimary),
            ),
          ),
          TextButton(
            onPressed: () {
              context.read<PlaylistProvider>().deletePlaylist(playlist.id);
              Navigator.pop(ctx);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('${playlist.name} deleted')),
              );
            },
            child: Text(
              'Delete',
              style: GoogleFonts.inter(color: AppTheme.error),
            ),
          ),
        ],
      ),
    );
  }

  void _showRenameDialog(BuildContext context, Playlist playlist) {
    final controller = TextEditingController(text: playlist.name);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.bgElevated,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          'Rename Playlist',
          style: GoogleFonts.outfit(color: Colors.white),
        ),
        content: TextField(
          controller: controller,
          style: GoogleFonts.inter(color: Colors.white),
          decoration: InputDecoration(
            hintText: 'Playlist Name',
            hintStyle: GoogleFonts.inter(color: AppTheme.textMuted),
            filled: true,
            fillColor: AppTheme.bgCard,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: AppTheme.gold),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(
              'Cancel',
              style: GoogleFonts.inter(color: AppTheme.textPrimary),
            ),
          ),
          TextButton(
            onPressed: () {
              final newName = controller.text.trim();
              if (newName.isNotEmpty) {
                context.read<PlaylistProvider>().renamePlaylist(
                  playlist.id,
                  newName,
                );
              }
              Navigator.pop(ctx);
            },
            child: Text('Save', style: GoogleFonts.inter(color: AppTheme.gold)),
          ),
        ],
      ),
    );
  }

  void _openPlaylist(BuildContext context, Playlist playlist) async {
    // Show a pro loading indicator
    showDialog(
      context: context,
      barrierDismissible: false,
      barrierColor: Colors.transparent,
      builder: (_) => ProLoadingOverlay(
        subtitle: 'Fetching channels for\n"${playlist.name}"',
      ),
    );

    final provider = context.read<PlaylistProvider>();
    await provider.loadPlaylist(playlist);

    if (context.mounted) {
      // Dismiss the loading indicator
      Navigator.pop(context);

      if (provider.error != null) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(provider.error!)));
      } else {
        AdManager.instance.showInterstitialAd(
          onAdClosed: () {
            if (context.mounted) {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const MainPlayerScreen()),
              ).then((_) {
                // Ensure we return to portrait when coming back from the player
                SystemChrome.setPreferredOrientations([
                  DeviceOrientation.portraitUp,
                ]);
                SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
              });
            }
          },
        );
      }
    }
  }
}
