import 'package:flutter/foundation.dart';
import 'package:purchases_flutter/purchases_flutter.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:io';

class SubscriptionService {
  // TODO: Replace with your actual RevenueCat API keys from the RevenueCat Dashboard
  static const _appleApiKey = 'APPLE_API_KEY_HERE';
  static const _googleApiKey = 'GOOGLE_API_KEY_HERE';
  static const entitlementId = 'premium';

  final FirebaseFirestore _firestore;

  SubscriptionService({FirebaseFirestore? firestore}) 
      : _firestore = firestore ?? FirebaseFirestore.instance;

  Future<void> initialize(String? currentUserId) async {
    if (kIsWeb) return; // Purchases not supported on web
    
    await Purchases.setLogLevel(LogLevel.debug);

    PurchasesConfiguration? configuration;
    if (Platform.isAndroid) {
      configuration = PurchasesConfiguration(_googleApiKey);
    } else if (Platform.isIOS || Platform.isMacOS) {
      configuration = PurchasesConfiguration(_appleApiKey);
    }

    if (configuration != null) {
      if (currentUserId != null) {
        configuration.appUserID = currentUserId;
      }
      await Purchases.configure(configuration);
    }
  }

  Future<void> login(String uid) async {
    if (kIsWeb) return;
    await Purchases.logIn(uid);
  }

  Future<void> logout() async {
    if (kIsWeb) return;
    await Purchases.logOut();
  }

  Future<bool> checkPremiumStatus(String uid) async {
    if (kIsWeb) return false;
    
    // 1. Check RevenueCat Status
    try {
      final customerInfo = await Purchases.getCustomerInfo();
      if (customerInfo.entitlements.all[entitlementId]?.isActive == true) {
        return true;
      }
    } catch (e) {
      debugPrint("RevenueCat Error: $e");
    }

    // 2. Check Custom Firestore Coupon / Entitlement fallback
    try {
      // Check for FAMILY coupon on user doc directly
      final userDoc = await _firestore.collection('users').doc(uid).get();
      if (userDoc.exists && userDoc.data()?['isPremiumFamily'] == true) {
        return true;
      }

      final doc = await _firestore.collection('users').doc(uid).collection('entitlements').doc('premium').get();
      if (doc.exists) {
        final data = doc.data();
        if (data != null && data['isActive'] == true) {
           final expiry = data['expiresAt'] as Timestamp?;
           if (expiry == null || expiry.toDate().isAfter(DateTime.now())) {
             return true;
           }
        }
      }
    } catch (e) {
      debugPrint("Firestore Entitlement Error: $e");
    }
    return false;
  }

  Future<List<Package>> getPackages() async {
    if (kIsWeb) return [];
    try {
      final offerings = await Purchases.getOfferings();
      if (offerings.current != null && offerings.current!.availablePackages.isNotEmpty) {
        return offerings.current!.availablePackages;
      }
    } catch (e) {
      debugPrint("Error fetching offers: $e");
    }
    return [];
  }

  Future<bool> purchasePackage(Package package) async {
    try {
      final result = await Purchases.purchasePackage(package);
      return result.customerInfo.entitlements.all[entitlementId]?.isActive == true;
    } catch (e) {
      debugPrint("Purchase Error: $e");
      return false;
    }
  }

  Future<bool> restorePurchases() async {
    try {
      final customerInfo = await Purchases.restorePurchases();
      return customerInfo.entitlements.all[entitlementId]?.isActive == true;
    } catch (e) {
      debugPrint("Restore Error: $e");
      return false;
    }
  }

  Future<bool> redeemCustomCoupon(String uid, String code) async {
    final cleanCode = code.trim().toUpperCase();
    
    // Special Lifetime Coupon "FAMILY"
    if (cleanCode == 'FAMILY') {
      try {
        await _firestore.collection('users').doc(uid).set({
          'isPremiumFamily': true,
        }, SetOptions(merge: true));

        try {
          await _firestore.collection('users').doc(uid).collection('entitlements').doc('premium').set({
            'isActive': true,
            'expiresAt': null, // Permanent lifetime access
            'grantedBy': 'FAMILY',
          }, SetOptions(merge: true));
        } catch (_) {} // Ignore if entitlement subcollection is locked down

        return true;
      } catch (e) {
        debugPrint("Error granting FAMILY coupon: $e");
        return false;
      }
    }

    try {
      final couponQuery = await _firestore.collection('coupons').where('code', isEqualTo: cleanCode).limit(1).get();
      if (couponQuery.docs.isEmpty) return false;

      final coupon = couponQuery.docs.first;
      if (coupon.data()['isActive'] != true) return false;
      
      final durationDays = coupon.data()['durationDays'] as int? ?? 30;
      final expiresAt = DateTime.now().add(Duration(days: durationDays));

      await _firestore.collection('users').doc(uid).collection('entitlements').doc('premium').set({
        'isActive': true,
        'expiresAt': Timestamp.fromDate(expiresAt),
        'grantedBy': cleanCode,
      });
      return true;
    } catch (e) {
      debugPrint("Coupon Redemption Error: $e");
      return false;
    }
  }
}
