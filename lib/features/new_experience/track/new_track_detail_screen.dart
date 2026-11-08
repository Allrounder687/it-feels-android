import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:it_feels_music/data/models/song_model.dart';
import 'package:it_feels_music/core/music_identity/canonical_track.dart';
import 'package:it_feels_music/core/intelligence/federation/federated_music_intelligence_service.dart';
import 'package:it_feels_music/core/intelligence/analytics/music_dna_service.dart';
import 'package:it_feels_music/core/providers/riverpod_bridge.dart';
import '../theme/new_experience_tokens.dart';
import '../theme/new_ambient_canvas.dart';
import '../widgets/new_artwork_image.dart';
import '../widgets/new_glass_container.dart';
import '../widgets/new_section_header.dart';
import '../album/new_album_detail_screen.dart';
import '../artist/new_artist_detail_screen.dart';
import '../theme/content_viewport_insets.dart';

class NewTrackDetailScreen extends ConsumerStatefulWidget {
  final Song song;

  const NewTrackDetailScreen({
    super.key,
    required this.song,
  });

  @override
  ConsumerState<NewTrackDetailScreen> createState() => _NewTrackDetailScreenState();
}

class _NewTrackDetailScreenState extends ConsumerState<NewTrackDetailScreen> {
  final FederatedMusicIntelligenceService _fedService =
      FederatedMusicIntelligenceService();
  final MusicDnaService _dnaService = MusicDnaService();

  bool _isLoading = true;
  CanonicalTrack? _canonicalTrack;
  TrackPersonalInsights? _insights;

  @override
  void initState() {
    super.initState();
    _loadTrackIntelligence();
  }

  Future<void> _loadTrackIntelligence() async {
    try {
      final base = CanonicalTrack.fromSong(widget.song);
      final enriched = await _fedService.enrichTrack(base);
      final insights = await _dnaService.getTrackInsights(widget.song.title);

      if (mounted) {
        setState(() {
          _canonicalTrack = enriched;
          _insights = insights;
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final playerState = ref.watch(audioPlayerProvider);
    final hasSong = playerState.currentSong != null;

    return NewAmbientCanvas(
      intensity: 0.55,
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 20),
            onPressed: () => Navigator.of(context).pop(),
          ),
          title: Text(
            'Track Intelligence',
            style: GoogleFonts.outfit(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: NewExperienceTokens.textPrimary,
            ),
          ),
        ),
        body: _isLoading
            ? const Center(
                child: CircularProgressIndicator(color: NewExperienceTokens.accentCyan),
              )
            : CustomScrollView(
                physics: const BouncingScrollPhysics(),
                slivers: [
                  // ── Hero Track Header ──
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(NewExperienceTokens.radiusMedium),
                            child: NewArtworkImage(
                              imageUrl: widget.song.image,
                              width: 90,
                              height: 90,
                              fit: BoxFit.cover,
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  widget.song.title,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: GoogleFonts.outfit(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                    color: NewExperienceTokens.textPrimary,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                InkWell(
                                  onTap: () {
                                    Navigator.of(context).push(
                                      MaterialPageRoute(
                                        builder: (context) => NewArtistDetailScreen(
                                          artistName: widget.song.artist,
                                        ),
                                      ),
                                    );
                                  },
                                  child: Text(
                                    widget.song.artist,
                                    style: GoogleFonts.outfit(
                                      fontSize: 14,
                                      color: NewExperienceTokens.accentCyan,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 4),
                                if (widget.song.album.isNotEmpty)
                                  InkWell(
                                    onTap: () {
                                      Navigator.of(context).push(
                                        MaterialPageRoute(
                                          builder: (context) => NewAlbumDetailScreen(
                                            albumTitle: widget.song.album,
                                            artistName: widget.song.artist,
                                          ),
                                        ),
                                      );
                                    },
                                    child: Text(
                                      widget.song.album,
                                      style: const TextStyle(
                                        fontSize: 12,
                                        color: NewExperienceTokens.textMuted,
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  // ── Song Story ──
                  if (_canonicalTrack?.trackStory != null)
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                        child: NewGlassContainer(
                          borderRadius: NewExperienceTokens.radiusMedium,
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  const Icon(Icons.auto_stories_rounded, color: NewExperienceTokens.accentCyan, size: 18),
                                  const SizedBox(width: 8),
                                  Text(
                                    'Story Behind the Song',
                                    style: GoogleFonts.outfit(
                                      fontSize: 15,
                                      fontWeight: FontWeight.bold,
                                      color: NewExperienceTokens.textPrimary,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Text(
                                _canonicalTrack!.trackStory!,
                                style: NewExperienceTokens.bodyMedium(
                                  color: NewExperienceTokens.textSecondary,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),

                  // ── Personal Listening Insights ──
                  if (_insights != null)
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                        child: NewGlassContainer(
                          borderRadius: NewExperienceTokens.radiusMedium,
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  const Icon(Icons.analytics_outlined, color: NewExperienceTokens.accentViolet, size: 18),
                                  const SizedBox(width: 8),
                                  Text(
                                    'Personal Insights',
                                    style: GoogleFonts.outfit(
                                      fontSize: 15,
                                      fontWeight: FontWeight.bold,
                                      color: NewExperienceTokens.textPrimary,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceAround,
                                children: [
                                  _buildInsightPill('Plays', '${_insights!.playCount}'),
                                  _buildInsightPill('Skips', '${_insights!.skipCount}'),
                                  _buildInsightPill('Completion', '${_insights!.completionPercentage.toStringAsFixed(0)}%'),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),

                  // ── Recording Credits ──
                  const SliverToBoxAdapter(
                    child: Padding(
                      padding: EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                      child: NewSectionHeader(
                        title: 'Recording Credits',
                        actionLabel: 'Verified',
                      ),
                    ),
                  ),

                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: NewGlassContainer(
                        borderRadius: NewExperienceTokens.radiusMedium,
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        child: Column(
                          children: [
                            _buildCreditRow('Composer', _canonicalTrack?.composer ?? 'Not credited'),
                            const Divider(color: Colors.white10),
                            _buildCreditRow('Lyricist', _canonicalTrack?.lyricist ?? 'Not credited'),
                            const Divider(color: Colors.white10),
                            _buildCreditRow('ISRC', _canonicalTrack?.isrc ?? 'Not registered'),
                            const Divider(color: Colors.white10),
                            _buildCreditRow('Language', widget.song.language.toUpperCase()),
                            const Divider(color: Colors.white10),
                            _buildCreditRow('Duration', '${widget.song.duration} seconds'),
                            if (_canonicalTrack?.provenance != null) ...[
                              const Divider(color: Colors.white10),
                              _buildCreditRow('Source', _canonicalTrack!.provenance!.attribution),
                            ],
                          ],
                        ),
                      ),
                    ),
                  ),

                  // Bottom Clearance
                  ContentViewportInsets.sliverBottomSpacer(context, ref),
                ],
              ),
      ),
    );
  }

  Widget _buildInsightPill(String label, String value) {
    return Column(
      children: [
        Text(
          value,
          style: GoogleFonts.outfit(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: NewExperienceTokens.textPrimary,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: NewExperienceTokens.eyebrowLabel(
            color: NewExperienceTokens.textMuted,
          ),
        ),
      ],
    );
  }

  Widget _buildCreditRow(String role, String name) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            role,
            style: const TextStyle(color: NewExperienceTokens.textMuted, fontSize: 13),
          ),
          Flexible(
            child: Text(
              name,
              textAlign: TextAlign.right,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.outfit(
                color: NewExperienceTokens.textPrimary,
                fontWeight: FontWeight.w600,
                fontSize: 13,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
