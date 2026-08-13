import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:razorpay_flutter/razorpay_flutter.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:io';
import 'package:it_feels_music/core/utils/service_locator.dart';

class RazorpayService {
  Razorpay? _razorpay;
  FirebaseFirestore get _firestore => locator.isRegistered<FirebaseFirestore>() ? locator<FirebaseFirestore>() : FirebaseFirestore.instance;
  FirebaseAuth get _auth => locator.isRegistered<FirebaseAuth>() ? locator<FirebaseAuth>() : FirebaseAuth.instance;
  
  static const String _backendUrl = 'https://it-feels-proxy.cleverfox687.workers.dev';
  
  Completer<bool>? _paymentCompleter;

  RazorpayService() {
    if (Platform.isAndroid || Platform.isIOS) {
      _razorpay = Razorpay();
      _razorpay!.on(Razorpay.EVENT_PAYMENT_SUCCESS, _handlePaymentSuccess);
      _razorpay!.on(Razorpay.EVENT_PAYMENT_ERROR, _handlePaymentError);
      _razorpay!.on(Razorpay.EVENT_EXTERNAL_WALLET, _handleExternalWallet);
    }
  }

  void dispose() {
    _razorpay?.clear();
  }

  Future<bool> checkout(int amountInRupees, int durationDays) async {
    _paymentCompleter = Completer<bool>();


    final user = _auth.currentUser;
    if (user == null) return false;

    try {
      // 1. Generate Order on Backend
      final response = await http.post(
        Uri.parse('$_backendUrl/api/v1/razorpay/order'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'amount': amountInRupees * 100, // Razorpay takes paise
          'receipt': 'rcpt_${user.uid.substring(0, 5)}_${DateTime.now().millisecondsSinceEpoch}',
        }),
      );

      if (response.statusCode != 200) {
        debugPrint("Failed to create Razorpay Order: ${response.body}");
        return false;
      }

      final data = jsonDecode(response.body);
      final orderId = data['id'];

      // 2. Open Razorpay Checkout
      if (_razorpay == null) {
        debugPrint("Razorpay is not supported on this platform.");
        return false;
      }
      
      var options = {
        'key': 'rzp_test_TJlcmhW8KS7SsX', // Test Key
        'amount': amountInRupees * 100,
        'name': 'IT Feels Music Premium',
        'order_id': orderId,
        'description': '$durationDays Days Premium Subscription',
        'prefill': {
          'contact': '',
          'email': user.email ?? '',
        },
        'theme': {
          'color': '#7BA2E7' // AppColors.midnightPrimary
        }
      };

      _razorpay!.open(options);

      // 3. Wait for the completer
      return await _paymentCompleter!.future;
    } catch (e) {
      debugPrint("Razorpay Checkout Exception: $e");
      return false;
    }
  }

  Future<void> _handlePaymentSuccess(PaymentSuccessResponse response) async {
    final user = _auth.currentUser;
    if (user != null) {
      await _firestore.collection('users').doc(user.uid).set({
        'isPremiumFamily': true,
        'premiumGrantedBy': 'razorpay_${response.paymentId}',
        'orderId': response.orderId,
      }, SetOptions(merge: true));
      _paymentCompleter?.complete(true);
    } else {
      _paymentCompleter?.complete(false);
    }
  }

  void _handlePaymentError(PaymentFailureResponse response) {
    debugPrint("Razorpay Error: ${response.code} - ${response.message}");
    _paymentCompleter?.complete(false);
  }

  void _handleExternalWallet(ExternalWalletResponse response) {
    debugPrint("External Wallet Selected: ${response.walletName}");
    _paymentCompleter?.complete(false); // Can handle specific wallet logic here if needed
  }
}
