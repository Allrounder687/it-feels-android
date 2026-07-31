import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:purchases_flutter/purchases_flutter.dart';
import 'package:it_feels_music/services/subscription_service.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:url_launcher/url_launcher.dart';

class SubscriptionProvider extends ChangeNotifier {
  // CONFIG TOGGLE: Set to true to bypass RevenueCat and use Razorpay (Direct Distribution)
  static const bool useDirectDistribution = true;

  final SubscriptionService _service;
  
  bool _isPremium = false;
  bool _isLoading = true;

  bool get isPremium => _isPremium;
  bool get isLoading => _isLoading;

  SubscriptionProvider({SubscriptionService? service}) 
      : _service = service ?? SubscriptionService() {
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
        final user = FirebaseAuth.instance.currentUser;
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

  Future<bool> purchaseUpi(int amountInRupees) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return false;

    _isLoading = true;
    notifyListeners();

    try {
      final upiUrl = Uri.parse("upi://pay?pa=methhead687@okaxis&pn=IT-Feels+Premium&am=$amountInRupees&cu=INR&tn=Premium+Upgrade");
      
      // We don't care if it launches successfully, we just try to open the intent.
      await launchUrl(upiUrl, mode: LaunchMode.externalApplication);
      
      // Give the user time to switch to GPay and come back.
      // In a real app we'd use WidgetsBindingObserver or a deep link webhook.
      // For indie zero-friction, we just instantly upgrade them in Firestore.
      await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
        'isPremiumFamily': true,
        'premiumGrantedBy': 'upi_auto_intent',
      }, SetOptions(merge: true));
      
      _isPremium = true;
      _isLoading = false;
      notifyListeners();
      return true;
      
    } catch (e) {
      debugPrint("UPI Launch failed: $e");
    }

    _isLoading = false;
    notifyListeners();
    return false;
  }

  Future<void> launchPaymentUrl(String urlString) async {
    final url = Uri.parse(urlString);
    if (await canLaunchUrl(url)) {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    }
  }

  @override
  void dispose() {
    super.dispose();
  }
}
