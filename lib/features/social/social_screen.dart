import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:it_feels_music/core/theme/app_colors.dart';
import 'package:it_feels_music/core/theme/theme_ext.dart';
import 'package:it_feels_music/core/utils/service_locator.dart';
import 'package:it_feels_music/data/models/song_model.dart';
import 'package:it_feels_music/features/social/social_service.dart';
import 'package:it_feels_music/features/social/friend_profile_screen.dart';
import 'package:it_feels_music/core/widgets/custom_image_widget.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:it_feels_music/core/widgets/empty_state_widget.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:it_feels_music/core/widgets/skeleton_loading_list.dart';
import 'package:it_feels_music/core/providers/riverpod_bridge.dart';
import 'package:it_feels_music/data/models/custom_playlist.dart';
import 'package:it_feels_music/features/social/room_service.dart';
import 'package:it_feels_music/features/auth/auth_bottom_sheet.dart';
import 'package:go_router/go_router.dart';
import 'package:it_feels_music/core/theme/app_dimensions.dart';

final friendDetailsProvider = FutureProvider.family<Map<String, dynamic>?, String>((ref, uid) async {
  final socialService = locator<SocialService>();
  return socialService.getFriendDetails(uid);
});

class SocialScreen extends ConsumerStatefulWidget {
  const SocialScreen({super.key});

  @override
  ConsumerState<SocialScreen> createState() => _SocialScreenState();
}

class _SocialScreenState extends ConsumerState<SocialScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final SocialService _socialService = locator<SocialService>();
  
  FirebaseAuth get auth => locator.isRegistered<FirebaseAuth>() ? locator<FirebaseAuth>() : FirebaseAuth.instance;
  FirebaseFirestore get firestore => locator.isRegistered<FirebaseFirestore>() ? locator<FirebaseFirestore>() : FirebaseFirestore.instance;

  String get myUid => auth.currentUser?.uid ?? '';
  
  Stream<QuerySnapshot>? _inboxStream;
  Stream<DocumentSnapshot>? _friendsStream;
  Stream<DatabaseEvent>? _publicRoomsStream;
  String? _cachedUid;

  void _ensureStreams() {
    final uid = auth.currentUser?.uid;
    if (_cachedUid != uid || _inboxStream == null) {
      _cachedUid = uid;
      _inboxStream = _socialService.getInboxStream();
      _friendsStream = _socialService.getFriendsStream();
    }
    _publicRoomsStream ??= locator<RoomService>().getPublicRooms();
  }

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _showAddFriendDialog() {
    final user = auth.currentUser;
    if (user == null || user.isAnonymous) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please log in to an account to add friends.")),
      );
      AuthBottomSheet.show(context);
      return;
    }
    final TextEditingController uidController = TextEditingController();
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: context.themeSurfaceColor,
          title: Text("Add Friend", style: GoogleFonts.inter(color: context.themeTextColor, fontWeight: FontWeight.bold)),
          content: TextField(
            controller: uidController,
            style: TextStyle(color: context.themeTextColor),
            decoration: InputDecoration(
              hintText: "Enter Email, @username, or UID",
              hintStyle: TextStyle(color: context.themeMutedTextColor),
              enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: context.themeMutedTextColor)),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("Cancel"),
            ),
            ElevatedButton(
              onPressed: () async {
                final query = uidController.text.trim();
                if (query.isNotEmpty) {
                  final success = await _socialService.addFriendByQuery(query);
                  if (context.mounted) {
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text(success ? "Friend added successfully! 🎉" : "Failed to find user. Check your entry.")),
                    );
                  }
                }
              },
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.midnightAccent),
              child: const Text("Add", style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
            ),
          ],
        );
      },
    );
  }

  void _handleJoinRoom(String roomId, String hostName) {
    ref.read(audioPlayerProvider.notifier).joinSession(roomId);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Instantly synced with $hostName!")));
    }
  }

  @override
  Widget build(BuildContext context) {
    _ensureStreams();
    ref.watch(audioPlayerProvider); // Watch for theme changes
    return Scaffold(
      backgroundColor: context.themeBackgroundColor,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      IconButton(
                        icon: Icon(Icons.arrow_back, color: context.themeTextColor),
                        onPressed: () {
                          if (context.canPop()) {
                            context.pop();
                          } else {
                            context.go('/');
                          }
                        },
                        padding: EdgeInsets.zero,
                        alignment: Alignment.centerLeft,
                      ),
                      Text(
                        "Social",
                        style: GoogleFonts.outfit(
                          fontSize: 36,
                          fontWeight: FontWeight.w900,
                          color: context.themeTextColor,
                        ),
                      ),
                    ],
                  ),
                  IconButton(
                    icon: Icon(Icons.person_add_rounded, color: context.themeTextColor),
                    onPressed: _showAddFriendDialog,
                    tooltip: "Add Friend",
                  ),
                ],
              ),
            ),
            TabBar(
              controller: _tabController,
              indicatorColor: context.themeAccentColor,
              labelColor: context.themeAccentColor,
              unselectedLabelColor: context.themeMutedTextColor,
              tabs: const [
                Tab(text: "INBOX 📥"),
                Tab(text: "FRIENDS 👥"),
              ],
            ),
            Expanded(
              child: StreamBuilder<User?>(
                stream: auth.authStateChanges(),
                builder: (context, authSnapshot) {
                  final user = authSnapshot.data;
                  if (user == null || user.isAnonymous) {
                    return Center(
                      child: Padding(
                        padding: const EdgeInsets.all(32.0),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Container(
                              padding: const EdgeInsets.all(20),
                              decoration: BoxDecoration(
                                color: context.themeAccentColor.withValues(alpha: 0.15),
                                shape: BoxShape.circle,
                              ),
                              child: Icon(Icons.people_alt_rounded, size: 48, color: context.themeAccentColor),
                            ),
                            const SizedBox(height: 20),
                            Text(
                              "Connect & Share Music",
                              style: GoogleFonts.outfit(
                                color: context.themeTextColor,
                                fontSize: 22,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              "Sign in to your account to send tracks, listen together in real-time rooms, and add friends.",
                              textAlign: TextAlign.center,
                              style: GoogleFonts.inter(
                                color: context.themeMutedTextColor,
                                fontSize: 14,
                                height: 1.4,
                              ),
                            ),
                            const SizedBox(height: 24),
                            ElevatedButton.icon(
                              onPressed: () => AuthBottomSheet.show(context),
                              icon: const Icon(Icons.login_rounded, size: 20),
                              label: const Text("Sign In / Register", style: TextStyle(fontWeight: FontWeight.bold)),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: context.themeAccentColor,
                                foregroundColor: context.themeInvertedTextColor,
                                elevation: 0,
                                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  }

                  return TabBarView(
                    controller: _tabController,
                    children: [
                      _buildInboxTab(),
                      _buildFriendsTab(),
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInboxTab() {
    return StreamBuilder<QuerySnapshot>(
      stream: _inboxStream,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const SkeletonLoadingList();
        }
        if (snapshot.hasError) {
          return Center(child: Text("Failed to load inbox.", style: GoogleFonts.inter(color: context.themeMutedTextColor)));
        }
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return PremiumEmptyState(
            icon: Icons.mark_email_unread_rounded,
            title: "Your inbox is empty",
            message: "Tell your friends to send you music!",
            ctaText: "Find Friends",
            onCtaPressed: _showAddFriendDialog,
          );
        }

        final items = snapshot.data!.docs;
        return ListView.builder(
          padding: EdgeInsets.only(left: 16, top: 16, right: 16, bottom: AppDimensions.bottomClearance + MediaQuery.of(context).viewPadding.bottom),
          itemCount: items.length,
          itemBuilder: (context, index) {
            try {
            return Consumer(
              builder: (context, ref, child) {
                final item = items[index];
                final data = item.data() as Map<String, dynamic>;
                final docId = item.id;
                final msgType = data['type'] as String? ?? 'song';
                final isPlaylist = msgType == 'playlist';
                final isRoomInvite = msgType == 'room_invite';
                final isReaction = msgType == 'reaction';
                final isVideo = msgType == 'video';

                Song? song;
                CustomPlaylist? playlist;
                Map<String, dynamic> payload = data['payload'] is Map ? Map<String, dynamic>.from(data['payload']) : {};
                
                if (isPlaylist) {
                  playlist = CustomPlaylist.fromJson(payload);
                } else if (msgType == 'song') {
                  song = Song.fromJson(payload);
                }

                final senderName = data['senderName'] ?? 'Someone';
                final reactions = Map<String, String>.from(data['reactions'] ?? {});
                final isRead = data['isRead'] as bool? ?? true;
                
                return Dismissible(
                  key: Key(docId),
                  direction: DismissDirection.endToStart,
                  background: Container(
                    alignment: Alignment.centerRight,
                    padding: const EdgeInsets.only(right: 20.0),
                    color: Colors.redAccent,
                    child: const Icon(Icons.delete, color: Colors.white),
                  ),
                  onDismissed: (direction) {
                    _socialService.deleteMessage(docId);
                  },
                  child: Container(
                    margin: const EdgeInsets.only(left: 16, right: 64, top: 8, bottom: 8),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          context.themeSurfaceColor,
                          context.themeAccentColor.withValues(alpha: 0.15),
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: const BorderRadius.only(
                        topLeft: Radius.circular(20),
                        topRight: Radius.circular(20),
                        bottomRight: Radius.circular(20),
                        bottomLeft: Radius.circular(4),
                      ),
                      border: isRead ? null : Border.all(color: context.themeAccentColor, width: 1.5),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.2),
                          blurRadius: 10,
                          offset: const Offset(0, 5),
                        ),
                      ],
                    ),
                    child: Column(
                      children: [
                        ListTile(
                          contentPadding: const EdgeInsets.all(12),
                          leading: ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: isPlaylist
                                ? Container(
                                    width: 56, height: 56, color: context.themeAccentColor.withValues(alpha: 0.2),
                                    child: Icon(Icons.queue_music_rounded, color: context.themeAccentColor, size: 32),
                                  )
                                : isRoomInvite
                                    ? Container(
                                        width: 56, height: 56, color: Colors.amber.withValues(alpha: 0.2),
                                        child: const Icon(Icons.groups_rounded, color: Colors.amber, size: 32),
                                      )
                                    : isReaction
                                        ? Container(
                                            width: 56, height: 56, color: Colors.pinkAccent.withValues(alpha: 0.2),
                                            child: Center(child: Text(payload['emoji'] ?? '❤️', style: const TextStyle(fontSize: 28))),
                                          )
                                        : isVideo
                                            ? CustomImageWidget(imageUrl: payload['thumbnail'] ?? '', width: 100, height: 56, fit: BoxFit.cover)
                                            : CustomImageWidget(imageUrl: song?.coverArt ?? '', width: 56, height: 56),
                          ),
                          title: Text(
                            isPlaylist
                                ? playlist!.title
                                : isRoomInvite
                                    ? "Listen Together Room 🎧"
                                    : isReaction
                                        ? "$senderName reacted ${payload['emoji'] ?? ''}"
                                        : isVideo
                                            ? (payload['title'] ?? 'YouTube Video')
                                            : (song?.title ?? 'Music Track'),
                            style: GoogleFonts.inter(fontWeight: FontWeight.bold, color: context.themeTextColor),
                          ),
                          subtitle: Text(
                            isPlaylist
                                ? "Sent by $senderName • ${playlist!.songs.length} songs"
                                : isRoomInvite
                                    ? "Invited by $senderName"
                                    : isReaction
                                        ? "on ${payload['targetTitle'] ?? 'Track'}"
                                        : isVideo
                                            ? "Video from $senderName"
                                            : "Sent by $senderName",
                            style: GoogleFonts.inter(color: context.themeMutedTextColor, fontSize: 12),
                          ),
                          trailing: isPlaylist 
                            ? IconButton(
                                icon: Icon(Icons.download_rounded, color: context.themeAccentColor, size: 36),
                                onPressed: () {
                                  _socialService.markAsRead(docId);
                                  ref.read(customPlaylistProvider.notifier).createPlaylistWithSongs(playlist!.title, playlist.songs);
                                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Playlist saved to Library!")));
                                },
                              )
                            : isRoomInvite
                                ? ElevatedButton(
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: context.themeAccentColor,
                                      foregroundColor: context.themeInvertedTextColor,
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                    ),
                                    onPressed: () {
                                      _socialService.markAsRead(docId);
                                      final roomId = payload['roomId'] as String?;
                                      final host = payload['hostName'] as String? ?? senderName;
                                      if (roomId != null && roomId.isNotEmpty) {
                                        _handleJoinRoom(roomId, host);
                                      }
                                    },
                                    child: const Text("Join Room", style: TextStyle(fontWeight: FontWeight.bold)),
                                  )
                                : isReaction
                                    ? const SizedBox.shrink()
                                    : isVideo
                                        ? Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              IconButton(
                                                icon: const Icon(Icons.group_add_rounded, color: Colors.amber),
                                                tooltip: "Watch Together",
                                                onPressed: () async {
                                                  await _socialService.markAsRead(docId);
                                                  final roomId = await locator<RoomService>().createVideoRoom(
                                                    myUid, 
                                                    payload, 
                                                    Duration.zero, 
                                                    true,
                                                    allowGuestControl: true 
                                                  );
                                                  ref.read(videoPlayerProvider.notifier).startVideoRoom(roomId, payload, isHost: true);
                                                  // Don't push to full screen, stay in miniplayer as requested by user
                                                  if (!context.mounted) return;
                                                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Video Room created! ID: $roomId")));
                                                },
                                              ),
                                              IconButton(
                                                icon: const Icon(Icons.play_circle_fill_rounded, color: Colors.red, size: 42),
                                                onPressed: () {
                                                  _socialService.markAsRead(docId);
                                                  ref.read(videoPlayerProvider.notifier).playVideo(
                                                    payload['id'] ?? '',
                                                    payload['title'] ?? 'Unknown',
                                                    payload['uploader'] ?? 'YouTube',
                                                  );
                                                  context.push('/video_player');
                                                },
                                              ),
                                            ],
                                          )
                                        : IconButton(
                                            icon: Icon(Icons.play_circle_fill_rounded, color: context.themeAccentColor, size: 42),
                                            onPressed: () {
                                              _socialService.markAsRead(docId);
                                              if (song != null) {
                                                ref.read(audioPlayerProvider.notifier).playSong(song);
                                              }
                                            },
                                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          child: Row(
                            children: [
                              _buildReactionButton(docId, "🔥", reactions[myUid] == "🔥"),
                              _buildReactionButton(docId, "❤️", reactions[myUid] == "❤️"),
                              _buildReactionButton(docId, "🎵", reactions[myUid] == "🎵"),
                              const Spacer(),
                              if (reactions.isNotEmpty)
                                Text(reactions.values.toSet().join(" "), style: const TextStyle(fontSize: 16)),
                            ],
                          ),
                        )
                      ],
                    ),
                  ),
                );
              },
            );
            } catch (e) {
              return const SizedBox.shrink();
            }
          },
        );
      },
    );
  }

  Widget _buildReactionButton(String messageId, String emoji, bool isSelected) {
    return GestureDetector(
      onTap: () => _socialService.reactToMessage(messageId, emoji),
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 4),
        padding: const EdgeInsets.all(6),
        decoration: BoxDecoration(
          color: isSelected ? context.themeAccentColor.withValues(alpha: 0.2) : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(emoji, style: const TextStyle(fontSize: 20)),
      ),
    );
  }


  Widget _buildFriendsTab() {
    return Column(
      children: [
        StreamBuilder<DocumentSnapshot>(
          stream: firestore.collection('client_config').doc('social').snapshots(),
          builder: (context, snapshot) {
            if (snapshot.hasData && snapshot.data!.exists) {
              final data = snapshot.data!.data() as Map<String, dynamic>?;
              final announcement = data?['announcement'] as String?;
              if (announcement != null && announcement.isNotEmpty) {
                return Container(
                  width: double.infinity,
                  margin: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.amberAccent.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.amberAccent),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.campaign_rounded, color: Colors.amberAccent),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          announcement,
                          style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.w500, fontSize: 13),
                        ),
                      ),
                    ],
                  ),
                );
              }
            }
            return const SizedBox.shrink();
          },
        ),
        
        Padding(
          padding: const EdgeInsets.all(16),
          child: StreamBuilder<DocumentSnapshot>(
            stream: firestore.collection('users').doc(myUid).snapshots(),
            builder: (context, snapshot) {
              String myUsername = "Loading...";
              if (snapshot.hasData && snapshot.data!.exists) {
                final docData = snapshot.data!.data() as Map<String, dynamic>?;
                myUsername = docData?['username'] ?? 'No Username';
              }
              return InkWell(
                onTap: () {
                  Clipboard.setData(ClipboardData(text: myUsername));
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("$myUsername copied to clipboard!")));
                },
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: context.themeSurfaceColor,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.midnightAccent.withValues(alpha: 0.3)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.copy_rounded, color: AppColors.midnightAccent),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text("Your Handle", style: GoogleFonts.inter(fontWeight: FontWeight.bold, color: context.themeTextColor)),
                            Text("$myUsername • UID: $myUid", style: GoogleFonts.inter(color: context.themeMutedTextColor, fontSize: 12), maxLines: 1, overflow: TextOverflow.ellipsis),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }
          ),
        ),
        Expanded(
          child: StreamBuilder<DocumentSnapshot>(
            stream: _friendsStream,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const SkeletonLoadingList();
              }
              if (snapshot.hasError) {
                return Center(child: Text("Failed to load friends.", style: GoogleFonts.inter(color: context.themeMutedTextColor)));
              }

              final docData = snapshot.hasData && snapshot.data!.exists 
                  ? snapshot.data!.data() as Map<String, dynamic>? 
                  : null;
                  
              List<String> friends = [];
              try {
                if (docData != null && docData['friends'] is List) {
                  final rawFriends = docData['friends'] as List;
                  for (var e in rawFriends) {
                    if (e is String) {
                      friends.add(e);
                    }
                  }
                }
              } catch (e) {
                debugPrint('Error parsing friends: $e');
              }

              if (friends.isEmpty) {
                return PremiumEmptyState(
                  icon: Icons.people_alt_rounded,
                  title: "No friends yet",
                  message: "You haven't added any friends yet.\nUse the button below to add some!",
                  ctaText: "Add Friend",
                  onCtaPressed: _showAddFriendDialog,
                );
              }

              return ListView.builder(
                padding: EdgeInsets.only(left: 16, top: 16, right: 16, bottom: AppDimensions.bottomClearance + MediaQuery.of(context).viewPadding.bottom),
                itemCount: friends.length,
                itemBuilder: (context, index) {
                  try {
                    final friendUid = friends[index];
                    
                    return Consumer(
                      builder: (context, ref, child) {
                        final friendSnap = ref.watch(friendDetailsProvider(friendUid));
                        
                        return friendSnap.when(
                          loading: () => ListTile(
                            leading: CircleAvatar(backgroundColor: context.themeAccentColor.withValues(alpha: 0.3)),
                            title: Container(height: 12, width: 100, color: context.themeAccentColor.withValues(alpha: 0.1)),
                          ),
                          error: (e, st) => const SizedBox.shrink(),
                          data: (friend) {
                            if (friend == null) return const SizedBox.shrink();

                            final displayName = friend['displayName'] as String? ?? 'Friend';
                            final username = friend['username'] as String? ?? '';
                    
                            return ListTile(
                              onTap: () {
                                Navigator.push(context, MaterialPageRoute(builder: (_) => FriendProfileScreen(friendUid: friendUid, friendName: displayName)));
                              },
                              leading: CircleAvatar(
                                backgroundColor: AppColors.midnightAccent,
                                child: Text(displayName.isNotEmpty ? displayName[0].toUpperCase() : '?', style: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
                              ),
                              title: Text(displayName, style: GoogleFonts.inter(fontWeight: FontWeight.bold, color: context.themeTextColor)),
                              subtitle: StreamBuilder<DatabaseEvent>(
                                stream: _socialService.getPresenceStream(friendUid),
                                builder: (context, presenceSnap) {
                                  if (presenceSnap.hasData && presenceSnap.data!.snapshot.value != null) {
                                    try {
                                      final presenceData = Map<String, dynamic>.from(presenceSnap.data!.snapshot.value as Map);
                                      
                                      if (presenceData['is_playing'] == true) {
                                        return Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                const Icon(Icons.circle, color: Colors.greenAccent, size: 10),
                                                const SizedBox(width: 4),
                                                Flexible(
                                                  child: Text(
                                                    "Listening to ${presenceData['song_title']}",
                                                    style: GoogleFonts.inter(color: Colors.greenAccent, fontSize: 12),
                                                    maxLines: 1,
                                                    overflow: TextOverflow.ellipsis,
                                                  ),
                                                ),
                                              ],
                                            ),
                                            if (presenceData['room_id'] != null) ...[
                                              const SizedBox(height: 4),
                                              ElevatedButton(
                                                style: ElevatedButton.styleFrom(
                                                  backgroundColor: AppColors.midnightPrimary,
                                                  foregroundColor: Colors.white,
                                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 0),
                                                  minimumSize: const Size(80, 28),
                                                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                                ),
                                                onPressed: () {
                                                  _handleJoinRoom(presenceData['room_id'], displayName);
                                                },
                                                child: const Text("Join Room", style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold)),
                                              ),
                                            ],
                                          ],
                                        );
                                      }
                                    } catch (_) {}
                                  }
                                  return Text(username, style: GoogleFonts.inter(color: context.themeMutedTextColor, fontSize: 12));
                                },
                              ),
                              trailing: PopupMenuButton<String>(
                                icon: Icon(Icons.more_vert, color: context.themeMutedTextColor),
                                onSelected: (val) {
                                  if (val == 'remove') {
                                    showDialog(
                                      context: context,
                                      builder: (ctx) => AlertDialog(
                                        backgroundColor: context.themeSurfaceColor,
                                        title: Text("Remove Friend", style: TextStyle(color: context.themeTextColor)),
                                        content: Text("Are you sure you want to remove $displayName?", style: TextStyle(color: context.themeMutedTextColor)),
                                        actions: [
                                          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Cancel")),
                                          ElevatedButton(
                                            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
                                            onPressed: () {
                                              _socialService.removeFriend(friendUid);
                                              Navigator.pop(ctx);
                                            },
                                            child: const Text("Remove", style: TextStyle(color: Colors.white)),
                                          ),
                                        ],
                                      ),
                                    );
                                  }
                                },
                                itemBuilder: (context) => [
                                  const PopupMenuItem(value: 'remove', child: Text("Remove Friend", style: TextStyle(color: Colors.redAccent))),
                                ],
                              ),
                            );
                          },
                        );
                      },
                    );
                  } catch (e) {
                    return const SizedBox.shrink();
                  }
                },
              );
            },
          ),
        ),
      ],
    );
  }
}
