import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:purchases_flutter/purchases_flutter.dart';
import 'dart:async';

import 'package:it_feels_music/services/subscription_service.dart';
import 'package:it_feels_music/core/utils/service_locator.dart';

import 'package:url_launcher/url_launcher.dart';
import 'package:it_feels_music/services/razorpay_service.dart';

class SubscriptionProvider extends ChangeNotifier {
  // CONFIG TOGGLE: Set to true to bypass RevenueCat and use Razorpay (Direct Distribution)
  static const bool useDirectDistribution = true;

  final SubscriptionService _service;
  final RazorpayService _razorpayService = RazorpayService();
  
  bool _isPremium = false;
  bool _isLoading = true;

  bool get isPremium => _isPremium;
  bool get isLoading => _isLoading;

  FirebaseAuth get _auth => locator.isRegistered<FirebaseAuth>() ? locator<FirebaseAuth>() : FirebaseAuth.instance;

  SubscriptionProvider({SubscriptionService? service}) 
      : _service = service ?? SubscriptionService() {
    _init();
  }

  Future<void> _init() async {
    final user = _auth.currentUser;
    await _service.initialize(user?.uid);
    await checkStatus();
    
    _auth.authStateChanges().listen((user) async {
      if (user != null) {
        await _service.login(user.uid);
      } else {
        await _service.logout();
      }
      await checkStatus();
    });
    
    // Listen to RevenueCat updates
    Purchases.addCustomerInfoUpdateListener((customerInfo) async {
      final isRCActive = customerInfo.entitlements.all[SubscriptionService.entitlementId]?.isActive == true;
      
      if (isRCActive) {
        if (!_isPremium) {
          _isPremium = true;
          notifyListeners();
        }
      } else {
        // RevenueCat says no premium, but they might have a Firestore custom coupon
        // So we re-verify via the backend before downgrading them.
        final user = _auth.currentUser;
        if (user != null) {
          final isFirestoreActive = await _service.checkPremiumStatus(user.uid);
          if (_isPremium != isFirestoreActive) {
            _isPremium = isFirestoreActive;
            notifyListeners();
          }
        } else {
          if (_isPremium) {
            _isPremium = false;
            notifyListeners();
          }
        }
      }
    });
  }

  Future<void> checkStatus() async {
    final user = _auth.currentUser;
    if (user == null || user.isAnonymous) {
      _isPremium = false;
      _isLoading = false;
      notifyListeners();
      return;
    }

    _isPremium = await _service.checkPremiumStatus(user.uid);
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
    final user = _auth.currentUser;
    if (user == null) return false;
    
    _isLoading = true;
    notifyListeners();
    final success = await _service.redeemCustomCoupon(user.uid, code);
    if (success) _isPremium = true;
    _isLoading = false;
    notifyListeners();
    return success;
  }

  Future<bool> purchaseUpi(int amountInRupees, int durationDays) async {
    _isLoading = true;
    notifyListeners();

    // The _razorpayService now directly updates Firestore on success.
    final success = await _razorpayService.checkout(amountInRupees, durationDays);
    if (success) {
      _isPremium = true;
    }

    _isLoading = false;
    notifyListeners();
    return success;
  }

  Future<void> launchPaymentUrl(String urlString) async {
    final url = Uri.parse(urlString);
    if (await canLaunchUrl(url)) {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    }
  }

  @override
  void dispose() {
    _razorpayService.dispose();
    super.dispose();
  }
}
