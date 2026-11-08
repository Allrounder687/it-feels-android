import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:it_feels_music/core/providers/riverpod_bridge.dart';
import 'package:it_feels_music/data/models/song_model.dart';
import 'package:it_feels_music/core/utils/service_locator.dart';
import 'package:it_feels_music/services/database_service.dart';
import 'package:it_feels_music/services/storage_service.dart';
import '../theme/new_experience_tokens.dart';
import '../theme/new_ambient_canvas.dart';
import '../widgets/new_section_header.dart';
import '../widgets/new_glass_container.dart';
import '../widgets/new_media_tile.dart';
import '../widgets/new_artwork_image.dart';
import '../playlist/new_playlist_detail_screen.dart';
import '../theme/content_viewport_insets.dart';

enum LibrarySortOption {
  dateAdded,
  titleAsc,
  titleDesc,
  artistAsc,
  durationDesc,
  playCountDesc,
}

class NewLibraryScreen extends ConsumerStatefulWidget {
  const NewLibraryScreen({super.key});

  @override
  ConsumerState<NewLibraryScreen> createState() => _NewLibraryScreenState();
}

class _NewLibraryScreenState extends ConsumerState<NewLibraryScreen> {
  String _activeTab = 'All';
  final List<String> _tabs = ['All', 'Liked Songs', 'Downloads', 'Playlists', 'On Repeat', 'Recently Played'];

  // In-Library Search & Filter
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  bool _isSearchExpanded = false;

  // Sorting
  LibrarySortOption _sortOption = LibrarySortOption.dateAdded;

  // Multi-Select Bulk Operations
  bool _isSelectionMode = false;
  final Set<String> _selectedSongIds = {};

  // Extra dynamic library data
  List<Song> _onRepeatSongs = [];
  List<Song> _recentlyPlayedSongs = [];

  // Dynamic scanning state
  bool _isScanningDownloads = false;
  int _totalStorageBytes = 0;

  Future<void> _updateStorageBytes() async {
    try {
      final bytes = await ref.read(downloadProvider.notifier).computeTotalStorageBytes();
      if (mounted) setState(() => _totalStorageBytes = bytes);
    } catch (_) {}
  }

  String _formatBytes(int bytes) {
    if (bytes <= 0) return '0 MB';
    final mb = bytes / (1024 * 1024);
    if (mb >= 1024) {
      return '${(mb / 1024).toStringAsFixed(2)} GB';
    }
    return '${mb.toStringAsFixed(1)} MB';
  }

  Future<void> _handleScanDownloads() async {
    setState(() => _isScanningDownloads = true);
    try {
      final scanned = await ref.read(downloadProvider.notifier).scanAndSync();
      await _updateStorageBytes();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Sync complete: found ${scanned.length} offline tracks'),
            backgroundColor: NewExperienceTokens.accentCyan,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Scan error: $e'),
            backgroundColor: Colors.redAccent,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isScanningDownloads = false);
      }
    }
  }

  void _playSongs(List<Song> songs, {bool shuffle = false}) {
    if (songs.isEmpty) return;
    if (shuffle) {
      ref.read(audioPlayerProvider.notifier).shufflePlayContext(songs);
    } else {
      ref.read(audioPlayerProvider.notifier).playSong(songs.first, queue: songs, index: 0);
    }
  }

  String get _sortOptionLabel {
    switch (_sortOption) {
      case LibrarySortOption.dateAdded:
        return 'Recent';
      case LibrarySortOption.titleAsc:
        return 'A-Z';
      case LibrarySortOption.titleDesc:
        return 'Z-A';
      case LibrarySortOption.artistAsc:
        return 'Artist';
      case LibrarySortOption.durationDesc:
        return 'Duration';
      case LibrarySortOption.playCountDesc:
        return 'Most Played';
    }
  }

  @override
  void initState() {
    super.initState();
    _loadDynamicCollections();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _updateStorageBytes();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadDynamicCollections() async {
    try {
      final db = locator<DatabaseService>();
      final onRepeat = await db.getOnRepeat(limit: 30);
      final pState = await StorageService.loadPlaybackState();
      final List<Song> recents = [];
      if (pState != null && pState['recentlyPlayed'] != null) {
        final List<dynamic> raw = pState['recentlyPlayed'];
        for (final item in raw) {
          try {
            recents.add(Song.fromJson(Map<String, dynamic>.from(item)));
          } catch (_) {}
        }
      }
      if (mounted) {
        setState(() {
          _onRepeatSongs = onRepeat;
          _recentlyPlayedSongs = recents;
        });
      }
    } catch (e) {
      debugPrint('[NewLibraryScreen] Error loading collections: $e');
    }
  }

  void _showCreatePlaylistDialog({List<Song>? initialSongs}) {
    final textController = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: NewExperienceTokens.midnightSurface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(NewExperienceTokens.radiusLarge),
          side: BorderSide(color: NewExperienceTokens.specularBorder),
        ),
        title: Text(
          'Create Playlist',
          style: NewExperienceTokens.sectionTitle(fontSize: 18),
        ),
        content: TextField(
          controller: textController,
          autofocus: true,
          style: NewExperienceTokens.bodyMedium(),
          decoration: InputDecoration(
            hintText: 'My Playlist #1',
            hintStyle: NewExperienceTokens.bodySmall(color: NewExperienceTokens.textMuted),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: NewExperienceTokens.specularBorder),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel', style: NewExperienceTokens.bodySmall(color: NewExperienceTokens.textMuted)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: NewExperienceTokens.accentViolet,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            onPressed: () {
              final title = textController.text.trim();
              if (title.isNotEmpty) {
                ref.read(customPlaylistProvider.notifier).createPlaylist(title);
                if (initialSongs != null && initialSongs.isNotEmpty) {
                  // Find created playlist and add tracks
                  final pNotifier = ref.read(customPlaylistProvider.notifier);
                  for (final song in initialSongs) {
                    pNotifier.addSongToPlaylist(title, song);
                  }
                }
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Created playlist "$title"')),
                );
              }
            },
            child: const Text('Create', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  void _showSortSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: NewExperienceTokens.midnightSurface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Sort Library By', style: NewExperienceTokens.sectionTitle(fontSize: 18)),
              const SizedBox(height: 12),
              _sortTile('Date Added (Recent First)', LibrarySortOption.dateAdded),
              _sortTile('Title (A to Z)', LibrarySortOption.titleAsc),
              _sortTile('Title (Z to A)', LibrarySortOption.titleDesc),
              _sortTile('Artist Name (A to Z)', LibrarySortOption.artistAsc),
              _sortTile('Track Duration (Longest First)', LibrarySortOption.durationDesc),
              _sortTile('Most Played Tracks', LibrarySortOption.playCountDesc),
            ],
          ),
        ),
      ),
    );
  }

  Widget _sortTile(String title, LibrarySortOption option) {
    final isSelected = _sortOption == option;
    return ListTile(
      contentPadding: EdgeInsets.zero,
      title: Text(
        title,
        style: NewExperienceTokens.bodyMedium(
          color: isSelected ? NewExperienceTokens.accentCyan : Colors.white,
        ).copyWith(fontWeight: isSelected ? FontWeight.bold : FontWeight.w500),
      ),
      trailing: isSelected ? const Icon(Icons.check_rounded, color: NewExperienceTokens.accentCyan) : null,
      onTap: () {
        setState(() => _sortOption = option);
        Navigator.pop(context);
      },
    );
  }

  Widget _buildEmptyState({
    required IconData icon,
    required String title,
    required String description,
    String? actionLabel,
    VoidCallback? onAction,
    bool isLoading = false,
  }) {
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 48),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withValues(alpha: 0.05),
                  border: Border.all(color: NewExperienceTokens.specularBorder),
                ),
                child: Icon(icon, size: 34, color: NewExperienceTokens.accentCyan),
              ),
              const SizedBox(height: 16),
              Text(
                title,
                style: NewExperienceTokens.sectionTitle(fontSize: 18),
              ),
              const SizedBox(height: 8),
              Text(
                description,
                textAlign: TextAlign.center,
                style: NewExperienceTokens.bodySmall(color: NewExperienceTokens.textMuted),
              ),
              if (actionLabel != null && onAction != null) ...[
                const SizedBox(height: 20),
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: NewExperienceTokens.accentViolet,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                  onPressed: isLoading ? null : onAction,
                  icon: isLoading
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                      : const Icon(Icons.sync_rounded, size: 18),
                  label: Text(isLoading ? 'Scanning Storage...' : actionLabel),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  List<Song> _applySortingAndFilter(List<Song> songs) {
    List<Song> result = List.from(songs);

    // Apply text search
    if (_searchQuery.trim().isNotEmpty) {
      final q = _searchQuery.trim().toLowerCase();
      result = result.where((s) {
        return s.title.toLowerCase().contains(q) ||
            s.artist.toLowerCase().contains(q) ||
            s.album.toLowerCase().contains(q);
      }).toList();
    }

    // Apply sorting
    switch (_sortOption) {
      case LibrarySortOption.dateAdded:
        result.sort((a, b) => b.addedAt.compareTo(a.addedAt));
        break;
      case LibrarySortOption.titleAsc:
        result.sort((a, b) => a.title.toLowerCase().compareTo(b.title.toLowerCase()));
        break;
      case LibrarySortOption.titleDesc:
        result.sort((a, b) => b.title.toLowerCase().compareTo(a.title.toLowerCase()));
        break;
      case LibrarySortOption.artistAsc:
        result.sort((a, b) => a.artist.toLowerCase().compareTo(b.artist.toLowerCase()));
        break;
      case LibrarySortOption.durationDesc:
        result.sort((a, b) => b.duration.compareTo(a.duration));
        break;
      case LibrarySortOption.playCountDesc:
        result.sort((a, b) => b.playCount.compareTo(a.playCount));
        break;
    }

    return result;
  }

  @override
  Widget build(BuildContext context) {
    final playlistState = ref.watch(customPlaylistProvider);
    final downloadState = ref.watch(downloadProvider);
    final playerState = ref.watch(audioPlayerProvider);
    final playerNotifier = ref.read(audioPlayerProvider.notifier);

    final rawLikedSongs = playerState.favoriteSongs;
    final rawDownloadedSongs = downloadState.downloadedSongs;

    final likedSongs = _applySortingAndFilter(rawLikedSongs);
    final downloadedSongs = _applySortingAndFilter(rawDownloadedSongs);
    final onRepeatSongs = _applySortingAndFilter(_onRepeatSongs);
    final recentlyPlayedSongs = _applySortingAndFilter(_recentlyPlayedSongs);

    // Master list for bulk actions
    List<Song> currentActiveSongs = [];
    if (_activeTab == 'Liked Songs') {
      currentActiveSongs = likedSongs;
    } else if (_activeTab == 'Downloads') {
      currentActiveSongs = downloadedSongs;
    } else if (_activeTab == 'On Repeat') {
      currentActiveSongs = onRepeatSongs;
    } else if (_activeTab == 'Recently Played') {
      currentActiveSongs = recentlyPlayedSongs;
    } else {
      currentActiveSongs = [...downloadedSongs, ...likedSongs];
    }

    return NewAmbientCanvas(
      intensity: 0.3,
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: SafeArea(
          bottom: false,
          child: Stack(
            children: [
              CustomScrollView(
                physics: const BouncingScrollPhysics(),
                slivers: [
                  // ── Header & Title ──
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.only(left: 20, right: 20, top: 18, bottom: 8),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'YOUR COLLECTION',
                                style: NewExperienceTokens.eyebrowLabel(
                                  color: NewExperienceTokens.accentCyan,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Your Library',
                                style: NewExperienceTokens.displayHero(fontSize: 28),
                              ),
                            ],
                          ),
                          Row(
                            children: [
                              // Toggle In-Library Search
                              IconButton(
                                tooltip: 'Search in Library',
                                icon: Icon(
                                  _isSearchExpanded ? Icons.close_rounded : Icons.search_rounded,
                                  color: _isSearchExpanded ? NewExperienceTokens.accentCyan : NewExperienceTokens.textSecondary,
                                  size: 22,
                                ),
                                onPressed: () {
                                  setState(() {
                                    _isSearchExpanded = !_isSearchExpanded;
                                    if (!_isSearchExpanded) {
                                      _searchController.clear();
                                      _searchQuery = '';
                                    }
                                  });
                                },
                              ),

                              // Sort Button
                              IconButton(
                                tooltip: 'Sort Library',
                                icon: const Icon(
                                  Icons.sort_rounded,
                                  color: NewExperienceTokens.textSecondary,
                                  size: 22,
                                ),
                                onPressed: _showSortSheet,
                              ),

                              // Multi-Select Toggle
                              IconButton(
                                tooltip: _isSelectionMode ? 'Cancel Selection' : 'Select Tracks',
                                icon: Icon(
                                  _isSelectionMode ? Icons.check_circle_rounded : Icons.checklist_rounded,
                                  color: _isSelectionMode ? NewExperienceTokens.accentCyan : NewExperienceTokens.textSecondary,
                                  size: 22,
                                ),
                                onPressed: () {
                                  setState(() {
                                    _isSelectionMode = !_isSelectionMode;
                                    _selectedSongIds.clear();
                                  });
                                },
                              ),

                              // Create Playlist Button
                              IconButton(
                                tooltip: 'Create Playlist',
                                icon: Container(
                                  padding: const EdgeInsets.all(6),
                                  decoration: const BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: NewExperienceTokens.accentViolet,
                                  ),
                                  child: const Icon(
                                    Icons.add_rounded,
                                    color: Colors.white,
                                    size: 18,
                                  ),
                                ),
                                onPressed: () => _showCreatePlaylistDialog(),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),

                  // ── In-Library Search Bar (Collapsible) ──
                  if (_isSearchExpanded)
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
                        child: NewGlassContainer(
                          borderRadius: 14,
                          padding: const EdgeInsets.symmetric(horizontal: 14),
                          child: TextField(
                            controller: _searchController,
                            autofocus: true,
                            style: NewExperienceTokens.bodyMedium(),
                            decoration: InputDecoration(
                              hintText: 'Filter your library by title, artist, or album...',
                              hintStyle: NewExperienceTokens.bodySmall(color: NewExperienceTokens.textMuted),
                              border: InputBorder.none,
                              prefixIcon: const Icon(Icons.search, size: 18, color: NewExperienceTokens.textMuted),
                              suffixIcon: _searchQuery.isNotEmpty
                                  ? IconButton(
                                      icon: const Icon(Icons.clear, size: 16, color: NewExperienceTokens.textMuted),
                                      onPressed: () {
                                        _searchController.clear();
                                        setState(() => _searchQuery = '');
                                      },
                                    )
                                  : null,
                            ),
                            onChanged: (val) => setState(() => _searchQuery = val),
                          ),
                        ),
                      ),
                    ),

                  // ── Filter Chips ──
                  SliverToBoxAdapter(
                    child: SizedBox(
                      height: 44,
                      child: ListView.separated(
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
                        scrollDirection: Axis.horizontal,
                        itemCount: _tabs.length,
                        separatorBuilder: (_, _) => const SizedBox(width: 8),
                        itemBuilder: (context, index) {
                          final tab = _tabs[index];
                          final isSelected = _activeTab == tab;

                          return InkWell(
                            onTap: () => setState(() => _activeTab = tab),
                            borderRadius: BorderRadius.circular(18),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 200),
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                              decoration: BoxDecoration(
                                color: isSelected
                                    ? NewExperienceTokens.accentViolet
                                    : Colors.white.withValues(alpha: 0.06),
                                borderRadius: BorderRadius.circular(18),
                                border: Border.all(
                                  color: isSelected ? Colors.transparent : NewExperienceTokens.specularBorder,
                                ),
                              ),
                              child: Text(
                                tab,
                                style: NewExperienceTokens.bodySmall(
                                  color: isSelected ? Colors.white : NewExperienceTokens.textSecondary,
                                ).copyWith(fontWeight: isSelected ? FontWeight.bold : FontWeight.w500),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ),

                  const SliverToBoxAdapter(child: SizedBox(height: 14)),

                  // ── Library Quick Actions Bar (Play All, Shuffle, Scan Disk, Sort, Multi-Select) ──
                  if (_activeTab != 'Playlists' && currentActiveSongs.isNotEmpty)
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
                        child: SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          physics: const BouncingScrollPhysics(),
                          child: Row(
                            children: [
                              // Play All Button
                              ElevatedButton.icon(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: NewExperienceTokens.accentViolet,
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                                  elevation: 0,
                                ),
                                onPressed: () => _playSongs(currentActiveSongs, shuffle: false),
                                icon: const Icon(Icons.play_arrow_rounded, size: 20),
                                label: Text(
                                  'Play (${currentActiveSongs.length})',
                                  style: NewExperienceTokens.bodySmall(color: Colors.white)
                                      .copyWith(fontWeight: FontWeight.bold),
                                ),
                              ),
                              const SizedBox(width: 8),

                              // Shuffle Play Button
                              OutlinedButton.icon(
                                style: OutlinedButton.styleFrom(
                                  side: BorderSide(color: NewExperienceTokens.specularBorder),
                                  backgroundColor: Colors.white.withValues(alpha: 0.05),
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                                ),
                                onPressed: () => _playSongs(currentActiveSongs, shuffle: true),
                                icon: const Icon(Icons.shuffle_rounded, size: 18, color: NewExperienceTokens.accentCyan),
                                label: Text(
                                  'Shuffle',
                                  style: NewExperienceTokens.bodySmall(color: Colors.white)
                                      .copyWith(fontWeight: FontWeight.w600),
                                ),
                              ),
                              const SizedBox(width: 8),

                              // Scan / Sync Downloads (Visible in Downloads or All)
                              if (_activeTab == 'Downloads' || _activeTab == 'All') ...[
                                OutlinedButton.icon(
                                  style: OutlinedButton.styleFrom(
                                    side: BorderSide(color: NewExperienceTokens.specularBorder),
                                    backgroundColor: Colors.white.withValues(alpha: 0.05),
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                                  ),
                                  onPressed: _isScanningDownloads ? null : _handleScanDownloads,
                                  icon: _isScanningDownloads
                                      ? const SizedBox(
                                          width: 14,
                                          height: 14,
                                          child: CircularProgressIndicator(strokeWidth: 2, color: NewExperienceTokens.accentCyan),
                                        )
                                      : const Icon(Icons.sync_rounded, size: 18, color: NewExperienceTokens.accentCyan),
                                  label: Text(
                                    _isScanningDownloads ? 'Scanning...' : 'Scan Disk',
                                    style: NewExperienceTokens.bodySmall(color: Colors.white)
                                        .copyWith(fontWeight: FontWeight.w600),
                                  ),
                                ),
                                const SizedBox(width: 8),
                              ],

                              // Sort Dropdown Pill
                              InkWell(
                                onTap: _showSortSheet,
                                borderRadius: BorderRadius.circular(16),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withValues(alpha: 0.04),
                                    borderRadius: BorderRadius.circular(16),
                                    border: Border.all(color: NewExperienceTokens.specularBorder),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const Icon(Icons.sort_rounded, size: 16, color: NewExperienceTokens.textSecondary),
                                      const SizedBox(width: 6),
                                      Text(
                                        _sortOptionLabel,
                                        style: NewExperienceTokens.captionMuted(color: NewExperienceTokens.textSecondary)
                                            .copyWith(fontWeight: FontWeight.w600),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),

                              // Multi-Select Checklist Toggle
                              IconButton(
                                tooltip: _isSelectionMode ? 'Cancel Selection' : 'Select Multiple',
                                icon: Icon(
                                  _isSelectionMode ? Icons.check_circle_rounded : Icons.checklist_rounded,
                                  color: _isSelectionMode ? NewExperienceTokens.accentCyan : NewExperienceTokens.textSecondary,
                                  size: 20,
                                ),
                                onPressed: () {
                                  setState(() {
                                    _isSelectionMode = !_isSelectionMode;
                                    _selectedSongIds.clear();
                                  });
                                },
                              ),

                              // Select All / Deselect All Button (visible when selecting)
                              if (_isSelectionMode && currentActiveSongs.isNotEmpty) ...[
                                const SizedBox(width: 8),
                                TextButton.icon(
                                  style: TextButton.styleFrom(
                                    foregroundColor: NewExperienceTokens.accentCyan,
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                  ),
                                  icon: Icon(
                                    _selectedSongIds.length == currentActiveSongs.length
                                        ? Icons.deselect_rounded
                                        : Icons.select_all_rounded,
                                    size: 18,
                                  ),
                                  label: Text(
                                    _selectedSongIds.length == currentActiveSongs.length
                                        ? 'Deselect All'
                                        : 'Select All (${currentActiveSongs.length})',
                                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                                  ),
                                  onPressed: () {
                                    setState(() {
                                      if (_selectedSongIds.length == currentActiveSongs.length) {
                                        _selectedSongIds.clear();
                                      } else {
                                        _selectedSongIds.addAll(currentActiveSongs.map((s) => s.id));
                                      }
                                    });
                                  },
                                ),
                              ],
                            ],
                          ),
                        ),
                      ),
                    ),

                  // ── Liked Songs Hero Banner (if All or Liked Songs) ──
                  if (_activeTab == 'All' || _activeTab == 'Liked Songs') ...[
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        child: InkWell(
                          onTap: () {
                            final playlist = Playlist(
                              id: 'favorites_playlist',
                              title: 'Liked Songs',
                              subtitle: '${likedSongs.length} Songs',
                              image: likedSongs.isNotEmpty ? likedSongs.first.image : '',
                              songCount: likedSongs.length,
                            );
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (context) => NewPlaylistDetailScreen(
                                  playlist: playlist,
                                  staticTracks: likedSongs,
                                ),
                              ),
                            );
                          },
                          borderRadius: BorderRadius.circular(20),
                          child: Container(
                            height: 104,
                            padding: const EdgeInsets.all(18),
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                colors: [Color(0xFF4C1D95), Color(0xFF1E1B4B)],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
                              boxShadow: [
                                BoxShadow(
                                  color: const Color(0xFF4C1D95).withValues(alpha: 0.35),
                                  blurRadius: 16,
                                  offset: const Offset(0, 6),
                                ),
                              ],
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Text(
                                      'Liked Songs',
                                      style: NewExperienceTokens.sectionTitle(fontSize: 22),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      '${rawLikedSongs.length} Favorite Tracks',
                                      style: NewExperienceTokens.bodySmall(
                                        color: Colors.white.withValues(alpha: 0.8),
                                      ),
                                    ),
                                  ],
                                ),
                                Container(
                                  width: 50,
                                  height: 50,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: Colors.white.withValues(alpha: 0.15),
                                  ),
                                  child: const Icon(
                                    Icons.favorite_rounded,
                                    color: NewExperienceTokens.accentRose,
                                    size: 26,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SliverToBoxAdapter(child: SizedBox(height: 16)),
                  ],

                  // ── Liked Songs Tracklist (When in Liked Songs tab) ──
                  if (_activeTab == 'Liked Songs') ...[
                    if (likedSongs.isEmpty)
                      _buildEmptyState(
                        icon: Icons.favorite_border_rounded,
                        title: 'No Liked Songs Yet',
                        description: 'Tap the heart icon on any track to add it to your personal favorites collection.',
                      )
                    else
                      SliverList(
                        delegate: SliverChildBuilderDelegate(
                          (context, index) {
                            final song = likedSongs[index];
                            final isSelected = _selectedSongIds.contains(song.id);

                            return Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 20),
                              child: Row(
                                children: [
                                  if (_isSelectionMode)
                                    Checkbox(
                                      value: isSelected,
                                      activeColor: NewExperienceTokens.accentCyan,
                                      onChanged: (val) {
                                        setState(() {
                                          if (val == true) {
                                            _selectedSongIds.add(song.id);
                                          } else {
                                            _selectedSongIds.remove(song.id);
                                          }
                                        });
                                      },
                                    ),
                                  Expanded(
                                    child: NewMediaTile(
                                      song: song,
                                      index: index,
                                      onTap: _isSelectionMode
                                          ? () {
                                              setState(() {
                                                if (isSelected) {
                                                  _selectedSongIds.remove(song.id);
                                                } else {
                                                  _selectedSongIds.add(song.id);
                                                }
                                              });
                                            }
                                          : () => playerNotifier.playSong(
                                                song,
                                                queue: likedSongs,
                                                index: index,
                                              ),
                                    ),
                                  ),
                                ],
                              ),
                            );
                          },
                          childCount: likedSongs.length,
                        ),
                      ),
                    const SliverToBoxAdapter(child: SizedBox(height: 16)),
                  ],

                  // ── Downloaded Tracks Shelf ──
                  if (_activeTab == 'Downloads' && downloadedSongs.isEmpty)
                    _buildEmptyState(
                      icon: Icons.download_done_rounded,
                      title: 'No Downloaded Music Found',
                      description: 'Music downloaded for offline playback will appear here.\nYou can also scan your device storage for existing local audio files.',
                      actionLabel: 'Scan Disk Storage',
                      onAction: _handleScanDownloads,
                      isLoading: _isScanningDownloads,
                    ),

                  // Offline Storage Hero Card (when in Downloads tab)
                  if (_activeTab == 'Downloads' && downloadedSongs.isNotEmpty) ...[
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        child: Container(
                          padding: const EdgeInsets.all(18),
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [Color(0xFF0F3A40), Color(0xFF06181C)],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: NewExperienceTokens.accentCyan.withValues(alpha: 0.3)),
                            boxShadow: [
                              BoxShadow(
                                color: NewExperienceTokens.accentCyan.withValues(alpha: 0.12),
                                blurRadius: 16,
                                offset: const Offset(0, 6),
                              ),
                            ],
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                          decoration: BoxDecoration(
                                            color: NewExperienceTokens.accentCyan.withValues(alpha: 0.2),
                                            borderRadius: BorderRadius.circular(6),
                                          ),
                                          child: Text(
                                            'OFFLINE READY',
                                            style: NewExperienceTokens.captionMuted(
                                              color: NewExperienceTokens.accentCyan,
                                            ).copyWith(fontWeight: FontWeight.bold, fontSize: 10),
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 6),
                                    Text(
                                      'Offline Storage',
                                      style: NewExperienceTokens.sectionTitle(fontSize: 20),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      '${rawDownloadedSongs.length} Tracks • ${_formatBytes(_totalStorageBytes)} On Disk',
                                      style: NewExperienceTokens.bodySmall(
                                        color: Colors.white.withValues(alpha: 0.8),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Row(
                                children: [
                                  IconButton(
                                    tooltip: 'Shuffle Offline',
                                    icon: const Icon(Icons.shuffle_rounded, color: NewExperienceTokens.accentCyan, size: 24),
                                    onPressed: () => _playSongs(downloadedSongs, shuffle: true),
                                  ),
                                  const SizedBox(width: 4),
                                  InkWell(
                                    onTap: () => _playSongs(downloadedSongs, shuffle: false),
                                    borderRadius: BorderRadius.circular(22),
                                    child: Container(
                                      width: 44,
                                      height: 44,
                                      decoration: const BoxDecoration(
                                        shape: BoxShape.circle,
                                        color: NewExperienceTokens.accentCyan,
                                      ),
                                      child: const Icon(Icons.play_arrow_rounded, color: Colors.black, size: 26),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SliverToBoxAdapter(child: SizedBox(height: 16)),
                  ],

                  if ((_activeTab == 'All' || _activeTab == 'Downloads') && downloadedSongs.isNotEmpty) ...[
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        child: NewSectionHeader(
                          title: 'Downloaded Music (${downloadedSongs.length})',
                          eyebrow: 'OFFLINE READY',
                          actionLabel: 'Shuffle',
                          onAction: () => _playSongs(downloadedSongs, shuffle: true),
                        ),
                      ),
                    ),
                    SliverList(
                      delegate: SliverChildBuilderDelegate(
                        (context, index) {
                          final song = downloadedSongs[index];
                          final isSelected = _selectedSongIds.contains(song.id);

                          return Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 20),
                            child: Row(
                              children: [
                                if (_isSelectionMode)
                                  Checkbox(
                                    value: isSelected,
                                    activeColor: NewExperienceTokens.accentCyan,
                                    onChanged: (val) {
                                      setState(() {
                                        if (val == true) {
                                          _selectedSongIds.add(song.id);
                                        } else {
                                          _selectedSongIds.remove(song.id);
                                        }
                                      });
                                    },
                                  ),
                                Expanded(
                                  child: NewMediaTile(
                                    song: song,
                                    index: index,
                                    onTap: _isSelectionMode
                                        ? () {
                                            setState(() {
                                              if (isSelected) {
                                                _selectedSongIds.remove(song.id);
                                              } else {
                                                _selectedSongIds.add(song.id);
                                              }
                                            });
                                          }
                                        : () => playerNotifier.playSong(
                                              song,
                                              queue: downloadedSongs,
                                              index: index,
                                            ),
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                        childCount: _activeTab == 'Downloads'
                            ? downloadedSongs.length
                            : (downloadedSongs.length > 25 ? 25 : downloadedSongs.length),
                      ),
                    ),
                    const SliverToBoxAdapter(child: SizedBox(height: 16)),
                  ],

                  // ── On Repeat Shelf ──
                  if (_activeTab == 'On Repeat' && onRepeatSongs.isEmpty)
                    _buildEmptyState(
                      icon: Icons.repeat_rounded,
                      title: 'No Repeat Tracks Yet',
                      description: 'Tracks you listen to frequently will automatically appear here as your listening patterns emerge.',
                    ),

                  if ((_activeTab == 'All' || _activeTab == 'On Repeat') && onRepeatSongs.isNotEmpty) ...[
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        child: NewSectionHeader(
                          title: 'On Repeat (${onRepeatSongs.length})',
                          eyebrow: 'MOST PLAYED',
                          actionLabel: 'Shuffle',
                          onAction: () => _playSongs(onRepeatSongs, shuffle: true),
                        ),
                      ),
                    ),
                    SliverList(
                      delegate: SliverChildBuilderDelegate(
                        (context, index) {
                          final song = onRepeatSongs[index];
                          return Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 20),
                            child: NewMediaTile(
                              song: song,
                              index: index,
                              onTap: () => playerNotifier.playSong(
                                song,
                                queue: onRepeatSongs,
                                index: index,
                              ),
                            ),
                          );
                        },
                        childCount: _activeTab == 'On Repeat'
                            ? onRepeatSongs.length
                            : (onRepeatSongs.length > 15 ? 15 : onRepeatSongs.length),
                      ),
                    ),
                    const SliverToBoxAdapter(child: SizedBox(height: 16)),
                  ],

                  // ── Recently Played Shelf ──
                  if (_activeTab == 'Recently Played' && recentlyPlayedSongs.isEmpty)
                    _buildEmptyState(
                      icon: Icons.history_rounded,
                      title: 'No Listening History',
                      description: 'Songs you stream or play offline will be tracked here so you can retrace your listening sessions anytime.',
                    ),

                  if ((_activeTab == 'All' || _activeTab == 'Recently Played') && recentlyPlayedSongs.isNotEmpty) ...[
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        child: NewSectionHeader(
                          title: 'Recently Played (${recentlyPlayedSongs.length})',
                          eyebrow: 'LISTENING HISTORY',
                          actionLabel: 'Shuffle',
                          onAction: () => _playSongs(recentlyPlayedSongs, shuffle: true),
                        ),
                      ),
                    ),
                    SliverList(
                      delegate: SliverChildBuilderDelegate(
                        (context, index) {
                          final song = recentlyPlayedSongs[index];
                          return Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 20),
                            child: NewMediaTile(
                              song: song,
                              index: index,
                              onTap: () => playerNotifier.playSong(
                                song,
                                queue: recentlyPlayedSongs,
                                index: index,
                              ),
                            ),
                          );
                        },
                        childCount: _activeTab == 'Recently Played'
                            ? recentlyPlayedSongs.length
                            : (recentlyPlayedSongs.length > 15 ? 15 : recentlyPlayedSongs.length),
                      ),
                    ),
                    const SliverToBoxAdapter(child: SizedBox(height: 16)),
                  ],

                  // ── Custom User Playlists ──
                  if (_activeTab == 'All' || _activeTab == 'Playlists') ...[
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        child: NewSectionHeader(
                          title: 'Your Playlists (${playlistState.playlists.length})',
                          eyebrow: 'CREATED BY YOU',
                          actionLabel: '+ New',
                          onAction: () => _showCreatePlaylistDialog(),
                        ),
                      ),
                    ),
                    if (playlistState.playlists.isEmpty)
                      SliverToBoxAdapter(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
                          child: Center(
                            child: Column(
                              children: [
                                const Icon(
                                  Icons.playlist_add_rounded,
                                  size: 40,
                                  color: NewExperienceTokens.textMuted,
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  'No custom playlists yet',
                                  style: NewExperienceTokens.bodyMedium(
                                    color: NewExperienceTokens.textSecondary,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'Tap the + button to create your first playlist.',
                                  style: NewExperienceTokens.captionMuted(),
                                ),
                              ],
                            ),
                          ),
                        ),
                      )
                    else
                      SliverList(
                        delegate: SliverChildBuilderDelegate(
                          (context, index) {
                            final pl = playlistState.playlists[index];
                            return Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
                              child: InkWell(
                                onTap: () {
                                  final playlist = Playlist(
                                    id: pl.id,
                                    title: pl.title,
                                    subtitle: '${pl.songs.length} Tracks',
                                    image: pl.songs.isNotEmpty ? pl.songs.first.image : '',
                                    songCount: pl.songs.length,
                                  );
                                  Navigator.of(context).push(
                                    MaterialPageRoute(
                                      builder: (context) => NewPlaylistDetailScreen(
                                        playlist: playlist,
                                        staticTracks: pl.songs,
                                      ),
                                    ),
                                  );
                                },
                                borderRadius: BorderRadius.circular(14),
                                child: NewGlassContainer(
                                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                                  child: Row(
                                    children: [
                                      Container(
                                        width: 48,
                                        height: 48,
                                        decoration: BoxDecoration(
                                          color: NewExperienceTokens.midnightSurface,
                                          borderRadius: BorderRadius.circular(10),
                                        ),
                                        child: pl.songs.isNotEmpty
                                            ? NewArtworkImage(
                                                imageUrl: pl.songs.first.image,
                                                width: 48,
                                                height: 48,
                                                borderRadius: BorderRadius.circular(10),
                                                iconSize: 22,
                                              )
                                            : const Icon(
                                                Icons.music_note_rounded,
                                                color: NewExperienceTokens.accentViolet,
                                              ),
                                      ),
                                      const SizedBox(width: 14),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              pl.title,
                                              style: NewExperienceTokens.bodyMedium().copyWith(
                                                fontWeight: FontWeight.w600,
                                              ),
                                            ),
                                            const SizedBox(height: 2),
                                            Text(
                                              '${pl.songs.length} Songs • Playlist',
                                              style: NewExperienceTokens.captionMuted(),
                                            ),
                                          ],
                                        ),
                                      ),
                                      const Icon(
                                        Icons.chevron_right_rounded,
                                        color: NewExperienceTokens.textMuted,
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            );
                          },
                          childCount: playlistState.playlists.length,
                        ),
                      ),
                  ],

                  // Centralized dynamic bottom clearance
                  ContentViewportInsets.sliverBottomSpacer(context, ref),
                ],
              ),

              // ── Multi-Select Floating Bulk Action Dock ──
              if (_isSelectionMode && _selectedSongIds.isNotEmpty)
                Positioned(
                  left: 20,
                  right: 20,
                  bottom: ContentViewportInsets.bottom(context, ref) + 12,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    decoration: BoxDecoration(
                      color: NewExperienceTokens.midnightSurface,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: NewExperienceTokens.accentCyan, width: 1.2),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.6),
                          blurRadius: 20,
                          offset: const Offset(0, 6),
                        ),
                      ],
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          '${_selectedSongIds.length} Selected',
                          style: NewExperienceTokens.bodyMedium(
                            color: NewExperienceTokens.accentCyan,
                          ).copyWith(fontWeight: FontWeight.bold),
                        ),
                        Row(
                          children: [
                            // Add to Queue
                            IconButton(
                              tooltip: 'Add to Queue',
                              icon: const Icon(Icons.queue_music_rounded, size: 20, color: Colors.white),
                              onPressed: () {
                                final selectedSongs = currentActiveSongs
                                    .where((s) => _selectedSongIds.contains(s.id))
                                    .toList();
                                ref.read(audioPlayerProvider.notifier).addSongsToQueue(selectedSongs);
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(content: Text('Added ${selectedSongs.length} tracks to queue')),
                                );
                                setState(() {
                                  _isSelectionMode = false;
                                  _selectedSongIds.clear();
                                });
                              },
                            ),
                            // Add to Playlist
                            IconButton(
                              tooltip: 'Add to Playlist',
                              icon: const Icon(Icons.playlist_add_rounded, size: 20, color: Colors.white),
                              onPressed: () {
                                final selectedSongs = currentActiveSongs
                                    .where((s) => _selectedSongIds.contains(s.id))
                                    .toList();
                                _showCreatePlaylistDialog(initialSongs: selectedSongs);
                              },
                            ),
                            // Bulk Delete from Storage (if in Downloads tab)
                            if (_activeTab == 'Downloads') ...[
                              IconButton(
                                tooltip: 'Delete from Storage',
                                icon: const Icon(Icons.delete_outline_rounded, size: 20, color: Colors.redAccent),
                                onPressed: () async {
                                  final selectedSongs = currentActiveSongs
                                      .where((s) => _selectedSongIds.contains(s.id))
                                      .toList();
                                  final confirm = await showDialog<bool>(
                                    context: context,
                                    builder: (ctx) => AlertDialog(
                                      backgroundColor: NewExperienceTokens.midnightSurface,
                                      title: const Text('Delete Downloaded Tracks', style: TextStyle(color: Colors.white)),
                                      content: Text(
                                        'Permanently delete ${selectedSongs.length} downloaded track(s) from device storage?',
                                        style: NewExperienceTokens.bodySmall(color: NewExperienceTokens.textSecondary),
                                      ),
                                      actions: [
                                        TextButton(
                                          onPressed: () => Navigator.pop(ctx, false),
                                          child: const Text('Cancel', style: TextStyle(color: Colors.white70)),
                                        ),
                                        ElevatedButton(
                                          style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
                                          onPressed: () => Navigator.pop(ctx, true),
                                          child: const Text('Delete', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                                        ),
                                      ],
                                    ),
                                  );
                                  if (confirm == true) {
                                    await ref.read(downloadProvider.notifier).removeDownloadsBatch(selectedSongs);
                                    _updateStorageBytes();
                                    setState(() {
                                      _selectedSongIds.clear();
                                      _isSelectionMode = false;
                                    });
                                    if (mounted) {
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        SnackBar(content: Text('Deleted ${selectedSongs.length} tracks from disk')),
                                      );
                                    }
                                  }
                                },
                              ),
                            ],
                            const SizedBox(width: 4),
                            ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: NewExperienceTokens.accentCyan,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                              ),
                              onPressed: () {
                                setState(() {
                                  _isSelectionMode = false;
                                  _selectedSongIds.clear();
                                });
                              },
                              child: const Text('Done', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 13)),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
