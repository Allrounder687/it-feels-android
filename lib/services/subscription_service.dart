import 'package:flutter/foundation.dart';
import 'package:purchases_flutter/purchases_flutter.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:io';
import 'dart:convert';
import 'package:http/http.dart' as http;

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
    
    // 0. Check local device-wide premium flag (persists across app updates & guest resets)
    try {
      final prefs = await SharedPreferences.getInstance();
      if (prefs.getBool('isPremiumDevice') == true || (uid.isNotEmpty && prefs.getBool('isPremiumFamily_$uid') == true)) {
        return true;
      }
    } catch (_) {}

    // 1. Check RevenueCat Status
    try {
      final customerInfo = await Purchases.getCustomerInfo();
      if (customerInfo.entitlements.all[entitlementId]?.isActive == true) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setBool('isPremiumDevice', true);
        return true;
      }
    } catch (e) {
      debugPrint("RevenueCat Error: $e");
    }

    // 2. Check Custom Firestore Coupon / Entitlement fallback
    try {
      final prefs = await SharedPreferences.getInstance();
      
      // Global device level premium flag so app updates / guest resets don't revoke premium
      if (prefs.getBool('isPremiumDevice') == true || prefs.getBool('isPremiumFamily_$uid') == true) {
        return true;
      }

      // Check for FAMILY coupon on user doc directly
      final userDoc = await _firestore.collection('users').doc(uid).get();
      if (userDoc.exists && userDoc.data()?['isPremiumFamily'] == true) {
        await prefs.setBool('isPremiumFamily_$uid', true);
        await prefs.setBool('isPremiumDevice', true);
        return true;
      }

      final doc = await _firestore.collection('users').doc(uid).collection('entitlements').doc('premium').get();
      if (doc.exists) {
        final data = doc.data();
        if (data != null && data['isActive'] == true) {
           final expiry = data['expiresAt'] as Timestamp?;
           if (expiry == null || expiry.toDate().isAfter(DateTime.now())) {
             await prefs.setBool('isPremiumDevice', true);
             return true;
           }
        }
      }
    } catch (e) {
      debugPrint("Firestore Entitlement Error: $e");
      // Fallback to local cache in case of offline/error
      final prefs = await SharedPreferences.getInstance();
      if (prefs.getBool('isPremiumDevice') == true || prefs.getBool('isPremiumFamily_$uid') == true) {
        return true;
      }
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
      final active = result.customerInfo.entitlements.all[entitlementId]?.isActive == true;
      if (active) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setBool('isPremiumDevice', true);
      }
      return active;
    } catch (e) {
      debugPrint("Purchase Error: $e");
      return false;
    }
  }

  Future<bool> restorePurchases() async {
    try {
      final customerInfo = await Purchases.restorePurchases();
      final active = customerInfo.entitlements.all[entitlementId]?.isActive == true;
      if (active) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setBool('isPremiumDevice', true);
      }
      return active;
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
        final prefs = await SharedPreferences.getInstance();
        await prefs.setBool('isPremiumFamily_$uid', true);
        await prefs.setBool('isPremiumDevice', true);

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

    // Gumroad License API Verification
    // Gumroad keys are formatted like XXXXXXXX-XXXXXXXX-XXXXXXXX-XXXXXXXX
    if (cleanCode.length > 20 && cleanCode.contains('-')) {
       try {
         final response = await http.post(
           Uri.parse('https://api.gumroad.com/v2/licenses/verify'),
           body: {
             'product_id': 'sC8BcFZNHHStRCAERalyxA==', // Exact Product ID from Gumroad
             'license_key': cleanCode,
           }
         );
         
         if (response.statusCode == 200) {
           final data = jsonDecode(response.body);
           if (data['success'] == true && data['purchase'] != null && data['purchase']['refunded'] == false && data['purchase']['chargebacked'] == false) {
              final expiresAt = DateTime.now().add(const Duration(days: 365)); // Grant 1 year per Gumroad license
              await _firestore.collection('users').doc(uid).collection('entitlements').doc('premium').set({
                'isActive': true,
                'expiresAt': Timestamp.fromDate(expiresAt),
                'grantedBy': 'gumroad_$cleanCode',
              });
              return true;
           }
         }
       } catch (e) {
         debugPrint("Gumroad Verification Error: $e");
       }
    }

    // Fallback to Firestore custom Crypto/Promo coupons
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
