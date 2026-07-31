import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:it_feels_music/core/providers/riverpod_bridge.dart';
import 'package:it_feels_music/features/auth/auth_provider.dart';
import 'package:it_feels_music/core/theme/theme_ext.dart';
import 'package:it_feels_music/main.dart';

class AuthBottomSheet extends ConsumerStatefulWidget {
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
        appProviderContainer.read(authProvider.notifier).resetFlow();
      }
    });
  }

  @override
  ConsumerState<AuthBottomSheet> createState() => _AuthBottomSheetState();
}

class _AuthBottomSheetState extends ConsumerState<AuthBottomSheet> {
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
    final authState = ref.watch(authProvider);
    
    // Auto-close when authenticated
    if (authState.isAuthenticated) {
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
          color: context.themeBackgroundColor.withValues(alpha: 0.95),
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.5),
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
                  color: Colors.grey.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 24),
            Text(
              _getTitle(authState.viewState),
              style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _getSubtitle(authState.viewState),
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[400],
              ),
            ),
            const SizedBox(height: 24),
            
            // Email Input
            AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              height: authState.viewState == AuthViewState.emailInput ? 60 : 0,
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
                  onSubmitted: (val) => ref.read(authProvider.notifier).submitEmail(val),
                ),
              ),
            ),

            // Password Input
            AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              height: (authState.viewState == AuthViewState.loginPassword || 
                      authState.viewState == AuthViewState.signupPassword) ? 60 : 0,
              child: SingleChildScrollView(
                child: TextField(
                  controller: _passwordController,
                  focusNode: _passwordFocus,
                  obscureText: true,
                  decoration: InputDecoration(
                    hintText: authState.viewState == AuthViewState.signupPassword ? 'Create a password' : 'Enter your password',
                    prefixIcon: const Icon(Icons.lock_outline),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    filled: true,
                    fillColor: Colors.black12,
                  ),
                  onSubmitted: (val) => ref.read(authProvider.notifier).submitPassword(val),
                ),
              ),
            ),

            if (authState.errorMessage.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 16),
                child: Text(
                  authState.errorMessage,
                  style: const TextStyle(color: Colors.redAccent, fontSize: 13),
                  textAlign: TextAlign.center,
                ),
              ),

            const SizedBox(height: 24),

            // Main Action Button
            ElevatedButton(
              onPressed: authState.viewState == AuthViewState.loading
                  ? null
                  : () {
                      if (authState.viewState == AuthViewState.emailInput) {
                        ref.read(authProvider.notifier).submitEmail(_emailController.text);
                      } else if (authState.viewState == AuthViewState.emailVerificationPending) {
                        ref.read(authProvider.notifier).checkVerificationStatus();
                      } else {
                        ref.read(authProvider.notifier).submitPassword(_passwordController.text);
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
              child: authState.viewState == AuthViewState.loading
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    )
                  : Text(
                      _getButtonText(authState.viewState),
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
            ),
            const SizedBox(height: 16),
            
            if (authState.viewState == AuthViewState.emailVerificationPending)
              TextButton(
                onPressed: () => ref.read(authProvider.notifier).resendVerificationEmail(),
                child: const Text('Resend Verification Link'),
              ),
            
            // Google Sign-In Button
            if (authState.viewState == AuthViewState.emailInput) ...[
              const Center(
                child: Text(
                  'OR',
                  style: TextStyle(
                    color: Colors.grey,
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              OutlinedButton.icon(
                onPressed: authState.viewState == AuthViewState.loading
                    ? null
                    : () => ref.read(authProvider.notifier).signInWithGoogle(),
                icon: Image.network(
                  'https://upload.wikimedia.org/wikipedia/commons/c/c1/Google_%22G%22_logo.svg',
                  height: 24,
                  errorBuilder: (context, error, stackTrace) => const Icon(Icons.g_mobiledata, color: Colors.blue),
                ),
                label: const Text(
                  'Continue with Google',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                style: OutlinedButton.styleFrom(
                  foregroundColor: context.themeTextColor,
                  side: BorderSide(color: Colors.grey.withValues(alpha: 0.3)),
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ],
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
      case AuthViewState.emailVerificationPending:
        return 'Verify Your Email';
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
      case AuthViewState.emailVerificationPending:
        return 'We sent a verification link to your email. Click it to activate your account.';
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
      case AuthViewState.emailVerificationPending:
        return 'I\'ve Verified My Email';
      default:
        return '...';
    }
  }
}
