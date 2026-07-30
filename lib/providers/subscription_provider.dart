import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:purchases_flutter/purchases_flutter.dart';
import '../services/subscription_service.dart';

class SubscriptionProvider extends ChangeNotifier {
  final SubscriptionService _service = SubscriptionService();
  bool _isPremium = false;
  bool _isLoading = true;

  bool get isPremium => _isPremium;
  bool get isLoading => _isLoading;

  SubscriptionProvider() {
    _init();
  }

  Future<void> _init() async {
    final user = FirebaseAuth.instance.currentUser;
    await _service.initialize(user?.uid);
    await checkStatus();
    
    FirebaseAuth.instance.authStateChanges().listen((user) async {
      if (user != null) {
        await _service.login(user.uid);
      } else {
        await _service.logout();
      }
      await checkStatus();
    });
    
    // Listen to RevenueCat updates
    Purchases.addCustomerInfoUpdateListener((customerInfo) {
      final isActive = customerInfo.entitlements.all[SubscriptionService.entitlementId]?.isActive == true;
      if (_isPremium != isActive) {
        _isPremium = isActive;
        notifyListeners();
      }
    });
  }

  Future<void> checkStatus() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      _isPremium = await _service.checkPremiumStatus(user.uid);
    } else {
      _isPremium = false;
    }
    _isLoading = false;
    notifyListeners();
  }

  Future<List<Package>> getPackages() => _service.getPackages();

  Future<bool> purchasePackage(Package package) async {
    _isLoading = true;
    notifyListeners();
    final success = await _service.purchasePackage(package);
    if (success) _isPremium = true;
    _isLoading = false;
    notifyListeners();
    return success;
  }

  Future<bool> restorePurchases() async {
    _isLoading = true;
    notifyListeners();
    final success = await _service.restorePurchases();
    if (success) _isPremium = true;
    _isLoading = false;
    notifyListeners();
    return success;
  }

  Future<bool> redeemCoupon(String code) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return false;
    
    _isLoading = true;
    notifyListeners();
    final success = await _service.redeemCustomCoupon(user.uid, code);
    if (success) _isPremium = true;
    _isLoading = false;
    notifyListeners();
    return success;
  }
}
