import 'package:flutter/foundation.dart';
import 'package:purchases_flutter/purchases_flutter.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:it_feels_music/services/backend_api_service.dart';
import 'dart:io';
import 'dart:convert';
import 'package:http/http.dart' as http;

class SubscriptionService {
  // TODO: Replace with your actual RevenueCat API keys from the RevenueCat Dashboard
  static const _appleApiKey = 'APPLE_API_KEY_HERE';
  static const _googleApiKey = 'GOOGLE_API_KEY_HERE';
  static const entitlementId = 'premium';

  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;

  SubscriptionService({FirebaseFirestore? firestore, FirebaseAuth? auth}) 
      : _firestore = firestore ?? FirebaseFirestore.instance,
        _auth = auth ?? FirebaseAuth.instance;

  Future<void> initialize(String? currentUserId) async {
    if (kIsWeb) return; // Purchases not supported on web
    if (_googleApiKey.contains('API_KEY_HERE') || _appleApiKey.contains('API_KEY_HERE')) {
      debugPrint("[SubscriptionService] Placeholder RevenueCat key detected. Direct Distribution mode active.");
      return;
    }

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
    if (kIsWeb || _googleApiKey.contains('API_KEY_HERE')) return;
    try {
      await Purchases.logIn(uid);
    } catch (_) {}
  }

  Future<void> logout() async {
    if (kIsWeb || _googleApiKey.contains('API_KEY_HERE')) return;
    try {
      await Purchases.logOut();
    } catch (_) {}
  }

  Future<bool> checkPremiumStatus(String uid) async {
    if (kIsWeb || uid.isEmpty) return false;


    // 1. Check RevenueCat Status (if keys configured)
    if (!_googleApiKey.contains('API_KEY_HERE')) {
      try {
        final customerInfo = await Purchases.getCustomerInfo();
        if (customerInfo.entitlements.all[entitlementId]?.isActive == true) {
          return true;
        }
      } catch (e) {
        debugPrint("RevenueCat Error: $e");
      }
    }

    // 2. Check via Cloudflare Worker (Bypasses unreliable local Firestore cache)
    try {
      final user = _auth.currentUser;
      if (user == null) return false;
      
      String? token;
      try {
        // Try getting token with a 3-second timeout to prevent hanging on Windows C++ channel errors
        token = await user.getIdToken(true).timeout(const Duration(seconds: 3));
      } catch (e) {
        debugPrint("getIdToken(true) failed/timed out, trying without refresh...");
        try {
          token = await user.getIdToken().timeout(const Duration(seconds: 2));
        } catch (_) {}
      }

      if (token != null) {
        final url = Uri.parse('${BackendApiService.baseUrl}/api/v1/premium/verify?uid=$uid');
        final response = await http.get(
          url,
          headers: {
            'Authorization': 'Bearer $token',
            'X-Feels-Secret': (dotenv.isInitialized ? dotenv.env['API_SECRET'] : null) ?? 'development_secret_123',
          },
        );

        if (response.statusCode == 200) {
          final data = json.decode(response.body);
          if (data['success'] == true && data['isPremium'] == true) {
            return true;
          }
        }
      }

      // 3. Fallback to Firestore directly if Cloudflare verification fails or token fetch hung
      debugPrint("Cloudflare verification failed or skipped, falling back to Firestore...");
      final doc = await _firestore.collection('users').doc(uid).get();
      if (doc.exists && doc.data()?['isPremiumFamily'] == true) {
        return true;
      }
    } catch (e) {
      debugPrint("Premium Check Error: $e");
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
        // Validation moved strictly to backend
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
        // Validation moved strictly to backend
      }
      return active;
    } catch (e) {
      debugPrint("Restore Error: $e");
      return false;
    }
  }

  Future<bool> redeemCustomCoupon(String uid, String code) async {
    final cleanCode = code.trim().toUpperCase();
    debugPrint("[SubscriptionService] Attempting to redeem coupon: '$cleanCode' for user: '$uid'");
    
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
        } catch (e) {
          debugPrint("[SubscriptionService] Warning: Subcollection entitlement write skipped: $e");
        }

        debugPrint("[SubscriptionService] SUCCESS: 'FAMILY' coupon redeemed & saved to Firestore user doc '$uid'!");
        return true;
      } catch (e) {
        debugPrint("[SubscriptionService] Error granting FAMILY coupon: $e");
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
