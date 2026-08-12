import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'dart:io';
import 'package:window_manager/window_manager.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:it_feels_music/core/theme/theme_ext.dart';
import 'package:it_feels_music/core/widgets/glass_shield_wrapper.dart';
import 'package:it_feels_music/core/theme/app_dimensions.dart';
import 'package:it_feels_music/features/settings/lastfm_provider.dart';

class LastfmSettingsScreen extends ConsumerStatefulWidget {
  const LastfmSettingsScreen({super.key});

  @override
  ConsumerState<LastfmSettingsScreen> createState() => _LastfmSettingsScreenState();
}

class _LastfmSettingsScreenState extends ConsumerState<LastfmSettingsScreen> {
  final TextEditingController _usernameController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();

  @override
  void dispose() {
    _usernameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _handleLogin() async {
    final notifier = ref.read(lastfmProvider.notifier);
    await notifier.login(_usernameController.text, _passwordController.text);
    
    // We can show snackbars by listening to state changes or just check after
    final state = ref.read(lastfmProvider);
    if (mounted) {
      if (state.errorMessage != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(state.errorMessage!),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      } else if (state.isLoggedIn) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Successfully connected to Last.fm!')),
        );
        _passwordController.clear();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(lastfmProvider);
    final notifier = ref.read(lastfmProvider.notifier);

    return GlassShieldWrapper(
      isGlassMode: context.isGlassTheme,
      child: Scaffold(
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
          "Last.fm Scrobbling",
          style: GoogleFonts.outfit(
            fontSize: 22,
            fontWeight: FontWeight.w800,
            color: context.themeTextColor,
          ),
        ),
      ),
      body: state.isLoading 
        ? const Center(child: CircularProgressIndicator())
        : !state.isConfigured 
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Text(
                  "Last.fm integration is not configured. Please turn on the 'Use Serverless Proxy Backend' option in Advanced Server Settings, or add API keys to your .env file.",
                  textAlign: TextAlign.center,
                  style: GoogleFonts.inter(color: context.themeMutedTextColor, fontSize: 16),
                ),
              ),
            )
          : SingleChildScrollView(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Icon(Icons.queue_music, size: 64, color: context.themeAccentColor),
                  const SizedBox(height: 24),
                  if (state.isLoggedIn) ...[
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: context.themeSurfaceColor,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Column(
                        children: [
                          Text(
                            "Connected as",
                            style: GoogleFonts.inter(color: context.themeMutedTextColor),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            state.username ?? 'Unknown User',
                            style: GoogleFonts.outfit(
                              color: context.themeTextColor,
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 24),
                          Text(
                            "Your listening history will automatically sync to your Last.fm profile.",
                            textAlign: TextAlign.center,
                            style: GoogleFonts.inter(color: context.themeMutedTextColor),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 32),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.redAccent.withValues(alpha: 0.1),
                        foregroundColor: Colors.redAccent,
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      onPressed: () => notifier.logout(),
                      child: Text(
                        "Disconnect Account",
                        style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 16),
                      ),
                    ),
                  ] else ...[
                    Text(
                      "Connect your Last.fm account to automatically scrobble your listening history.",
                      textAlign: TextAlign.center,
                      style: GoogleFonts.inter(color: context.themeMutedTextColor, fontSize: 16),
                    ),
                    const SizedBox(height: 32),
                    TextField(
                      controller: _usernameController,
                      style: TextStyle(color: context.themeTextColor),
                      decoration: InputDecoration(
                        labelText: 'Username',
                        labelStyle: TextStyle(color: context.themeMutedTextColor),
                        filled: true,
                        fillColor: context.themeSurfaceColor,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none,
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: _passwordController,
                      obscureText: true,
                      style: TextStyle(color: context.themeTextColor),
                      decoration: InputDecoration(
                        labelText: 'Password',
                        labelStyle: TextStyle(color: context.themeMutedTextColor),
                        filled: true,
                        fillColor: context.themeSurfaceColor,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none,
                        ),
                      ),
                    ),
                    const SizedBox(height: 32),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: context.themeAccentColor,
                        foregroundColor: context.themeInvertedTextColor,
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      onPressed: _handleLogin,
                      child: Text(
                        "Connect to Last.fm",
                        style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 16),
                      ),
                    ),
                  ],
                  SizedBox(height: AppDimensions.bottomClearance + MediaQuery.of(context).viewPadding.bottom),
                ],
              ),
            ),
    ));
  }
}

