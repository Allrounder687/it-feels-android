import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:it_feels_music/core/providers/riverpod_bridge.dart';
import 'package:it_feels_music/features/subscription/subscription_provider.dart';
import 'package:it_feels_music/core/theme/app_colors.dart';
import 'package:it_feels_music/core/providers/bottom_ui_provider.dart';
import 'package:it_feels_music/features/subscription/premium_celebration_dialog.dart';
import 'package:purchases_flutter/purchases_flutter.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:it_feels_music/features/auth/auth_bottom_sheet.dart';


class PaywallBottomSheet extends ConsumerStatefulWidget {
  final String featureName;

  const PaywallBottomSheet({super.key, required this.featureName});

  static void show(BuildContext context, {required String featureName}) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => PaywallBottomSheet(featureName: featureName),
    );
  }

  @override
  ConsumerState<PaywallBottomSheet> createState() => _PaywallBottomSheetState();
}

class _PaywallBottomSheetState extends ConsumerState<PaywallBottomSheet> {
  final TextEditingController _couponController = TextEditingController();
  bool _showCouponField = false;
  String? _errorMessage;

  @override
  void dispose() {
    _couponController.dispose();
    super.dispose();
  }

  Future<void> _purchase(BuildContext context, Package package) async {
    final subProvider = ref.read(subscriptionProvider);
    final success = await subProvider.purchasePackage(package);
    if (success && context.mounted) {
      Navigator.pop(context);
    }
  }

  Future<void> _handleUpiPayment(BuildContext context, int amount, int days) async {
    final subProvider = ref.read(subscriptionProvider);
    
    // Launch Razorpay Checkout
    final success = await subProvider.purchaseUpi(amount, days);
    
    if (!context.mounted) return;

    if (success) {
      Navigator.pop(context); // close paywall sheet
      PremiumCelebrationDialog.show(context, isFamilyCoupon: false);
    } else if (!subProvider.isPremium) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Payment failed or cancelled.')));
    }
  }

  Future<void> _redeem(BuildContext context) async {
    if (_couponController.text.trim().isEmpty) return;
    
    final user = FirebaseAuth.instance.currentUser;
    if (user == null || user.isAnonymous) {
      setState(() {
        _errorMessage = 'Please sign in to an account to redeem coupon codes.';
      });
      AuthBottomSheet.show(context);
      return;
    }

    setState(() {
      _errorMessage = null;
    });
    
    final code = _couponController.text.trim();
    final isFamily = code.toUpperCase() == 'FAMILY';
    
    final subProvider = ref.read(subscriptionProvider);
    final success = await subProvider.redeemCoupon(code);
    if (success && context.mounted) {
      Navigator.pop(context);
      PremiumCelebrationDialog.show(context, isFamilyCoupon: isFamily);
    } else if (context.mounted) {
      setState(() {
        _errorMessage = 'Invalid or expired code.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<SubscriptionProvider>(subscriptionProvider, (previous, next) {
      if (previous?.isPremium != true && next.isPremium) {
        if (context.mounted) {
          Navigator.of(context).pop();
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Premium status verified!')),
          );
        }
      }
    });

    final subProvider = ref.watch(subscriptionProvider);
    final bottomUiHeight = ref.watch(bottomUiProvider);
    final bottomPadding = MediaQuery.of(context).viewInsets.bottom + bottomUiHeight + 16.0;
    final settings = ref.watch(settingsProvider);
    
    final contentContainer = Container(
      padding: EdgeInsets.only(
        bottom: bottomPadding,
        top: 40,
        left: 24,
        right: 24,
      ),
      decoration: BoxDecoration(
        color: settings.isPerformanceMode ? AppColors.midnightSurface : AppColors.midnightSurface.withValues(alpha: 0.6),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
        border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
          Container(
            width: 40,
            height: 4,
            margin: const EdgeInsets.only(bottom: 24),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.3),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
            const Icon(Icons.auto_awesome, color: AppColors.midnightAccent, size: 48),
            const SizedBox(height: 16),
            Text(
              "Unlock ${widget.featureName}",
              style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.white),
            ),
            const SizedBox(height: 8),
            Text(
              "Get access to Lyrics, Lossless Audio, advanced DSP, and unlimited Listen Together rooms with IT Feels Premium.",
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 14, color: Colors.white.withValues(alpha: 0.7)),
            ),
            const SizedBox(height: 32),
            if (subProvider.isLoading)
              const CircularProgressIndicator(color: AppColors.midnightAccent)
            else if (SubscriptionProvider.useDirectDistribution) ...[
              // Direct Distribution UI
              Padding(
                padding: const EdgeInsets.only(bottom: 12.0),
                child: ElevatedButton(
                  onPressed: () => _handleUpiPayment(context, 999, 365),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.midnightPrimary,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    minimumSize: const Size(double.infinity, 56),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                  child: const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.security, size: 20, color: Colors.amber),
                      SizedBox(width: 8),
                      Text("1 Year for ₹999 (Verified UPI Payment)", style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
                    ],
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(bottom: 12.0),
                child: ElevatedButton(
                  onPressed: () => subProvider.launchPaymentUrl('https://gumroad.com/l/it-feels'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white.withValues(alpha: 0.1),
                    foregroundColor: Colors.white,
                    elevation: 0,
                    minimumSize: const Size(double.infinity, 56),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                  child: const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.credit_card, size: 20),
                      SizedBox(width: 8),
                      Text("Pay with Card (Gumroad)", style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
                    ],
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(bottom: 12.0),
                child: ElevatedButton(
                  onPressed: () => subProvider.launchPaymentUrl('https://commerce.coinbase.com/checkout'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white.withValues(alpha: 0.1),
                    foregroundColor: Colors.white,
                    elevation: 0,
                    minimumSize: const Size(double.infinity, 56),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                  child: const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.currency_bitcoin, size: 20, color: Colors.orangeAccent),
                      SizedBox(width: 8),
                      Text("Pay with Crypto", style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                "Cancel anytime. Direct payments carry 0% fees.",
                style: TextStyle(fontSize: 12, color: Colors.white.withValues(alpha: 0.5)),
              ),
            ] else ...[
              // RevenueCat UI
              FutureBuilder<List<Package>>(
                future: subProvider.getPackages(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                     return const CircularProgressIndicator(color: AppColors.midnightAccent);
                  }
                  if (!snapshot.hasData || snapshot.data!.isEmpty) {
                     return const Text("Store currently unavailable.", style: TextStyle(color: Colors.white54));
                  }
                  
                  return Column(
                    children: snapshot.data!.map((pkg) => Padding(
                      padding: const EdgeInsets.only(bottom: 12.0),
                      child: ElevatedButton(
                        onPressed: () => _purchase(context, pkg),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.midnightPrimary,
                          foregroundColor: Colors.white,
                          elevation: 0,
                          minimumSize: const Size(double.infinity, 56),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        ),
                        child: Text("Subscribe for ${pkg.storeProduct.priceString}", style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                      ),
                    )).toList(),
                  );
                },
              ),
            ],
            const SizedBox(height: 16),
              TextButton(
                onPressed: () => setState(() => _showCouponField = !_showCouponField),
                child: Text("Redeem Code (Gumroad / Crypto / Promo)", style: TextStyle(color: Colors.white.withValues(alpha: 0.5))),
              ),
              if (_errorMessage != null)
                Padding(
                  padding: const EdgeInsets.only(top: 8.0, bottom: 8.0),
                  child: Text(
                    _errorMessage!,
                    style: const TextStyle(color: Colors.redAccent, fontSize: 13),
                  ),
                ),
                
              if (_showCouponField) ...[
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _couponController,
                        style: const TextStyle(color: Colors.white),
                        decoration: InputDecoration(
                          hintText: "Enter code...",
                          filled: true,
                          fillColor: Colors.white.withValues(alpha: 0.05),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide.none,
                          ),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    ElevatedButton(
                      onPressed: () => _redeem(context),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.midnightAccent,
                        foregroundColor: Colors.black,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                      ),
                      child: const Text("Redeem"),
                    )
                  ],
                )
              ]
            ],
        ),
      ),
      );

    if (settings.isPerformanceMode) {
      return contentContainer;
    }

    return BackdropFilter(
      filter: ImageFilter.blur(sigmaX: 30, sigmaY: 30),
      child: contentContainer,
    );
  }
}
