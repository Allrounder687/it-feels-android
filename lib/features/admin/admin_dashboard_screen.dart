import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'dart:io';
import 'package:window_manager/window_manager.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:it_feels_music/core/theme/theme_ext.dart';
import 'package:it_feels_music/core/theme/app_colors.dart';
import 'package:timeago/timeago.dart' as timeago;
import 'package:it_feels_music/data/models/badge_model.dart';

enum AdminFilter { all, online, premium, banned }

class AdminDashboardScreen extends StatefulWidget {
  const AdminDashboardScreen({super.key});

  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen> {
  final TextEditingController _searchController = TextEditingController();
  AdminFilter _currentFilter = AdminFilter.all;
  String _sortBy = 'lastActive';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  String _formatDuration(int seconds) {
    if (seconds < 60) return '${seconds}s';
    if (seconds < 3600) return '${(seconds / 60).floor()}m';
    return '${(seconds / 3600).toStringAsFixed(1)}h';
  }

  void _toggleBan(String uid, bool currentStatus) async {
    try {
      await FirebaseFirestore.instance.collection('users').doc(uid).set(
        {'isBanned': !currentStatus},
        SetOptions(merge: true),
      );
    } catch (e) {
      debugPrint('[AdminDashboard] Failed to toggle ban: $e');
    }
  }

  void _togglePremium(String uid, bool currentStatus) async {
    try {
      await FirebaseFirestore.instance.collection('users').doc(uid).set(
        {'isPremiumFamily': !currentStatus},
        SetOptions(merge: true),
      );
    } catch (e) {
      debugPrint('[AdminDashboard] Failed to toggle premium: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.themeBackgroundColor,
      appBar: AppBar(
        flexibleSpace: kIsWeb ? null : (!Platform.isWindows && !Platform.isMacOS && !Platform.isLinux ? null : const DragToMoveArea(child: SizedBox.expand())),
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: context.themeTextColor),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          "Admin Dashboard",
          style: GoogleFonts.outfit(
            fontSize: 22,
            fontWeight: FontWeight.w800,
            color: context.themeTextColor,
          ),
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.people_alt, color: context.themeTextColor),
            onPressed: () => _showSocialAnnouncementDialog(context),
            tooltip: 'Set Social Announcement',
          ),
          IconButton(
            icon: Icon(Icons.campaign, color: context.themeTextColor),
            onPressed: () => _showBroadcastDialog(context),
            tooltip: 'Send Global Broadcast',
          ),
        ],
      ),
      body: Column(
        children: [
          // Search & Filters
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
            child: Column(
              children: [
                TextField(
                  controller: _searchController,
                  onChanged: (value) => setState(() {}),
                  style: TextStyle(color: context.themeTextColor),
                  decoration: InputDecoration(
                    hintText: 'Search by email, UID, or device...',
                    hintStyle: TextStyle(color: context.themeMutedTextColor),
                    prefixIcon: Icon(Icons.search, color: context.themeMutedTextColor),
                    filled: true,
                    fillColor: context.themeSurfaceColor,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: [
                            _buildFilterChip("All", AdminFilter.all),
                            _buildFilterChip("Online", AdminFilter.online),
                            _buildFilterChip("Premium", AdminFilter.premium),
                            _buildFilterChip("Banned", AdminFilter.banned),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    _buildSortDropdown(),
                  ],
                ),
              ],
            ),
          ),
          
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance.collection('users').orderBy(_sortBy, descending: true).snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator(color: AppColors.midnightAccent));
          }
          if (snapshot.hasError) {
            return Center(child: Text("Error fetching data: ${snapshot.error}", style: TextStyle(color: context.themeTextColor)));
          }

          var docs = snapshot.data?.docs ?? [];
          
          // Apply Filters
          docs = docs.where((doc) {
            final data = doc.data() as Map<String, dynamic>? ?? {};
            final uid = doc.id;
            final email = data['email'] ?? uid;
            final deviceModel = data['deviceInfo'] ?? data['deviceModel'] ?? 'Unknown Device';
            final isOnline = data['isOnline'] ?? false;
            final isBanned = data['isBanned'] ?? false;
            final isPremium = data['isPremiumFamily'] ?? false;

            // Search query
            final query = _searchController.text.toLowerCase();
            if (query.isNotEmpty) {
              if (!email.toLowerCase().contains(query) && 
                  !uid.toLowerCase().contains(query) &&
                  !deviceModel.toLowerCase().contains(query)) {
                return false;
              }
            }

            // Choice filter
            switch (_currentFilter) {
              case AdminFilter.all:
                break;
              case AdminFilter.online:
                if (!isOnline) return false;
                break;
              case AdminFilter.premium:
                if (!isPremium) return false;
                break;
              case AdminFilter.banned:
                if (!isBanned) return false;
                break;
            }

            return true;
          }).toList();

          if (docs.isEmpty) {
            return Center(
              child: Text(
                "No users found.",
                style: GoogleFonts.inter(color: context.themeMutedTextColor, fontSize: 16),
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            itemCount: docs.length,
            itemBuilder: (context, index) {
              final data = docs[index].data() as Map<String, dynamic>? ?? {};
              final uid = docs[index].id;
              
              final isOnline = data['isOnline'] ?? false;
              final isBanned = data['isBanned'] ?? false;
              final isPremium = data['isPremiumFamily'] ?? false;
              final email = data['email'] ?? uid; // Fallback to UID if email not present
              final deviceModel = data['deviceInfo'] ?? data['deviceModel'] ?? 'Unknown Device';
              final totalSeconds = data['totalUsageSeconds'] ?? 0;
              final rawLocation = data['location'];
              String locationStr = 'Unknown Location';
              if (rawLocation is String) {
                locationStr = rawLocation;
              } else if (rawLocation is Map) {
                locationStr = '${rawLocation['city'] ?? ''}, ${rawLocation['country'] ?? ''}'.trim();
              }
                  
              final lastActiveRaw = data['lastActive'];
              final lastActiveTime = lastActiveRaw is Timestamp ? lastActiveRaw.toDate() : null;
              final lastActiveStr = lastActiveTime != null ? timeago.format(lastActiveTime) : 'Never';

              return Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: context.themeSurfaceColor,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: isBanned ? Colors.redAccent.withValues(alpha: 0.5) : Colors.transparent,
                    width: 1.5,
                  ),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    // Status Indicator
                    Container(
                      width: 12,
                      height: 12,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: isBanned 
                            ? Colors.redAccent 
                            : (isOnline ? Colors.greenAccent : Colors.grey),
                        boxShadow: isBanned || isOnline ? [
                          BoxShadow(
                            color: (isBanned ? Colors.redAccent : Colors.greenAccent).withValues(alpha: 0.5),
                            blurRadius: 8,
                          )
                        ] : null,
                      ),
                    ),
                    const SizedBox(width: 16),
                    
                    // User Details
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            email,
                            style: GoogleFonts.inter(
                              color: context.themeTextColor,
                              fontWeight: FontWeight.w700,
                              fontSize: 14,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '$deviceModel â€¢ $locationStr',
                            style: GoogleFonts.inter(
                              color: context.themeMutedTextColor,
                              fontSize: 12,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Active: $lastActiveStr â€¢ Usage: ${_formatDuration(totalSeconds)}',
                            style: GoogleFonts.inter(
                              color: context.themeMutedTextColor,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                    
                    // Actions
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.emoji_events, color: Colors.orangeAccent),
                          onPressed: () => _showGrantBadgeDialog(context, uid, email),
                          tooltip: 'Grant Badge',
                        ),
                        IconButton(
                          icon: Icon(
                            isPremium ? Icons.star : Icons.star_border, 
                            color: isPremium ? Colors.amber : Colors.grey
                          ),
                          onPressed: () => _togglePremium(uid, isPremium),
                          tooltip: 'Toggle Premium',
                        ),
                        Switch(
                          value: isBanned,
                          activeThumbColor: Colors.redAccent,
                          inactiveTrackColor: context.themeBackgroundColor,
                          onChanged: (val) => _toggleBan(uid, isBanned),
                        ),
                      ],
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String label, AdminFilter filter) {
    final isSelected = _currentFilter == filter;
    return Padding(
      padding: const EdgeInsets.only(right: 8.0),
      child: ChoiceChip(
        label: Text(
          label, 
          style: TextStyle(
            color: isSelected ? context.themeInvertedTextColor : context.themeTextColor,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal
          )
        ),
        selected: isSelected,
        onSelected: (selected) {
          if (selected) {
            setState(() {
              _currentFilter = filter;
            });
          }
        },
        selectedColor: context.themeAccentColor,
        backgroundColor: context.themeSurfaceColor,
        side: BorderSide(
          color: isSelected ? Colors.transparent : context.themeMutedTextColor.withValues(alpha: 0.3),
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      ),
    );
  }

  Widget _buildSortDropdown() {
    return Container(
      height: 40,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: context.themeSurfaceColor,
        borderRadius: BorderRadius.circular(20),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: _sortBy,
          dropdownColor: context.themeSurfaceColor,
          icon: Icon(Icons.sort, color: context.themeMutedTextColor, size: 18),
          style: GoogleFonts.inter(color: context.themeTextColor, fontWeight: FontWeight.w600, fontSize: 13),
          items: const [
            DropdownMenuItem(value: 'lastActive', child: Text('Recent')),
            DropdownMenuItem(value: 'totalUsageSeconds', child: Text('Top Listeners')),
          ],
          onChanged: (val) {
            if (val != null) setState(() => _sortBy = val);
          },
        ),
      ),
    );
  }

  void _showGrantBadgeDialog(BuildContext context, String uid, String email) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: context.themeSurfaceColor,
          title: Text("Grant Badge to $email", style: TextStyle(color: context.themeTextColor, fontSize: 18)),
          content: SizedBox(
            width: double.maxFinite,
            child: GridView.builder(
              shrinkWrap: true,
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                crossAxisSpacing: 16,
                mainAxisSpacing: 16,
                childAspectRatio: 0.8,
              ),
              itemCount: BadgeModel.allBadges.length,
              itemBuilder: (context, index) {
                final badge = BadgeModel.allBadges[index];
                return GestureDetector(
                  onTap: () async {
                    Navigator.pop(context);
                    try {
                      await FirebaseFirestore.instance.collection('users').doc(uid).set({
                        'badges': FieldValue.arrayUnion([badge.id])
                      }, SetOptions(merge: true));
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Granted ${badge.name}!')),
                        );
                      }
                    } catch (e) {
                      debugPrint('Failed to grant badge: $e');
                    }
                  },
                  child: Container(
                    decoration: BoxDecoration(
                      color: context.themeCardColor,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: context.themeAccentColor.withValues(alpha: 0.3)),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Image.asset(badge.imagePath, height: 60, width: 60, fit: BoxFit.cover),
                        const SizedBox(height: 8),
                        Text(
                          badge.name,
                          style: GoogleFonts.inter(color: context.themeTextColor, fontWeight: FontWeight.bold, fontSize: 12),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text("Cancel", style: TextStyle(color: context.themeMutedTextColor)),
            ),
          ],
        );
      },
    );
  }

  void _showSocialAnnouncementDialog(BuildContext context) {
    final TextEditingController messageController = TextEditingController();
    
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: context.themeSurfaceColor,
          title: Text("Set Social Announcement", style: TextStyle(color: context.themeTextColor)),
          content: TextField(
            controller: messageController,
            style: TextStyle(color: context.themeTextColor),
            maxLines: 3,
            decoration: InputDecoration(
              hintText: 'Enter announcement (leave blank to clear)',
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
              style: ElevatedButton.styleFrom(backgroundColor: Colors.amberAccent),
              onPressed: () async {
                final msg = messageController.text.trim();
                await FirebaseFirestore.instance.collection('client_config').doc('social').set({
                  'announcement': msg,
                  'timestamp': FieldValue.serverTimestamp(),
                }, SetOptions(merge: true));
                
                if (context.mounted) {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Social Announcement updated!')),
                  );
                }
              },
              child: Text("Update", style: TextStyle(color: context.themeInvertedTextColor)),
            ),
          ],
        );
      },
    );
  }

  void _showBroadcastDialog(BuildContext context) {
    final titleController = TextEditingController();
    final messageController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: context.themeSurfaceColor,
          title: Text("Send Broadcast", style: TextStyle(color: context.themeTextColor)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: titleController,
                style: TextStyle(color: context.themeTextColor),
                decoration: InputDecoration(
                  labelText: 'Title',
                  labelStyle: TextStyle(color: context.themeMutedTextColor),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: messageController,
                style: TextStyle(color: context.themeTextColor),
                maxLines: 3,
                decoration: InputDecoration(
                  labelText: 'Message',
                  labelStyle: TextStyle(color: context.themeMutedTextColor),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text("Cancel", style: TextStyle(color: context.themeMutedTextColor)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: context.themeAccentColor),
              onPressed: () async {
                final title = titleController.text.trim();
                final msg = messageController.text.trim();
                if (title.isNotEmpty && msg.isNotEmpty) {
                  await FirebaseFirestore.instance.collection('broadcasts').add({
                    'title': title,
                    'message': msg,
                    'timestamp': FieldValue.serverTimestamp(),
                  });
                  if (context.mounted) {
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Broadcast sent successfully!')),
                    );
                  }
                }
              },
              child: Text("Send", style: TextStyle(color: context.themeInvertedTextColor)),
            ),
          ],
        );
      },
    );
  }
}

