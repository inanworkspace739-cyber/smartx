import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../models/channel.dart';
import '../theme/app_theme.dart';
import 'glass_container.dart';

class ChannelCard extends StatelessWidget {
  final Channel channel;
  final bool isGrid;
  final bool isFavorite;
  final VoidCallback onTap;
  final VoidCallback? onToggleFavorite;

  const ChannelCard({
    super.key,
    required this.channel,
    required this.isGrid,
    this.isFavorite = false,
    required this.onTap,
    this.onToggleFavorite,
  });

  @override
  Widget build(BuildContext context) {
    if (isGrid) return _buildGridCard();
    return _buildListTile();
  }

  Widget _buildGridCard() {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: GlassContainer(
          child: Stack(
            children: [
              // Content
              Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      width: 56,
                      height: 56,
                      decoration: BoxDecoration(
                        color: AppTheme.bgElevated,
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: _buildLogo(size: 56),
                    ),
                    const SizedBox(height: 12),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      child: Text(
                        channel.name,
                        textAlign: TextAlign.center,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.outfit(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.textPrimary,
                        ),
                      ),
                    ),
                    const SizedBox(height: 4),
                    if (channel.group.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        child: Text(
                          channel.group,
                          textAlign: TextAlign.center,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.inter(
                            fontSize: 11,
                            color: AppTheme.textMuted,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              // Favorite button
              if (onToggleFavorite != null)
                Positioned(
                  top: 6,
                  right: 6,
                  child: GestureDetector(
                    onTap: onToggleFavorite,
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.3),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        isFavorite
                            ? Icons.favorite_rounded
                            : Icons.favorite_border_rounded,
                        color: isFavorite ? Colors.redAccent : Colors.white70,
                        size: 16,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildListTile() {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: GlassContainer(
          padding: const EdgeInsets.all(12),
          borderRadius: 14,
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: AppTheme.bgElevated,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: _buildLogo(size: 48),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      channel.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.outfit(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.textPrimary,
                      ),
                    ),
                    if (channel.group.isNotEmpty) ...[
                      const SizedBox(height: 3),
                      Text(
                        channel.group,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          color: AppTheme.textMuted,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              // Favorite button
              if (onToggleFavorite != null)
                GestureDetector(
                  onTap: onToggleFavorite,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: Icon(
                      isFavorite
                          ? Icons.favorite_rounded
                          : Icons.favorite_border_rounded,
                      color: isFavorite ? Colors.redAccent : AppTheme.textMuted,
                      size: 20,
                    ),
                  ),
                ),
              const SizedBox(width: 4),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppTheme.primary.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.play_arrow_rounded,
                  color: AppTheme.primary,
                  size: 22,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLogo({required double size}) {
    if (channel.logoUrl.isNotEmpty) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(size == 56 ? 14 : 12),
        child: CachedNetworkImage(
          imageUrl: channel.logoUrl,
          width: size,
          height: size,
          fit: BoxFit.cover,
          placeholder: (_, __) => _buildPlaceholderIcon(size),
          errorWidget: (_, __, ___) => _buildPlaceholderIcon(size),
        ),
      );
    }
    return _buildPlaceholderIcon(size);
  }

  Widget _buildPlaceholderIcon(double size) {
    return Center(
      child: Icon(
        Icons.live_tv_rounded,
        color: AppTheme.textMuted,
        size: size * 0.45,
      ),
    );
  }
}
