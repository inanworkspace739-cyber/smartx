import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:provider/provider.dart';
import '../providers/playlist_provider.dart';
import '../services/ad_manager.dart';
import '../theme/app_theme.dart';
import '../widgets/glass_container.dart';
import '../widgets/pro_loading_overlay.dart';
import 'main_player_screen.dart';

class AddPlaylistScreen extends StatefulWidget {
  final int initialTab;

  const AddPlaylistScreen({super.key, this.initialTab = 0});

  @override
  State<AddPlaylistScreen> createState() => _AddPlaylistScreenState();
}

class _AddPlaylistScreenState extends State<AddPlaylistScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  // M3U URL Controllers
  final _m3uNameController = TextEditingController();
  final _m3uUrlController = TextEditingController();

  // Xtream Controllers
  final _xtreamNameController = TextEditingController();
  final _xtreamServerController = TextEditingController();
  final _xtreamUsernameController = TextEditingController();
  final _xtreamPasswordController = TextEditingController();

  bool _obscurePassword = true;

  NativeAd? _nativeAd;
  bool _isNativeAdLoaded = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(
      length: 3,
      vsync: this,
      initialIndex: widget.initialTab,
    );
    _loadNativeAd();
    AdManager.instance.loadRewardedAd();
  }

  void _loadNativeAd() {
    final nativeAdUnitId = 'ca-app-pub-9283129936552011/5838471060';

    _nativeAd = NativeAd(
      adUnitId: nativeAdUnitId,
      request: const AdRequest(),
      listener: NativeAdListener(
        onAdLoaded: (Ad ad) {
          if (mounted) {
            setState(() {
              _isNativeAdLoaded = true;
            });
          }
        },
        onAdFailedToLoad: (Ad ad, LoadAdError error) {
          debugPrint('NativeAd failed to load: $error');
          ad.dispose();
        },
      ),
      nativeTemplateStyle: NativeTemplateStyle(
        templateType: TemplateType.medium,
        mainBackgroundColor: AppTheme.bgCard,
        cornerRadius: 12.0,
        callToActionTextStyle: NativeTemplateTextStyle(
          textColor: Colors.white,
          backgroundColor: AppTheme.primary,
          style: NativeTemplateFontStyle.bold,
          size: 16.0,
        ),
        primaryTextStyle: NativeTemplateTextStyle(
          textColor: Colors.white,
          backgroundColor: Colors.transparent,
          style: NativeTemplateFontStyle.bold,
          size: 16.0,
        ),
        secondaryTextStyle: NativeTemplateTextStyle(
          textColor: AppTheme.textSecondary,
          backgroundColor: Colors.transparent,
          style: NativeTemplateFontStyle.normal,
          size: 14.0,
        ),
        tertiaryTextStyle: NativeTemplateTextStyle(
          textColor: AppTheme.textMuted,
          backgroundColor: Colors.transparent,
          style: NativeTemplateFontStyle.normal,
          size: 14.0,
        ),
      ),
    )..load();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _m3uNameController.dispose();
    _m3uUrlController.dispose();
    _xtreamNameController.dispose();
    _xtreamServerController.dispose();
    _xtreamUsernameController.dispose();
    _xtreamPasswordController.dispose();
    _nativeAd?.dispose();
    super.dispose();
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(
              Icons.error_outline_rounded,
              color: Colors.white,
              size: 20,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                message,
                style: GoogleFonts.inter(fontSize: 14, color: Colors.white),
              ),
            ),
          ],
        ),
        backgroundColor: AppTheme.error.withValues(alpha: 0.9),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(16),
        duration: const Duration(seconds: 4),
      ),
    );
  }

  void _showSuccess(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(
              Icons.check_circle_rounded,
              color: Colors.white,
              size: 20,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                message,
                style: GoogleFonts.inter(fontSize: 14, color: Colors.white),
              ),
            ),
          ],
        ),
        backgroundColor: AppTheme.success.withValues(alpha: 0.9),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(16),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Must read viewInsets BEFORE the Scaffold, because Scaffold zeros it out in the body context
    final isKeyboardVisible = MediaQuery.viewInsetsOf(context).bottom > 0;
    final isScreenTallEnough = MediaQuery.sizeOf(context).height > 500;
    return Container(
      decoration: const BoxDecoration(gradient: AppTheme.bgGradient),
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          title: Text(
            'Add Playlist',
            style: GoogleFonts.outfit(
              fontWeight: FontWeight.w600,
              letterSpacing: -0.5,
            ),
          ),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios_rounded),
            onPressed: () => Navigator.pop(context),
          ),
          bottom: TabBar(
            controller: _tabController,
            indicatorColor: AppTheme.primary,
            indicatorWeight: 3,
            labelColor: AppTheme.textPrimary,
            unselectedLabelColor: AppTheme.textMuted,
            labelStyle: GoogleFonts.outfit(
              fontWeight: FontWeight.w600,
              fontSize: 14,
              letterSpacing: 0.1,
            ),
            unselectedLabelStyle: GoogleFonts.outfit(
              fontSize: 14,
              fontWeight: FontWeight.w400,
              letterSpacing: 0.1,
            ),
            tabs: const [
              Tab(text: 'M3U URL'),
              Tab(text: 'Local File'),
              Tab(text: 'Xtream'),
            ],
          ),
        ),
        body: Consumer<PlaylistProvider>(
          builder: (context, provider, _) {
            return Stack(
              children: [
                Column(
                  children: [
                    Expanded(
                      child: TabBarView(
                        controller: _tabController,
                        children: [
                          _buildM3uUrlTab(provider),
                          _buildLocalFileTab(provider),
                          _buildXtreamTab(provider),
                        ],
                      ),
                    ),
                    if (_isNativeAdLoaded &&
                        _nativeAd != null &&
                        !isKeyboardVisible &&
                        isScreenTallEnough)
                      Container(
                        height:
                            320, // TemplateType.medium requires larger height to accommodate video media view safely
                        margin: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 8,
                        ).copyWith(bottom: 24),
                        child: AdWidget(ad: _nativeAd!),
                      ),
                  ],
                ),
                if (provider.isLoading)
                  const Positioned.fill(
                    child: ProLoadingOverlay(
                      title: 'Loading Playlist...',
                      subtitle: 'Fetching channels and categories...',
                    ),
                  ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildM3uUrlTab(PlaylistProvider provider) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 8),
          _buildLabel('Playlist Name'),
          const SizedBox(height: 8),
          TextField(
            controller: _m3uNameController,
            decoration: const InputDecoration(
              hintText: 'e.g. My IPTV',
              prefixIcon: Icon(Icons.edit_rounded, color: AppTheme.textMuted),
            ),
            style: GoogleFonts.inter(color: AppTheme.textPrimary),
          ),
          const SizedBox(height: 24),
          _buildLabel('M3U Playlist URL'),
          const SizedBox(height: 8),
          TextField(
            controller: _m3uUrlController,
            decoration: const InputDecoration(
              hintText: 'http://example.com/playlist.m3u',
              prefixIcon: Icon(Icons.link_rounded, color: AppTheme.textMuted),
            ),
            style: GoogleFonts.inter(color: AppTheme.textPrimary),
            keyboardType: TextInputType.url,
          ),
          const SizedBox(height: 32),
          _buildSubmitButton(
            label: 'Load Playlist',
            icon: Icons.download_rounded,
            onPressed: () => _loadM3uUrl(provider),
          ),
        ],
      ),
    );
  }

  Widget _buildLocalFileTab(PlaylistProvider provider) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          const SizedBox(height: 40),
          GestureDetector(
            onTap: () => _pickLocalFile(provider),
            child: GlassContainer(
              padding: const EdgeInsets.symmetric(vertical: 60),
              borderRadius: 20,
              border: Border.all(
                color: AppTheme.accent.withValues(alpha: 0.3),
                width: 2,
              ),
              child: Column(
                children: [
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      gradient: AppTheme.accentGradient,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: AppTheme.accent.withValues(alpha: 0.3),
                          blurRadius: 20,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    child: const Icon(
                      Icons.upload_file_rounded,
                      color: Colors.white,
                      size: 40,
                    ),
                  ),
                  const SizedBox(height: 24),
                  Text(
                    'Tap to browse files',
                    style: GoogleFonts.outfit(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Supports .m3u and .m3u8 files',
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      color: AppTheme.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildXtreamTab(PlaylistProvider provider) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 8),
          _buildLabel('Playlist Name'),
          const SizedBox(height: 8),
          TextField(
            controller: _xtreamNameController,
            decoration: const InputDecoration(
              hintText: 'e.g. My Server',
              prefixIcon: Icon(Icons.edit_rounded, color: AppTheme.textMuted),
            ),
            style: GoogleFonts.inter(color: AppTheme.textPrimary),
          ),
          const SizedBox(height: 20),
          _buildLabel('Server URL'),
          const SizedBox(height: 8),
          TextField(
            controller: _xtreamServerController,
            decoration: const InputDecoration(
              hintText: 'http://server.com:port',
              prefixIcon: Icon(Icons.dns_rounded, color: AppTheme.textMuted),
            ),
            style: GoogleFonts.inter(color: AppTheme.textPrimary),
            keyboardType: TextInputType.url,
          ),
          const SizedBox(height: 20),
          _buildLabel('Username'),
          const SizedBox(height: 8),
          TextField(
            controller: _xtreamUsernameController,
            decoration: const InputDecoration(
              hintText: 'Your username',
              prefixIcon: Icon(Icons.person_rounded, color: AppTheme.textMuted),
            ),
            style: GoogleFonts.inter(color: AppTheme.textPrimary),
          ),
          const SizedBox(height: 20),
          _buildLabel('Password'),
          const SizedBox(height: 8),
          TextField(
            controller: _xtreamPasswordController,
            obscureText: _obscurePassword,
            decoration: InputDecoration(
              hintText: 'Your password',
              prefixIcon: const Icon(
                Icons.lock_rounded,
                color: AppTheme.textMuted,
              ),
              suffixIcon: IconButton(
                icon: Icon(
                  _obscurePassword
                      ? Icons.visibility_off_rounded
                      : Icons.visibility_rounded,
                  color: AppTheme.textMuted,
                ),
                onPressed: () =>
                    setState(() => _obscurePassword = !_obscurePassword),
              ),
            ),
            style: GoogleFonts.inter(color: AppTheme.textPrimary),
          ),
          const SizedBox(height: 32),
          _buildSubmitButton(
            label: 'Connect',
            icon: Icons.login_rounded,
            onPressed: () => _connectXtream(provider),
          ),
        ],
      ),
    );
  }

  Widget _buildLabel(String text) {
    return Text(
      text,
      style: GoogleFonts.outfit(
        fontSize: 14,
        fontWeight: FontWeight.w600,
        color: AppTheme.textSecondary,
      ),
    );
  }

  Widget _buildSubmitButton({
    required String label,
    required IconData icon,
    required VoidCallback onPressed,
  }) {
    return SizedBox(
      width: double.infinity,
      height: 56,
      child: Container(
        decoration: BoxDecoration(
          gradient: AppTheme.primaryGradient,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: AppTheme.primary.withValues(alpha: 0.4),
              blurRadius: 16,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: ElevatedButton.icon(
          onPressed: onPressed,
          icon: Icon(icon),
          label: Text(label),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.transparent,
            shadowColor: Colors.transparent,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _showSupportDialog(VoidCallback action) async {
    final confirmed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        child: GlassContainer(
          borderRadius: 24,
          padding: const EdgeInsets.all(28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(18),
                decoration: const BoxDecoration(
                  gradient: AppTheme.primaryGradient,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.favorite_rounded,
                  color: Colors.white,
                  size: 36,
                ),
              ),
              const SizedBox(height: 20),
              Text(
                'Support Us',
                style: GoogleFonts.outfit(
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.textPrimary,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'Watch a short ad to support the app and keep it free for everyone.',
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(
                  fontSize: 14,
                  color: AppTheme.textSecondary,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 28),
              SizedBox(
                width: double.infinity,
                child: Container(
                  decoration: BoxDecoration(
                    gradient: AppTheme.primaryGradient,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: AppTheme.primary.withValues(alpha: 0.4),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: ElevatedButton(
                    onPressed: () => Navigator.pop(ctx, true),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.transparent,
                      shadowColor: Colors.transparent,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    child: Text(
                      'Watch Ad',
                      style: GoogleFonts.outfit(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );

    if (!mounted) return;
    if (confirmed == true) {
      AdManager.instance.showRewardedAd(onClosed: action);
    }
  }

  void _loadM3uUrl(PlaylistProvider provider) {
    if (_m3uUrlController.text.trim().isEmpty) {
      _showError('Please enter a playlist URL');
      return;
    }
    _showSupportDialog(() => _doLoadM3uUrl(provider));
  }

  void _doLoadM3uUrl(PlaylistProvider provider) async {
    await provider.addM3uUrl(
      name: _m3uNameController.text.trim(),
      url: _m3uUrlController.text.trim(),
    );

    if (!mounted) return;

    if (provider.error != null) {
      _showError(provider.error!);
    } else {
      _showSuccess(
        'Playlist loaded — ${provider.channels.length} channels found!',
      );
      await Future.delayed(const Duration(milliseconds: 500));
      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const MainPlayerScreen()),
        );
      }
    }
  }

  void _pickLocalFile(PlaylistProvider provider) async {
    await provider.addLocalFile();

    if (!mounted) return;

    if (provider.error != null) {
      _showError(provider.error!);
    } else if (provider.channels.isNotEmpty) {
      _showSuccess('File loaded — ${provider.channels.length} channels found!');
      await Future.delayed(const Duration(milliseconds: 500));
      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const MainPlayerScreen()),
        );
      }
    }
  }

  void _connectXtream(PlaylistProvider provider) {
    if (_xtreamServerController.text.trim().isEmpty ||
        _xtreamUsernameController.text.trim().isEmpty ||
        _xtreamPasswordController.text.trim().isEmpty) {
      _showError('Please fill in all fields');
      return;
    }
    _showSupportDialog(() => _doConnectXtream(provider));
  }

  void _doConnectXtream(PlaylistProvider provider) async {
    await provider.addXtreamPlaylist(
      name: _xtreamNameController.text.trim(),
      serverUrl: _xtreamServerController.text.trim(),
      username: _xtreamUsernameController.text.trim(),
      password: _xtreamPasswordController.text.trim(),
    );

    if (!mounted) return;

    if (provider.error != null) {
      _showError(provider.error!);
    } else {
      _showSuccess('Connected — ${provider.channels.length} channels found!');
      await Future.delayed(const Duration(milliseconds: 500));
      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const MainPlayerScreen()),
        );
      }
    }
  }
}
