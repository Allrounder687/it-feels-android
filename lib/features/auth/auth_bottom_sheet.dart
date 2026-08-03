import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:it_feels_music/core/providers/bottom_ui_provider.dart';
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

  bool get _isGoogleSignInSupported {
    if (kIsWeb) return true;
    return defaultTargetPlatform == TargetPlatform.android ||
           defaultTargetPlatform == TargetPlatform.iOS ||
           defaultTargetPlatform == TargetPlatform.macOS;
  }

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
    
    ref.listen(authProvider, (previous, next) {
      if (next.isAuthenticated && mounted) {
        if (Navigator.of(context).canPop()) {
          Navigator.of(context).pop();
        }
      }
    });

    final bottomUiHeight = ref.watch(bottomUiProvider);
    final bottomPadding = MediaQuery.of(context).viewInsets.bottom + bottomUiHeight;

    return Padding(
      padding: EdgeInsets.only(
        bottom: bottomPadding,
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
        child: SingleChildScrollView(
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
              height: 60,
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
                ),
              ),
            ),

            // Password Input
            AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              height: authState.viewState == AuthViewState.forgotPassword ? 0 : 60,
              margin: EdgeInsets.only(top: authState.viewState == AuthViewState.forgotPassword ? 0 : 16),
              child: SingleChildScrollView(
                child: TextField(
                  controller: _passwordController,
                  focusNode: _passwordFocus,
                  obscureText: true,
                  decoration: InputDecoration(
                    hintText: 'Enter your password',
                    prefixIcon: const Icon(Icons.lock_outline),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    filled: true,
                    fillColor: Colors.black12,
                  ),
                ),
              ),
            ),

            if (authState.viewState == AuthViewState.login)
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: () => ref.read(authProvider.notifier).toggleView(AuthViewState.forgotPassword),
                  child: const Text('Forgot Password?', style: TextStyle(color: Colors.grey)),
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
                      if (authState.viewState == AuthViewState.forgotPassword) {
                        ref.read(authProvider.notifier).submitForgotPassword(_emailController.text);
                      } else if (authState.viewState == AuthViewState.emailVerificationPending) {
                        ref.read(authProvider.notifier).checkVerificationStatus();
                      } else {
                        ref.read(authProvider.notifier).submitAuth(_emailController.text.trim(), _passwordController.text);
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
            
            if (authState.viewState == AuthViewState.emailVerificationPending)
              TextButton(
                onPressed: () => ref.read(authProvider.notifier).resendVerificationEmail(),
                child: const Text('Resend Verification Link'),
              ),
              
            if (authState.viewState == AuthViewState.login || authState.viewState == AuthViewState.signup)
              TextButton(
                onPressed: () {
                  final newState = authState.viewState == AuthViewState.login 
                      ? AuthViewState.signup 
                      : AuthViewState.login;
                  ref.read(authProvider.notifier).toggleView(newState);
                },
                child: Text(
                  authState.viewState == AuthViewState.login 
                      ? "Don't have an account? Sign Up" 
                      : "Already have an account? Log In",
                  style: const TextStyle(color: Colors.grey),
                ),
              ),
              
            if (authState.viewState == AuthViewState.forgotPassword)
              TextButton(
                onPressed: () => ref.read(authProvider.notifier).toggleView(AuthViewState.login),
                child: const Text("Back to Login", style: TextStyle(color: Colors.grey)),
              ),

            // Google Sign-In Button
            if ((authState.viewState == AuthViewState.login || authState.viewState == AuthViewState.signup) && _isGoogleSignInSupported) ...[
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
      ),
    );
  }

  String _getTitle(AuthViewState state) {
    switch (state) {
      case AuthViewState.login:
        return 'Welcome Back';
      case AuthViewState.signup:
        return 'Create Account';
      case AuthViewState.forgotPassword:
        return 'Reset Password';
      case AuthViewState.emailVerificationPending:
        return 'Verify Your Email';
      case AuthViewState.loading:
      case AuthViewState.authenticated:
        return 'Authenticating...';
    }
  }

  String _getSubtitle(AuthViewState state) {
    switch (state) {
      case AuthViewState.login:
        return 'Log in to backup playlists and use Listen Together.';
      case AuthViewState.signup:
        return 'Sign up to protect your library.';
      case AuthViewState.forgotPassword:
        return 'Enter your email to receive a password reset link.';
      case AuthViewState.emailVerificationPending:
        return 'We sent a verification link to your email. Click it to activate your account.';
      default:
        return '';
    }
  }

  String _getButtonText(AuthViewState state) {
    switch (state) {
      case AuthViewState.login:
        return 'Log In';
      case AuthViewState.signup:
        return 'Create Account';
      case AuthViewState.forgotPassword:
        return 'Send Reset Link';
      case AuthViewState.emailVerificationPending:
        return 'I\'ve Verified My Email';
      default:
        return '...';
    }
  }
}
