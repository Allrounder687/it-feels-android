import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/subscription_provider.dart';
import '../../core/theme/app_colors.dart';
import 'package:purchases_flutter/purchases_flutter.dart';

class PaywallBottomSheet extends StatefulWidget {
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
  State<PaywallBottomSheet> createState() => _PaywallBottomSheetState();
}

class _PaywallBottomSheetState extends State<PaywallBottomSheet> {
  final TextEditingController _couponController = TextEditingController();
  bool _showCouponField = false;

  @override
  void dispose() {
    _couponController.dispose();
    super.dispose();
  }

  Future<void> _purchase(BuildContext context, Package package) async {
    final subProvider = Provider.of<SubscriptionProvider>(context, listen: false);
    final success = await subProvider.purchasePackage(package);
    if (success && mounted) {
      Navigator.pop(context);
    }
  }

  Future<void> _purchaseRazorpay(BuildContext context, int amount, int days) async {
    final subProvider = Provider.of<SubscriptionProvider>(context, listen: false);
    final success = await subProvider.purchaseRazorpay(amount, days);
    if (success && mounted) {
      Navigator.pop(context);
    } else if (mounted && !subProvider.isPremium) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Payment failed or was cancelled.')),
      );
    }
  }

  Future<void> _redeem(BuildContext context) async {
    if (_couponController.text.trim().isEmpty) return;
    final subProvider = Provider.of<SubscriptionProvider>(context, listen: false);
    final success = await subProvider.redeemCoupon(_couponController.text.trim());
    if (success && mounted) {
      Navigator.pop(context);
    } else if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Invalid or expired code.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final subProvider = Provider.of<SubscriptionProvider>(context);
    
    return BackdropFilter(
      filter: ImageFilter.blur(sigmaX: 30, sigmaY: 30),
      child: Container(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom + 40,
          top: 40,
          left: 24,
          right: 24,
        ),
        decoration: BoxDecoration(
          color: AppColors.midnightSurface.withOpacity(0.6),
          borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
          border: Border.all(color: Colors.white.withOpacity(0.1)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(bottom: 24),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.3),
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
              style: TextStyle(fontSize: 14, color: Colors.white.withOpacity(0.7)),
            ),
            const SizedBox(height: 32),
            if (subProvider.isLoading)
              const CircularProgressIndicator(color: AppColors.midnightAccent)
            else if (SubscriptionProvider.useDirectDistribution) ...[
              // Razorpay Direct UPI UI
              Padding(
                padding: const EdgeInsets.only(bottom: 12.0),
                child: ElevatedButton(
                  onPressed: () => _purchaseRazorpay(context, 599, 180),
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
                      Icon(Icons.payment, size: 20),
                      SizedBox(width: 8),
                      Text("6 Months for ₹599 (via UPI)", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                    ],
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(bottom: 12.0),
                child: ElevatedButton(
                  onPressed: () => _purchaseRazorpay(context, 999, 365),
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
                      Icon(Icons.stars, size: 20),
                      SizedBox(width: 8),
                      Text("1 Year for ₹999 (Best Value)", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                "Includes a 14-day unlimited trial. Cancel anytime.",
                style: TextStyle(fontSize: 12, color: Colors.white.withOpacity(0.5)),
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
                child: Text("Have a custom coupon code?", style: TextStyle(color: Colors.white.withOpacity(0.5))),
              ),
              if (_showCouponField) ...[
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _couponController,
                        style: const TextStyle(color: Colors.white),
                        decoration: InputDecoration(
                          hintText: "Enter code...",
                          hintStyle: TextStyle(color: Colors.white.withOpacity(0.3)),
                          filled: true,
                          fillColor: Colors.white.withOpacity(0.05),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton(
                      onPressed: () => _redeem(context),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.midnightPill,
                        foregroundColor: Colors.white,
                        minimumSize: const Size(80, 56),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
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
  }
}
