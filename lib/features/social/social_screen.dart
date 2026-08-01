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

class SocialScreen extends StatefulWidget {
  const SocialScreen({super.key});

  @override
  State<SocialScreen> createState() => _SocialScreenState();
}

class _SocialScreenState extends State<SocialScreen> with SingleTickerProviderStateMixin {
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
              child: myUid.isEmpty
                  ? Center(
                      child: Text(
                        "Please log in to use Social features.",
                        style: GoogleFonts.inter(color: context.themeTextColor, fontSize: 16),
                      ),
                    )
                  : TabBarView(
                      controller: _tabController,
                      children: [
                        _buildInboxTab(),
                        _buildFriendsTab(),
                      ],
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
                final song = Song.fromJson(data['payload'] as Map<String, dynamic>);
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
                      border: isRead ? null : Border.all(color: AppColors.midnightAccent, width: 1.5),
                    ),
                    child: Column(
                      children: [
                        ListTile(
                          contentPadding: const EdgeInsets.all(12),
                          leading: ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: CustomImageWidget(imageUrl: song.coverArt, width: 56, height: 56),
                          ),
                          title: Text(song.title, style: GoogleFonts.inter(fontWeight: FontWeight.bold, color: context.themeTextColor)),
                          subtitle: Text("Sent by $senderName", style: GoogleFonts.inter(color: context.themeMutedTextColor, fontSize: 12)),
                          trailing: IconButton(
                            icon: const Icon(Icons.play_circle_fill_rounded, color: AppColors.midnightAccent, size: 42),
                            onPressed: () {
                              _socialService.markAsRead(docId);
                              ref.read(audioPlayerProvider.notifier).playSong(song);
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
          color: isSelected ? AppColors.midnightAccent.withValues(alpha: 0.2) : Colors.transparent,
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
                      final name = friendSnap.data?['name'] ?? 'Friend';
                      final username = friendSnap.data?['username'] ?? '';
                      return ListTile(
                        leading: CircleAvatar(
                          backgroundColor: AppColors.midnightAccent,
                          child: Text(name.isNotEmpty ? name[0].toUpperCase() : '?', style: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
                        ),
                        title: Text(name, style: GoogleFonts.inter(fontWeight: FontWeight.bold, color: context.themeTextColor)),
                        subtitle: StreamBuilder<DatabaseEvent>(
                          stream: _socialService.getPresenceStream(friendUid),
                          builder: (context, presenceSnap) {
                            if (presenceSnap.hasData && presenceSnap.data!.snapshot.value != null) {
                              final presenceData = Map<String, dynamic>.from(presenceSnap.data!.snapshot.value as Map);
                              if (presenceData['is_playing'] == true) {
                                return Row(
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
                                );
                              }
                            }
                            return Text(username, style: GoogleFonts.inter(color: context.themeMutedTextColor, fontSize: 12));
                          },
                        ),
                        trailing: IconButton(
                          icon: const Icon(Icons.person_remove_rounded, color: Colors.redAccent),
                          onPressed: () {
                            showDialog(
                              context: context,
                              builder: (ctx) => AlertDialog(
                                backgroundColor: context.themeSurfaceColor,
                                title: Text("Remove Friend", style: TextStyle(color: context.themeTextColor)),
                                content: Text("Are you sure you want to remove $name?", style: TextStyle(color: context.themeMutedTextColor)),
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
                          },
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
