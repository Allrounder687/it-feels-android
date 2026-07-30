import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../core/theme/theme_ext.dart';

class AuthBottomSheet extends StatefulWidget {
  const AuthBottomSheet({super.key});

  static void show(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => const AuthBottomSheet(),
    ).whenComplete(() {
      // Reset the flow when the bottom sheet is closed
      if (context.mounted) {
        Provider.of<AuthProvider>(context, listen: false).resetFlow();
      }
    });
  }

  @override
  State<AuthBottomSheet> createState() => _AuthBottomSheetState();
}

class _AuthBottomSheetState extends State<AuthBottomSheet> {
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final FocusNode _passwordFocus = FocusNode();

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _passwordFocus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);
    
    // Auto-close when authenticated
    if (authProvider.isAuthenticated) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (Navigator.of(context).canPop()) {
          Navigator.of(context).pop();
        }
      });
    }

    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Container(
        decoration: BoxDecoration(
          color: context.themeBackgroundColor.withOpacity(0.95),
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.5),
              blurRadius: 20,
              spreadRadius: 5,
            )
          ],
        ),
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.withOpacity(0.3),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 24),
            Text(
              _getTitle(authProvider.viewState),
              style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _getSubtitle(authProvider.viewState),
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[400],
              ),
            ),
            const SizedBox(height: 24),
            
            // Email Input
            AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              height: authProvider.viewState == AuthViewState.emailInput ? 60 : 0,
              child: SingleChildScrollView(
                child: TextField(
                  controller: _emailController,
                  keyboardType: TextInputType.emailAddress,
                  decoration: InputDecoration(
                    hintText: 'Enter your email',
                    prefixIcon: const Icon(Icons.email_outlined),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    filled: true,
                    fillColor: Colors.black12,
                  ),
                  onSubmitted: (val) => authProvider.submitEmail(val),
                ),
              ),
            ),

            // Password Input
            AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              height: (authProvider.viewState == AuthViewState.loginPassword || 
                      authProvider.viewState == AuthViewState.signupPassword) ? 60 : 0,
              child: SingleChildScrollView(
                child: TextField(
                  controller: _passwordController,
                  focusNode: _passwordFocus,
                  obscureText: true,
                  decoration: InputDecoration(
                    hintText: authProvider.viewState == AuthViewState.signupPassword ? 'Create a password' : 'Enter your password',
                    prefixIcon: const Icon(Icons.lock_outline),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    filled: true,
                    fillColor: Colors.black12,
                  ),
                  onSubmitted: (val) => authProvider.submitPassword(val),
                ),
              ),
            ),

            if (authProvider.errorMessage.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 16),
                child: Text(
                  authProvider.errorMessage,
                  style: const TextStyle(color: Colors.redAccent, fontSize: 13),
                  textAlign: TextAlign.center,
                ),
              ),

            const SizedBox(height: 24),

            // Main Action Button
            ElevatedButton(
              onPressed: authProvider.viewState == AuthViewState.loading
                  ? null
                  : () {
                      if (authProvider.viewState == AuthViewState.emailInput) {
                        authProvider.submitEmail(_emailController.text);
                      } else {
                        authProvider.submitPassword(_passwordController.text);
                      }
                    },
              style: ElevatedButton.styleFrom(
                backgroundColor: context.themeAccentColor,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: authProvider.viewState == AuthViewState.loading
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    )
                  : Text(
                      _getButtonText(authProvider.viewState),
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  String _getTitle(AuthViewState state) {
    switch (state) {
      case AuthViewState.emailInput:
        return 'Unlock Cloud Sync';
      case AuthViewState.loginPassword:
        return 'Welcome Back';
      case AuthViewState.signupPassword:
        return 'Create Account';
      case AuthViewState.loading:
      case AuthViewState.authenticated:
        return 'Authenticating...';
    }
  }

  String _getSubtitle(AuthViewState state) {
    switch (state) {
      case AuthViewState.emailInput:
        return 'Enter your email to backup playlists and use Listen Together.';
      case AuthViewState.loginPassword:
        return 'Enter your password to continue.';
      case AuthViewState.signupPassword:
        return 'Create a secure password to protect your library.';
      default:
        return '';
    }
  }

  String _getButtonText(AuthViewState state) {
    switch (state) {
      case AuthViewState.emailInput:
        return 'Continue';
      case AuthViewState.loginPassword:
        return 'Log In';
      case AuthViewState.signupPassword:
        return 'Create Account';
      default:
        return '...';
    }
  }
}
