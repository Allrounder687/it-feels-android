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
import 'package:it_feels_music/features/player/audio_player_provider.dart';

class SocialScreen extends StatefulWidget {
  const SocialScreen({super.key});

  @override
  State<SocialScreen> createState() => _SocialScreenState();
}

class _SocialScreenState extends State<SocialScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final SocialService _socialService = locator<SocialService>();
  final String myUid = FirebaseAuth.instance.currentUser?.uid ?? '';

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
              hintText: "Enter Friend's UID",
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
                final uid = uidController.text.trim();
                if (uid.isNotEmpty) {
                  final success = await _socialService.addFriendByUid(uid);
                  if (mounted) {
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text(success ? "Friend added successfully! 🎉" : "Failed to add friend. Check UID.")),
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
              child: TabBarView(
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

        final docs = snapshot.data!.docs;
        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: docs.length,
          itemBuilder: (context, index) {
            final doc = docs[index];
            final data = doc.data() as Map<String, dynamic>;
            final senderName = data['senderName'] ?? 'A friend';
            final songData = data['payload'] as Map<String, dynamic>;
            final song = Song.fromJson(songData);
            final reactions = Map<String, String>.from(data['reactions'] ?? {});
            
            return Card(
              color: context.themeSurfaceColor,
              margin: const EdgeInsets.only(bottom: 16),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text("Sent by $senderName", style: GoogleFonts.inter(fontWeight: FontWeight.bold, color: AppColors.midnightAccent)),
                    const SizedBox(height: 8),
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: CustomImageWidget(url: song.coverArt, width: 50, height: 50),
                      ),
                      title: Text(song.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: context.themeTextColor)),
                      subtitle: Text(song.artist, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: context.themeMutedTextColor)),
                      trailing: Consumer(
                        builder: (context, ref, child) {
                          return IconButton(
                            icon: const Icon(Icons.play_circle_fill, color: AppColors.midnightAccent, size: 36),
                            onPressed: () {
                              ref.read(audioPlayerProvider.notifier).playSong(song);
                            },
                          );
                        }
                      ),
                    ),
                    const Divider(color: Colors.white10),
                    Row(
                      children: [
                        Text("React: ", style: TextStyle(color: context.themeMutedTextColor)),
                        _buildReactionButton(doc.id, "🔥", reactions[myUid] == "🔥"),
                        _buildReactionButton(doc.id, "❤️", reactions[myUid] == "❤️"),
                        _buildReactionButton(doc.id, "🎵", reactions[myUid] == "🎵"),
                        const Spacer(),
                        if (reactions.isNotEmpty)
                          Text(reactions.values.join(" "), style: const TextStyle(fontSize: 16)),
                      ],
                    )
                  ],
                ),
              ),
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
        Padding(
          padding: const EdgeInsets.all(16),
          child: InkWell(
            onTap: () {
              Clipboard.setData(ClipboardData(text: myUid));
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("UID copied to clipboard!")));
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
                        Text("Your Unique ID", style: GoogleFonts.inter(fontWeight: FontWeight.bold, color: context.themeTextColor)),
                        Text(myUid, style: GoogleFonts.inter(color: context.themeMutedTextColor, fontSize: 12), maxLines: 1, overflow: TextOverflow.ellipsis),
                      ],
                    ),
                  ),
                ],
              ),
            ),
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
                      final name = friendSnap.data?['name'] ?? 'IT-Feels User';
                      return ListTile(
                        leading: CircleAvatar(
                          backgroundColor: AppColors.midnightAccent,
                          child: Text(name[0].toUpperCase(), style: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
                        ),
                        title: Text(name, style: TextStyle(color: context.themeTextColor)),
                        subtitle: Text("Friend", style: TextStyle(color: context.themeMutedTextColor)),
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
