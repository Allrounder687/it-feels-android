import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';

import 'package:window_manager/window_manager.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:it_feels_music/core/providers/riverpod_bridge.dart';
import 'package:file_picker/file_picker.dart';
import 'package:it_feels_music/data/services/local_audio_service.dart';
import 'package:it_feels_music/core/theme/theme_ext.dart';
import 'package:it_feels_music/features/settings/stats_screen.dart';
import 'package:it_feels_music/features/auth/auth_bottom_sheet.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:it_feels_music/data/models/badge_model.dart';
import 'package:it_feels_music/features/admin/admin_dashboard_screen.dart';
import 'package:it_feels_music/core/theme/app_dimensions.dart';

class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  final _nameController = TextEditingController();
  String _avatarPath = '';

  @override
  void initState() {
    super.initState();
    final profile = ref.read(profileProvider);
    _nameController.text = profile.userName;
    _avatarPath = profile.userAvatar;
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    final result = await FilePicker.pickFiles(type: FileType.image);
    if (result != null && result.files.single.path != null) {
      setState(() {
        _avatarPath = result.files.single.path!;
      });
    }
  }

  void _saveProfile() {
    ref.read(profileProvider.notifier).updateProfile(name: _nameController.text.trim(), avatar: _avatarPath);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          "Profile updated!",
          style: GoogleFonts.inter(),
        ),
        backgroundColor: context.themeAccentColor,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
    Navigator.pop(context);
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
          "Your Profile",
          style: GoogleFonts.outfit(
            fontSize: 22,
            fontWeight: FontWeight.w800,
            color: context.themeTextColor,
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(24, 24, 24, 24 + AppDimensions.bottomClearance + MediaQuery.of(context).viewPadding.bottom),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            const SizedBox(height: 20),
            GestureDetector(
              onTap: _pickImage,
              child: Stack(
                alignment: Alignment.bottomRight,
                children: [
                  CircleAvatar(
                    radius: 60,
                    backgroundColor: context.themeAccentColor.withValues(alpha: 0.2),
                    backgroundImage: _avatarPath.isNotEmpty && File(_avatarPath).existsSync()
                        ? FileImage(File(_avatarPath))
                        : null,
                    child: _avatarPath.isEmpty || !File(_avatarPath).existsSync()
                        ? Icon(
                            Icons.person_rounded,
                            size: 60,
                            color: context.themeAccentColor,
                          )
                        : null,
                  ),
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: context.themeAccentColor,
                      shape: BoxShape.circle,
                      border: Border.all(color: context.themeBackgroundColor, width: 3),
                    ),
                    child: const Icon(
                      Icons.camera_alt_rounded,
                      color: Colors.white,
                      size: 20,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 32),
            TextField(
              controller: _nameController,
              style: GoogleFonts.inter(color: context.themeTextColor),
              decoration: InputDecoration(
                labelText: "What should we call you?",
                labelStyle: GoogleFonts.inter(color: context.themeMutedTextColor),
                filled: true,
                fillColor: context.themeSurfaceColor,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide(color: context.themeTextColor24, width: 1),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide(color: context.themeTextColor24, width: 1),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide(color: context.themeAccentColor, width: 2),
                ),
              ),
            ),
            const SizedBox(height: 40),
            SizedBox(
              width: double.infinity,
              height: 56,
              child: ElevatedButton(
                onPressed: _saveProfile,
                style: ElevatedButton.styleFrom(
                  backgroundColor: context.themeAccentColor,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  elevation: 0,
                ),
                child: Text(
                  "Save Changes",
                  style: GoogleFonts.inter(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              height: 56,
              child: OutlinedButton(
                onPressed: () {
                  Navigator.push(context, MaterialPageRoute(builder: (_) => const StatsScreen()));
                },
                style: OutlinedButton.styleFrom(
                  side: BorderSide(color: context.themeAccentColor, width: 2),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                child: Text(
                  "View Your Stats",
                  style: GoogleFonts.inter(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: context.themeTextColor,
                  ),
                ),
              ),
            ),
            
            // TROPHY CASE
            Consumer(builder: (context, ref, _) {
              final user = ref.watch(authProvider).currentUser;
              if (user != null) {
                return Padding(
                  padding: const EdgeInsets.only(top: 32, bottom: 16),
                  child: _buildTrophyCase(user.uid),
                );
              }
              return const SizedBox.shrink();
            }),

            // ADMIN DASHBOARD BUTTON (Only visible to owner)
            if (ref.watch(authProvider).currentUser?.email == 'syedfaixalmajeed@gmail.com') ...[
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.push(context, MaterialPageRoute(builder: (_) => const AdminDashboardScreen()));
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.redAccent.withValues(alpha: 0.1),
                    foregroundColor: Colors.redAccent,
                    side: const BorderSide(color: Colors.redAccent, width: 2),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    elevation: 0,
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.security, color: Colors.redAccent),
                      const SizedBox(width: 8),
                      Text(
                        "Admin Dashboard",
                        style: GoogleFonts.inter(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.redAccent,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
            
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              height: 56,
              child: OutlinedButton(
                onPressed: () async {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text("Scanning local files...", style: GoogleFonts.inter())),
                  );
                  final localAudioService = LocalAudioService();
                  final localSongs = await localAudioService.scanLocalMusic();
                  if (context.mounted) {
                    if (localSongs.isNotEmpty) {
                      // Note: Ideally, we should merge these into our Isar DB or custom playlist.
                      // For now, just show a success message.
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text("Found ${localSongs.length} local songs! We will merge these into your library.", style: GoogleFonts.inter())),
                      );
                    } else {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text("No local songs found or permission denied.", style: GoogleFonts.inter())),
                      );
                    }
                  }
                },
                style: OutlinedButton.styleFrom(
                  side: BorderSide(color: context.themeTextColor.withValues(alpha: 0.3), width: 2),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.folder_open_rounded, color: context.themeTextColor),
                    const SizedBox(width: 8),
                    Text(
                      "Scan Local Device",
                      style: GoogleFonts.inter(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: context.themeTextColor,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            // Cloud Sync Auth Button
            Consumer(builder: (context, ref, _) { final auth = ref.watch(authProvider); 
                final isAuth = auth.isAuthenticated && !(auth.currentUser?.isAnonymous ?? false);
                return SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: OutlinedButton(
                    onPressed: () {
                      if (isAuth) {
                        // In Phase 3 step 3, this will handle sync logic. For now just show logout option.
                        showDialog(
                          context: context,
                          builder: (_) => AlertDialog(
                            backgroundColor: context.themeSurfaceColor,
                            title: const Text('Account'),
                            content: Text('Logged in as ${auth.currentUser?.email}'),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.pop(context),
                                child: const Text('Close'),
                              ),
                              TextButton(
                                onPressed: () async {
                                  Navigator.pop(context); // Close dialog first
                                  await ref.read(authProvider.notifier).signOut();
                                  if (context.mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text('Logged out successfully', style: TextStyle(color: context.themeBackgroundColor)),
                                        backgroundColor: context.themeTextColor,
                                        behavior: SnackBarBehavior.floating,
                                      ),
                                    );
                                  }
                                },
                                child: const Text('Sign Out', style: TextStyle(color: Colors.red)),
                              ),
                            ],
                          ),
                        );
                      } else {
                        AuthBottomSheet.show(context);
                      }
                    },
                    style: OutlinedButton.styleFrom(
                      side: BorderSide(color: isAuth ? Colors.green : context.themeAccentColor, width: 2),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(isAuth ? Icons.cloud_done : Icons.cloud_off, 
                             color: isAuth ? Colors.green : context.themeTextColor),
                        const SizedBox(width: 8),
                        Text(
                          isAuth ? "Cloud Sync Active" : "Enable Cloud Sync",
                          style: GoogleFonts.inter(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: context.themeTextColor,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
            SizedBox(height: AppDimensions.bottomClearance + MediaQuery.of(context).viewPadding.bottom),
          ],
        ),
      ),
    );
  }

  Widget _buildTrophyCase(String uid) {
    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance.collection('users').doc(uid).snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData || !snapshot.data!.exists) return const SizedBox.shrink();
        
        final data = snapshot.data!.data() as Map<String, dynamic>? ?? {};
        final badgesList = (data['badges'] as List<dynamic>?)?.cast<String>() ?? [];
        
        if (badgesList.isEmpty) return const SizedBox.shrink();

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.military_tech, color: Colors.amber, size: 28),
                const SizedBox(width: 8),
                Text(
                  "Trophy Case",
                  style: GoogleFonts.outfit(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: context.themeTextColor,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 120,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: badgesList.length,
                itemBuilder: (context, index) {
                  final badgeId = badgesList[index];
                  final badge = BadgeModel.getById(badgeId);
                  if (badge == null) return const SizedBox.shrink();
                  
                  return GestureDetector(
                    onTap: () {
                      showDialog(
                        context: context,
                        builder: (_) => AlertDialog(
                          backgroundColor: context.themeSurfaceColor,
                          title: Text(badge.name, style: GoogleFonts.outfit(color: context.themeTextColor, fontWeight: FontWeight.bold)),
                          content: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Image.asset(badge.imagePath, height: 100, width: 100),
                              const SizedBox(height: 16),
                              Text(badge.description, style: GoogleFonts.inter(color: context.themeMutedTextColor), textAlign: TextAlign.center),
                            ],
                          ),
                          actions: [
                            TextButton(onPressed: () => Navigator.pop(context), child: Text("Awesome", style: TextStyle(color: context.themeAccentColor))),
                          ],
                        ),
                      );
                    },
                    child: Container(
                      width: 100,
                      margin: const EdgeInsets.only(right: 16),
                      decoration: BoxDecoration(
                        color: context.themeCardColor,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: context.themeAccentColor.withValues(alpha: 0.5), width: 1.5),
                        boxShadow: [
                          BoxShadow(
                            color: context.themeAccentColor.withValues(alpha: 0.2),
                            blurRadius: 10,
                            spreadRadius: 2,
                          ),
                        ],
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Image.asset(badge.imagePath, height: 50, width: 50, fit: BoxFit.cover),
                          const SizedBox(height: 8),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 4.0),
                            child: Text(
                              badge.name,
                              style: GoogleFonts.inter(color: context.themeTextColor, fontSize: 11, fontWeight: FontWeight.w700),
                              textAlign: TextAlign.center,
                              maxLines: 2,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        );
      },
    );
  }
}

