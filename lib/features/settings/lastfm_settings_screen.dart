import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:it_feels_music/core/theme/theme_ext.dart';
import 'package:it_feels_music/core/utils/service_locator.dart';
import 'package:it_feels_music/services/lastfm_service.dart';

class LastfmSettingsScreen extends StatefulWidget {
  const LastfmSettingsScreen({super.key});

  @override
  State<LastfmSettingsScreen> createState() => _LastfmSettingsScreenState();
}

class _LastfmSettingsScreenState extends State<LastfmSettingsScreen> {
  final LastfmService _lastfmService = locator<LastfmService>();
  final TextEditingController _usernameController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  
  bool _isLoading = true;
  bool _isConfigured = false;
  bool _isLoggedIn = false;
  String? _username;

  @override
  void initState() {
    super.initState();
    _checkStatus();
  }
  
  Future<void> _checkStatus() async {
    final loggedIn = await _lastfmService.isLoggedIn();
    String? username;
    if (loggedIn) {
      username = await _lastfmService.getUsername();
    }
    
    setState(() {
      _isConfigured = _lastfmService.isConfigured;
      _isLoggedIn = loggedIn;
      _username = username;
      _isLoading = false;
    });
  }

  Future<void> _login() async {
    final user = _usernameController.text.trim();
    final pass = _passwordController.text.trim();
    
    if (user.isEmpty || pass.isEmpty) return;
    
    setState(() => _isLoading = true);
    
    final success = await _lastfmService.authenticate(user, pass);
    
    if (success && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Successfully connected to Last.fm!')),
      );
      _passwordController.clear();
      await _checkStatus();
    } else if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Login failed. Check your credentials and try again.'),
          backgroundColor: Theme.of(context).colorScheme.error,
        ),
      );
      setState(() => _isLoading = false);
    }
  }

  Future<void> _logout() async {
    setState(() => _isLoading = true);
    await _lastfmService.logout();
    await _checkStatus();
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
          "Last.fm Scrobbling",
          style: GoogleFonts.outfit(
            fontSize: 22,
            fontWeight: FontWeight.w800,
            color: context.themeTextColor,
          ),
        ),
      ),
      body: _isLoading 
        ? const Center(child: CircularProgressIndicator())
        : !_isConfigured 
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Text(
                  "Last.fm integration is not configured. Please add API keys to your .env file.",
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
                  if (_isLoggedIn) ...[
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
                            _username ?? 'Unknown User',
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
                      onPressed: _logout,
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
                      onPressed: _login,
                      child: Text(
                        "Connect to Last.fm",
                        style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 16),
                      ),
                    ),
                  ],
                  SizedBox(height: 168 + MediaQuery.of(context).viewPadding.bottom),
                ],
              ),
            ),
    );
  }
}
