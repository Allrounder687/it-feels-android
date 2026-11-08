import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:it_feels_music/core/intelligence/editorial/editorial_content_service.dart';
import 'package:it_feels_music/core/providers/riverpod_bridge.dart';
import '../theme/new_experience_tokens.dart';
import '../theme/new_ambient_canvas.dart';
import '../widgets/new_glass_container.dart';
import '../widgets/new_artwork_image.dart';
import '../widgets/new_action_button.dart';
import '../artist/new_artist_detail_screen.dart';
import '../theme/content_viewport_insets.dart';

class NewExploreScreen extends ConsumerStatefulWidget {
  const NewExploreScreen({super.key});

  @override
  ConsumerState<NewExploreScreen> createState() => _NewExploreScreenState();
}

class _NewExploreScreenState extends ConsumerState<NewExploreScreen> {
  final EditorialContentService _editorialService = EditorialContentService();
  String _selectedCategory = 'All';
  late final List<EditorialArticle> _allArticles;

  final List<String> _categories = [
    'All',
    'Artist Spotlight',
    'Regional Scene',
    'Composer Profile',
    'Movement',
  ];

  @override
  void initState() {
    super.initState();
    _allArticles = _editorialService.getCuratedArticles();
  }

  void _openArticleSheet(EditorialArticle article) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _buildArticleDetailSheet(article),
    );
  }

  @override
  Widget build(BuildContext context) {
    final playerState = ref.watch(audioPlayerProvider);
    final hasSong = playerState.currentSong != null;

    final filteredArticles = _selectedCategory == 'All'
        ? _allArticles
        : _allArticles.where((a) => a.category == _selectedCategory).toList();

    return NewAmbientCanvas(
      intensity: 0.40,
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
            'Explore Music',
            style: GoogleFonts.outfit(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: NewExperienceTokens.textPrimary,
            ),
          ),
        ),
        body: CustomScrollView(
          physics: const BouncingScrollPhysics(),
          slivers: [
            // ── Magazine Hero Header ──
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'MUSIC JOURNAL & CULTURAL DISCOVERY',
                      style: NewExperienceTokens.eyebrowLabel(
                        color: NewExperienceTokens.accentCyan,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Explore Stories',
                      style: NewExperienceTokens.displayHero(fontSize: 28),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Deep-dives into seminal artists, regional music movements, and the stories shaping modern sound.',
                      style: NewExperienceTokens.bodyMedium(
                        color: NewExperienceTokens.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 18),

                    // Category Filter Pills
                    SizedBox(
                      height: 36,
                      child: ListView.separated(
                        scrollDirection: Axis.horizontal,
                        itemCount: _categories.length,
                        separatorBuilder: (context, _) => const SizedBox(width: 8),
                        itemBuilder: (context, index) {
                          final cat = _categories[index];
                          final isSelected = _selectedCategory == cat;

                          return InkWell(
                            onTap: () => setState(() => _selectedCategory = cat),
                            borderRadius: BorderRadius.circular(18),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                              decoration: BoxDecoration(
                                color: isSelected
                                    ? NewExperienceTokens.accentCyan
                                    : Colors.white.withValues(alpha: 0.06),
                                borderRadius: BorderRadius.circular(18),
                                border: Border.all(
                                  color: isSelected
                                      ? Colors.transparent
                                      : NewExperienceTokens.specularBorder,
                                ),
                              ),
                              child: Text(
                                cat,
                                style: GoogleFonts.outfit(
                                  fontSize: 13,
                                  fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                                  color: isSelected ? Colors.black : NewExperienceTokens.textSecondary,
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],
                ),
              ),
            ),

            // ── Editorial Articles List ──
            SliverList(
              delegate: SliverChildBuilderDelegate(
                (context, index) {
                  final article = filteredArticles[index];
                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                    child: InkWell(
                      onTap: () => _openArticleSheet(article),
                      borderRadius: BorderRadius.circular(NewExperienceTokens.radiusMedium),
                      child: NewGlassContainer(
                        borderRadius: NewExperienceTokens.radiusMedium,
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Article Image & Category Badge
                            Stack(
                              children: [
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(NewExperienceTokens.radiusSmall),
                                  child: NewArtworkImage(
                                    imageUrl: article.heroImageUrl,
                                    width: double.infinity,
                                    height: 170,
                                    fit: BoxFit.cover,
                                  ),
                                ),
                                Positioned(
                                  top: 10,
                                  left: 10,
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: Colors.black.withValues(alpha: 0.75),
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(color: Colors.white24),
                                    ),
                                    child: Text(
                                      article.category.toUpperCase(),
                                      style: const TextStyle(
                                        color: NewExperienceTokens.accentCyan,
                                        fontSize: 10,
                                        fontWeight: FontWeight.bold,
                                        letterSpacing: 1,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 14),

                            Text(
                              article.title,
                              style: GoogleFonts.outfit(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: NewExperienceTokens.textPrimary,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              article.subtitle,
                              style: NewExperienceTokens.bodyMedium(
                                color: NewExperienceTokens.textSecondary,
                              ),
                            ),
                            const SizedBox(height: 12),

                            // Author & Attribution Footer
                            Row(
                              children: [
                                const Icon(Icons.verified_user_outlined, size: 14, color: NewExperienceTokens.accentViolet),
                                const SizedBox(width: 6),
                                Text(
                                  article.source,
                                  style: const TextStyle(color: NewExperienceTokens.textMuted, fontSize: 12),
                                ),
                                const Spacer(),
                                const Text(
                                  'Read Story →',
                                  style: TextStyle(
                                    color: NewExperienceTokens.accentCyan,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
                childCount: filteredArticles.length,
              ),
            ),

            // Bottom Clearance
            ContentViewportInsets.sliverBottomSpacer(context, ref),
          ],
        ),
      ),
    );
  }

  Widget _buildArticleDetailSheet(EditorialArticle article) {
    return DraggableScrollableSheet(
      initialChildSize: 0.90,
      minChildSize: 0.50,
      maxChildSize: 0.95,
      builder: (context, scrollController) {
        return Container(
          decoration: BoxDecoration(
            color: NewExperienceTokens.midnightSurface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
            border: Border.all(color: NewExperienceTokens.specularBorder),
          ),
          child: ListView(
            controller: scrollController,
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.white24,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),

              Text(
                article.category.toUpperCase(),
                style: const TextStyle(
                  color: NewExperienceTokens.accentCyan,
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.2,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                article.title,
                style: GoogleFonts.outfit(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: NewExperienceTokens.textPrimary,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                article.subtitle,
                style: NewExperienceTokens.bodyMedium(color: NewExperienceTokens.textSecondary),
              ),
              const SizedBox(height: 14),

              ClipRRect(
                borderRadius: BorderRadius.circular(NewExperienceTokens.radiusMedium),
                child: NewArtworkImage(
                  imageUrl: article.heroImageUrl,
                  width: double.infinity,
                  height: 200,
                  fit: BoxFit.cover,
                ),
              ),
              const SizedBox(height: 16),

              // Key Highlights
              if (article.keyHighlights.isNotEmpty) ...[
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.04),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: NewExperienceTokens.specularBorder),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Key Insights',
                        style: GoogleFonts.outfit(
                          fontWeight: FontWeight.bold,
                          color: NewExperienceTokens.accentViolet,
                        ),
                      ),
                      const SizedBox(height: 8),
                      ...article.keyHighlights.map((h) => Padding(
                            padding: const EdgeInsets.symmetric(vertical: 3),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text('• ', style: TextStyle(color: NewExperienceTokens.accentCyan, fontSize: 14)),
                                Expanded(
                                  child: Text(
                                    h,
                                    style: const TextStyle(color: NewExperienceTokens.textPrimary, fontSize: 13),
                                  ),
                                ),
                              ],
                            ),
                          )),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
              ],

              // Full Content
              Text(
                article.content,
                style: GoogleFonts.inter(
                  fontSize: 14,
                  height: 1.65,
                  color: NewExperienceTokens.textSecondary,
                ),
              ),
              const SizedBox(height: 20),

              // Action buttons (Stream Related Music / View Artist)
              if (article.relatedArtist != null)
                NewActionButton(
                  label: 'View ${article.relatedArtist} Profile',
                  icon: Icons.person_rounded,
                  onPressed: () {
                    Navigator.of(context).pop();
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (context) => NewArtistDetailScreen(artistName: article.relatedArtist!),
                      ),
                    );
                  },
                ),
              if (article.relatedSearchQuery != null) ...[
                const SizedBox(height: 10),
                NewActionButton(
                  label: 'Stream "${article.relatedSearchQuery}"',
                  icon: Icons.play_arrow_rounded,
                  variant: NewActionButtonVariant.glass,
                  onPressed: () {
                    Navigator.of(context).pop();
                    ref.read(searchProvider.notifier).search(article.relatedSearchQuery!);
                  },
                ),
              ],

              const SizedBox(height: 20),
              // Citation & Provenance
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.02),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  'Source: ${article.provenance.attribution} • License: ${article.provenance.license}',
                  style: const TextStyle(color: NewExperienceTokens.textMuted, fontSize: 11),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
