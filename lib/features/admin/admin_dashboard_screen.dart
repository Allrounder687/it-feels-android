import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:it_feels_music/core/theme/theme_ext.dart';
import 'package:it_feels_music/core/theme/app_colors.dart';
import 'package:timeago/timeago.dart' as timeago;

class AdminDashboardScreen extends StatelessWidget {
  const AdminDashboardScreen({super.key});

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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.themeBackgroundColor,
      appBar: AppBar(
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
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance.collection('users').orderBy('lastActive', descending: true).snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator(color: AppColors.midnightAccent));
          }
          if (snapshot.hasError) {
            return Center(child: Text("Error fetching data: ${snapshot.error}", style: TextStyle(color: context.themeTextColor)));
          }

          final docs = snapshot.data?.docs ?? [];
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
              final deviceModel = data['deviceModel'] ?? 'Unknown Device';
              final totalSeconds = data['totalUsageSeconds'] ?? 0;
              final locationMap = data['location'] as Map<String, dynamic>?;
              final locationStr = locationMap != null 
                  ? '${locationMap['city'] ?? ''}, ${locationMap['country'] ?? ''}'.trim()
                  : 'Unknown Location';
                  
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
                            uid,
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
                            '$deviceModel • $locationStr',
                            style: GoogleFonts.inter(
                              color: context.themeMutedTextColor,
                              fontSize: 12,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Active: $lastActiveStr • Usage: ${_formatDuration(totalSeconds)}',
                            style: GoogleFonts.inter(
                              color: context.themeMutedTextColor,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                    
                    // Ban Toggle
                    Switch(
                      value: isBanned,
                      activeColor: Colors.redAccent,
                      inactiveTrackColor: context.themeBackgroundColor,
                      onChanged: (val) => _toggleBan(uid, isBanned),
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }
}
