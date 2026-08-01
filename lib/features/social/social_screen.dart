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
import 'package:it_feels_music/core/widgets/custom_image_widget.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:it_feels_music/core/providers/riverpod_bridge.dart';
import 'package:it_feels_music/data/models/custom_playlist.dart';
import 'package:it_feels_music/features/social/room_service.dart';
import 'package:it_feels_music/features/auth/auth_bottom_sheet.dart';
class SocialScreen extends ConsumerStatefulWidget {
  const SocialScreen({super.key});

  @override
  ConsumerState<SocialScreen> createState() => _SocialScreenState();
}

class _SocialScreenState extends ConsumerState<SocialScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final SocialService _socialService = locator<SocialService>();
  String get myUid => FirebaseAuth.instance.currentUser?.uid ?? '';

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
    final user = FirebaseAuth.instance.currentUser;
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
    locator<RoomService>().requestJoinRoom(roomId);
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        final sub = locator<RoomService>().listenToAllowedStatus(roomId, myUid).listen((event) {
          if (event.snapshot.value == true) {
            if (ctx.mounted) {
              Navigator.pop(ctx);
              ref.read(audioPlayerProvider.notifier).joinSession(roomId);
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Joined $hostName's room!")));
              }
            }
          }
        });

        return AlertDialog(
          backgroundColor: context.themeSurfaceColor,
          title: Text("Connecting...", style: TextStyle(color: context.themeTextColor)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const CircularProgressIndicator(color: AppColors.midnightAccent),
              const SizedBox(height: 16),
              Text("Waiting for $hostName to accept your request.", style: TextStyle(color: context.themeMutedTextColor), textAlign: TextAlign.center),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                sub.cancel();
                locator<RoomService>().declineJoinRequest(roomId, myUid);
                Navigator.pop(ctx);
              },
              child: const Text("Cancel"),
            ),
          ],
        );
      },
    ).then((_) {
      // Ensure subscription is cancelled if dialog is dismissed
      // The listen is already cancelled in the onPressed, but we should make sure
    });
  }

  @override
  Widget build(BuildContext context) {
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
                  Text(
                    "Social",
                    style: GoogleFonts.outfit(
                      fontSize: 36,
                      fontWeight: FontWeight.w900,
                      color: context.themeTextColor,
                    ),
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
              indicatorColor: AppColors.midnightAccent,
              labelColor: AppColors.midnightAccent,
              unselectedLabelColor: context.themeMutedTextColor,
              tabs: const [
                Tab(text: "INBOX 📥"),
                Tab(text: "FRIENDS 👥"),
              ],
            ),
            Expanded(
              child: StreamBuilder<User?>(
                stream: FirebaseAuth.instance.authStateChanges(),
                builder: (context, snapshot) {
                  final user = snapshot.data;
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
                                color: AppColors.midnightAccent.withValues(alpha: 0.15),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(Icons.people_alt_rounded, size: 48, color: AppColors.midnightAccent),
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
                                backgroundColor: AppColors.midnightAccent,
                                foregroundColor: Colors.black,
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
      stream: _socialService.getInboxStream(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator(color: AppColors.midnightAccent));
        }
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return Center(
            child: Text("Your inbox is empty 📭\nTell your friends to send you music!", 
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(color: context.themeMutedTextColor),
            ),
          );
        }

        final items = snapshot.data!.docs;
        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: items.length,
          itemBuilder: (context, index) {
            return Consumer(
              builder: (context, ref, child) {
                final item = items[index];
                final data = item.data() as Map<String, dynamic>;
                final docId = item.id;
                final msgType = data['type'] as String? ?? 'song';
                final isPlaylist = msgType == 'playlist';
                final isRoomInvite = msgType == 'room_invite';
                final isReaction = msgType == 'reaction';

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
                    margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      color: context.themeSurfaceColor,
                      borderRadius: BorderRadius.circular(16),
                      border: isRead ? null : Border.all(color: context.themeAccentColor, width: 1.5),
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
                                        : CustomImageWidget(imageUrl: song?.coverArt ?? '', width: 56, height: 56),
                          ),
                          title: Text(
                            isPlaylist
                                ? playlist!.title
                                : isRoomInvite
                                    ? "Listen Together Room 🎧"
                                    : isReaction
                                        ? "$senderName reacted ${payload['emoji'] ?? ''}"
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
          stream: FirebaseFirestore.instance.collection('client_config').doc('social').snapshots(),
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
            stream: FirebaseFirestore.instance.collection('users').doc(myUid).snapshots(),
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
            stream: _socialService.getFriendsStream(),
            builder: (context, snapshot) {
              if (!snapshot.hasData || !snapshot.data!.exists) {
                return const Center(child: CircularProgressIndicator());
              }
              
              final data = snapshot.data!.data() as Map<String, dynamic>?;
              final friends = List<String>.from(data?['friends'] ?? []);

              if (friends.isEmpty) {
                return Center(
                  child: Text("You have no friends yet 🥲\nShare your UID to connect!", 
                    textAlign: TextAlign.center,
                    style: GoogleFonts.inter(color: context.themeMutedTextColor),
                  ),
                );
              }

              return ListView.builder(
                itemCount: friends.length,
                itemBuilder: (context, index) {
                  final friendUid = friends[index];
                  return FutureBuilder<Map<String, dynamic>?>(
                    future: _socialService.getFriendDetails(friendUid),
                    builder: (context, friendSnap) {
                      final firestoreData = (snapshot.data!.data() as Map<String, dynamic>?) ?? {};
                      final friendNames = Map<String, String>.from(firestoreData['friend_names'] ?? {});
                      final nickname = friendNames[friendUid];
                      
                      final realName = friendSnap.data?['name'] ?? 'Friend';
                      final displayName = nickname ?? realName;
                      final username = friendSnap.data?['username'] ?? '';
                      return ListTile(
                        leading: CircleAvatar(
                          backgroundColor: AppColors.midnightAccent,
                          child: Text(displayName.isNotEmpty ? displayName[0].toUpperCase() : '?', style: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
                        ),
                        title: Text(displayName, style: GoogleFonts.inter(fontWeight: FontWeight.bold, color: context.themeTextColor)),
                        subtitle: StreamBuilder<DatabaseEvent>(
                          stream: _socialService.getPresenceStream(friendUid),
                          builder: (context, presenceSnap) {
                            if (presenceSnap.hasData && presenceSnap.data!.snapshot.value != null) {
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
                                      InkWell(
                                        onTap: () {
                                          _handleJoinRoom(presenceData['room_id'], displayName);
                                        },
                                        child: Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                          decoration: BoxDecoration(
                                            color: AppColors.midnightPrimary,
                                            borderRadius: BorderRadius.circular(8),
                                          ),
                                          child: const Text("Join Room", style: TextStyle(fontSize: 10, color: Colors.white, fontWeight: FontWeight.bold)),
                                        ),
                                      ),
                                    ],
                                  ],
                                );
                              }
                            }
                            return Text(nickname != null ? "($realName) • $username" : username, style: GoogleFonts.inter(color: context.themeMutedTextColor, fontSize: 12));
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
                            } else if (val == 'rename') {
                              final tc = TextEditingController(text: nickname ?? realName);
                              showDialog(
                                context: context,
                                builder: (ctx) => AlertDialog(
                                  backgroundColor: context.themeSurfaceColor,
                                  title: Text("Set Nickname", style: TextStyle(color: context.themeTextColor)),
                                  content: TextField(
                                    controller: tc,
                                    style: TextStyle(color: context.themeTextColor),
                                    decoration: InputDecoration(
                                      hintText: "Nickname",
                                      hintStyle: TextStyle(color: context.themeMutedTextColor),
                                    ),
                                  ),
                                  actions: [
                                    TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Cancel")),
                                    ElevatedButton(
                                      style: ElevatedButton.styleFrom(backgroundColor: AppColors.midnightPrimary),
                                      onPressed: () {
                                        _socialService.setFriendNickname(friendUid, tc.text.trim());
                                        Navigator.pop(ctx);
                                      },
                                      child: const Text("Save", style: TextStyle(color: Colors.white)),
                                    ),
                                  ],
                                ),
                              );
                            }
                          },
                          itemBuilder: (context) => [
                            const PopupMenuItem(value: 'rename', child: Text("Set Nickname")),
                            const PopupMenuItem(value: 'remove', child: Text("Remove Friend", style: TextStyle(color: Colors.redAccent))),
                          ],
                        ),
                      );
                    },
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }
}
