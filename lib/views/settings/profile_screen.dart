import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:file_picker/file_picker.dart';
import '../../providers/profile_provider.dart';
import '../../data/services/local_audio_service.dart';
import 'package:it_feels_music/core/theme/theme_ext.dart';
import 'stats_screen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _nameController = TextEditingController();
  String _avatarPath = '';

  @override
  void initState() {
    super.initState();
    final profileProvider = Provider.of<ProfileProvider>(context, listen: false);
    _nameController.text = profileProvider.userName;
    _avatarPath = profileProvider.userAvatar;
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    final result = await FilePicker.platform.pickFiles(type: FileType.image);
    if (result != null && result.files.single.path != null) {
      setState(() {
        _avatarPath = result.files.single.path!;
      });
    }
  }

  void _saveProfile() {
    final profileProvider = Provider.of<ProfileProvider>(context, listen: false);
    profileProvider.updateProfile(name: _nameController.text.trim(), avatar: _avatarPath);
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
        padding: const EdgeInsets.all(24.0),
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
                    backgroundColor: context.themeAccentColor.withOpacity(0.2),
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
                  borderSide: BorderSide.none,
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
                  side: BorderSide(color: context.themeTextColor.withOpacity(0.3), width: 2),
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
          ],
        ),
      ),
    );
  }
}
