import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:razorpay_flutter/razorpay_flutter.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class RazorpayService {
  final Razorpay _razorpay = Razorpay();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  
  // TODO: Replace with your actual backend URL where the Cloudflare Proxy is hosted
  static const String _backendUrl = 'https://api.your-cloudflare-worker.workers.dev';
  
  Completer<bool>? _paymentCompleter;
  int _pendingDurationDays = 30;

  RazorpayService() {
    _razorpay.on(Razorpay.EVENT_PAYMENT_SUCCESS, _handlePaymentSuccess);
    _razorpay.on(Razorpay.EVENT_PAYMENT_ERROR, _handlePaymentError);
    _razorpay.on(Razorpay.EVENT_EXTERNAL_WALLET, _handleExternalWallet);
  }

  void dispose() {
    _razorpay.clear();
  }

  Future<bool> checkout(int amountInRupees, int durationDays) async {
    _paymentCompleter = Completer<bool>();
    _pendingDurationDays = durationDays;

    final user = FirebaseAuth.instance.currentUser;
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
      var options = {
        'key': 'rzp_test_placeholder', // TODO: Add public key or fetch from backend
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

      _razorpay.open(options);

      // 3. Wait for the completer
      return await _paymentCompleter!.future;
    } catch (e) {
      debugPrint("Razorpay Checkout Exception: $e");
      return false;
    }
  }

  Future<void> _handlePaymentSuccess(PaymentSuccessResponse response) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      final expiresAt = DateTime.now().add(Duration(days: _pendingDurationDays));
      await _firestore.collection('users').doc(user.uid).collection('entitlements').doc('premium').set({
        'isActive': true,
        'expiresAt': Timestamp.fromDate(expiresAt),
        'grantedBy': 'razorpay_${response.paymentId}',
        'orderId': response.orderId,
      });
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
