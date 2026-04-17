// lib/features/profile/screens/subscription_screen.dart
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:razorpay_flutter/razorpay_flutter.dart';
import 'package:http/http.dart' as http;

import '../../../core/theme/app_theme.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/storage/local_storage.dart';
import '../../../shared/widgets/gradient_button.dart';

class SubscriptionScreen extends StatefulWidget {
  const SubscriptionScreen({super.key});

  @override
  State<SubscriptionScreen> createState() => _SubscriptionScreenState();
}

class _SubscriptionScreenState extends State<SubscriptionScreen>
    with TickerProviderStateMixin {
  late Razorpay _razorpay;
  int _selectedTier = 1; // 0=Free, 1=Pro, 2=Premium
  bool _isProcessing = false;
  late AnimationController _shimmerController;
  late AnimationController _cardController;

  final List<_TierConfig> _tiers = const [
    _TierConfig(
      name: 'Free',
      price: 0,
      period: '',
      color: AppColors.freeTier,
      gradient: [Color(0xFF4A4A4A), Color(0xFF2A2A2A)],
      features: [
        _Feature('20 filters', true),
        _Feature('5 photo booth templates', true),
        _Feature('Basic editing tools', true),
        _Feature('Save to gallery', true),
        _Feature('Photo Booth watermark', false),
        _Feature('Premium filters', false),
        _Feature('100+ templates', false),
        _Feature('Print & ship', false),
        _Feature('Priority support', false),
      ],
    ),
    _TierConfig(
      name: 'Pro',
      price: 99,
      period: '/month',
      color: AppColors.proTier,
      gradient: [Color(0xFF4ECDC4), Color(0xFF1A9E96)],
      features: [
        _Feature('60 filters', true),
        _Feature('50 photo booth templates', true),
        _Feature('Advanced editing studio', true),
        _Feature('No watermark', true),
        _Feature('HD exports', true),
        _Feature('Print orders (10% off)', true),
        _Feature('Priority support', true),
        _Feature('All 120 filters', false),
        _Feature('All 100+ templates', false),
      ],
    ),
    _TierConfig(
      name: 'Premium',
      price: 299,
      period: '/month',
      color: AppColors.premiumTier,
      gradient: [Color(0xFFFFD93D), Color(0xFFFF8C00)],
      features: [
        _Feature('ALL 120+ filters', true),
        _Feature('ALL 100+ templates', true),
        _Feature('Full editing studio', true),
        _Feature('No watermark', true),
        _Feature('4K exports', true),
        _Feature('Unlimited print orders', true),
        _Feature('Free shipping on prints', true),
        _Feature('Early access to new features', true),
        _Feature('Dedicated support', true),
      ],
    ),
  ];

  @override
  void initState() {
    super.initState();
    _shimmerController = AnimationController(vsync: this, duration: const Duration(seconds: 2))
      ..repeat();
    _cardController = AnimationController(vsync: this, duration: const Duration(milliseconds: 400));
    _initRazorpay();
    _cardController.forward();
  }

  void _initRazorpay() {
    _razorpay = Razorpay();
    _razorpay.on(Razorpay.EVENT_PAYMENT_SUCCESS, _onPaymentSuccess);
    _razorpay.on(Razorpay.EVENT_PAYMENT_ERROR, _onPaymentError);
    _razorpay.on(Razorpay.EVENT_EXTERNAL_WALLET, _onExternalWallet);
  }

  Future<void> _subscribe() async {
    if (_selectedTier == 0) return;
    if (_isProcessing) return;

    setState(() => _isProcessing = true);
    HapticFeedback.mediumImpact();

    try {
      final tier = _tiers[_selectedTier];
      final amount = tier.price * 100; // paise

      // Create order on backend
      final token = LocalStorage.getString(AppConstants.tokenKey) ?? '';
      final response = await http.post(
        Uri.parse('${AppConstants.baseUrl}/api/v1/payments/create-order'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({
          'amount': amount,
          'currency': 'INR',
          'plan': tier.name.toLowerCase(),
          'period': 'monthly',
        }),
      );

      if (response.statusCode != 200) {
        throw Exception('Failed to create order');
      }

      final orderData = jsonDecode(response.body);

      // Launch Razorpay
      final options = {
        'key': AppConstants.razorpayKeyId,
        'amount': amount,
        'currency': 'INR',
        'name': AppConstants.appName,
        'description': '${tier.name} Plan - Monthly',
        'order_id': orderData['razorpay_order_id'],
        'prefill': {
          'name': LocalStorage.getString('user_name') ?? '',
          'email': LocalStorage.getString('user_email') ?? '',
          'contact': LocalStorage.getString('user_phone') ?? '',
        },
        'theme': {
          'color': '#FF6B9D',
        },
        'method': {
          'upi': true,
          'card': true,
          'netbanking': true,
          'wallet': true,
        },
        'upi': {
          'flow': 'intent',
          'default_app': 'none',
        },
        // UPI ID for direct UPI payment
        'callback_url': '${AppConstants.baseUrl}/api/v1/payments/razorpay-callback',
        'redirect': false,
      };

      _razorpay.open(options);
    } catch (e) {
      setState(() => _isProcessing = false);
      _showError('Payment initialization failed. Please try again.');
    }
  }

  Future<void> _payViaUPI() async {
    if (_selectedTier == 0) return;
    HapticFeedback.mediumImpact();

    final tier = _tiers[_selectedTier];

    // Direct UPI Intent
    final options = {
      'key': AppConstants.razorpayKeyId,
      'amount': tier.price * 100,
      'currency': 'INR',
      'name': AppConstants.appName,
      'description': '${tier.name} Plan',
      'prefill': {
        'vpa': AppConstants.upiId, // parulsinhaa5@okaxis - shows as payee
      },
      'method': {
        'upi': true,
        'card': false,
        'netbanking': false,
        'wallet': false,
      },
      'theme': {'color': '#FF6B9D'},
    };

    _razorpay.open(options);
  }

  void _onPaymentSuccess(PaymentSuccessResponse response) async {
    setState(() => _isProcessing = false);

    // Verify on backend
    try {
      final token = LocalStorage.getString(AppConstants.tokenKey) ?? '';
      await http.post(
        Uri.parse('${AppConstants.baseUrl}/api/v1/payments/verify'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({
          'razorpay_payment_id': response.paymentId,
          'razorpay_order_id': response.orderId,
          'razorpay_signature': response.signature,
          'plan': _tiers[_selectedTier].name.toLowerCase(),
        }),
      );

      // Update local subscription status
      await LocalStorage.setString('subscription_tier', _tiers[_selectedTier].name.toLowerCase());
      await LocalStorage.setString('subscription_expiry',
        DateTime.now().add(const Duration(days: 30)).toIso8601String());

      if (mounted) _showSuccess();
    } catch (e) {
      _showError('Payment received but verification failed. Contact support.');
    }
  }

  void _onPaymentError(PaymentFailureResponse response) {
    setState(() => _isProcessing = false);
    _showError('Payment failed: ${response.message ?? "Unknown error"}');
  }

  void _onExternalWallet(ExternalWalletResponse response) {
    setState(() => _isProcessing = false);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Opening ${response.walletName}...')),
    );
  }

  void _showSuccess() {
    showDialog(
      context: context,
      builder: (_) => Dialog(
        backgroundColor: AppColors.bgCard,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 80, height: 80,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(colors: [AppColors.pink, AppColors.lavender]),
                ),
                child: const Icon(Icons.check, color: Colors.white, size: 40),
              ),
              const SizedBox(height: 20),
              const Text('Payment Successful!',
                style: TextStyle(color: Colors.white, fontFamily: 'Poppins',
                  fontSize: 20, fontWeight: FontWeight.w700)),
              const SizedBox(height: 8),
              Text('Welcome to ${_tiers[_selectedTier].name}!',
                style: const TextStyle(color: AppColors.textSecondary, fontFamily: 'Poppins')),
              const SizedBox(height: 24),
              GradientButton(
                text: 'Start Exploring',
                onTap: () {
                  Navigator.pop(context);
                  Navigator.pop(context);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: AppColors.error,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  @override
  void dispose() {
    _razorpay.clear();
    _shimmerController.dispose();
    _cardController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bgDark,
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 200,
            pinned: true,
            backgroundColor: AppColors.bgDark,
            flexibleSpace: FlexibleSpaceBar(
              title: const Text('Choose Your Plan',
                style: TextStyle(fontFamily: 'Poppins', fontWeight: FontWeight.w700, fontSize: 18)),
              background: Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [Color(0xFF1A0820), Color(0xFF0A0A1A), Color(0xFF0D0D0D)],
                  ),
                ),
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const SizedBox(height: 40),
                      ShaderMask(
                        shaderCallback: (bounds) => const LinearGradient(
                          colors: [AppColors.pink, AppColors.lavender, AppColors.gold],
                        ).createShader(bounds),
                        child: const Text('Unlock Everything',
                          style: TextStyle(color: Colors.white, fontFamily: 'Poppins',
                            fontSize: 28, fontWeight: FontWeight.w700)),
                      ),
                      const SizedBox(height: 8),
                      const Text('No ads. No limits. Pure creativity.',
                        style: TextStyle(color: AppColors.textSecondary, fontFamily: 'Poppins')),
                    ],
                  ),
                ),
              ),
            ),
          ),

          SliverPadding(
            padding: const EdgeInsets.all(20),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                // Tier selector
                Row(
                  children: List.generate(_tiers.length, (i) => Expanded(
                    child: GestureDetector(
                      onTap: () {
                        setState(() => _selectedTier = i);
                        HapticFeedback.selectionClick();
                      },
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 250),
                        margin: EdgeInsets.only(
                          left: i == 0 ? 0 : 6,
                          right: i == _tiers.length - 1 ? 0 : 6,
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        decoration: BoxDecoration(
                          gradient: _selectedTier == i
                            ? LinearGradient(colors: _tiers[i].gradient)
                            : null,
                          color: _selectedTier == i ? null : AppColors.bgCard,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: _selectedTier == i
                              ? Colors.transparent
                              : Colors.white.withOpacity(0.1),
                          ),
                        ),
                        child: Column(
                          children: [
                            Text(_tiers[i].name,
                              style: TextStyle(
                                color: _selectedTier == i
                                  ? (_tiers[i].name == 'Premium' ? Colors.black : Colors.white)
                                  : AppColors.textSecondary,
                                fontFamily: 'Poppins',
                                fontWeight: FontWeight.w600,
                                fontSize: 14,
                              )),
                            if (_tiers[i].price > 0) ...[
                              const SizedBox(height: 2),
                              Text('₹${_tiers[i].price}',
                                style: TextStyle(
                                  color: _selectedTier == i
                                    ? (_tiers[i].name == 'Premium' ? Colors.black : Colors.white)
                                    : AppColors.textMuted,
                                  fontFamily: 'Poppins',
                                  fontWeight: FontWeight.w700,
                                  fontSize: 12,
                                )),
                            ],
                          ],
                        ),
                      ).animate().scale(
                        begin: const Offset(0.95, 0.95),
                        duration: 200.ms,
                        curve: Curves.easeOut,
                      ),
                    ),
                  )),
                ),

                const SizedBox(height: 28),

                // Selected tier card
                AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        _tiers[_selectedTier].gradient[0].withOpacity(0.15),
                        Colors.transparent,
                      ],
                    ),
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(
                      color: _tiers[_selectedTier].color.withOpacity(0.4),
                      width: 1.5,
                    ),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                              decoration: BoxDecoration(
                                gradient: LinearGradient(colors: _tiers[_selectedTier].gradient),
                                borderRadius: BorderRadius.circular(50),
                              ),
                              child: Text(_tiers[_selectedTier].name,
                                style: TextStyle(
                                  color: _tiers[_selectedTier].name == 'Premium'
                                    ? Colors.black
                                    : Colors.white,
                                  fontFamily: 'Poppins',
                                  fontWeight: FontWeight.w700,
                                  fontSize: 14,
                                )),
                            ),
                            const Spacer(),
                            if (_tiers[_selectedTier].price > 0)
                              RichText(
                                text: TextSpan(
                                  children: [
                                    TextSpan(
                                      text: '₹${_tiers[_selectedTier].price}',
                                      style: const TextStyle(
                                        fontFamily: 'Poppins',
                                        fontSize: 28,
                                        fontWeight: FontWeight.w700,
                                        color: Colors.white,
                                      ),
                                    ),
                                    TextSpan(
                                      text: _tiers[_selectedTier].period,
                                      style: const TextStyle(
                                        fontFamily: 'Poppins',
                                        fontSize: 14,
                                        color: AppColors.textSecondary,
                                      ),
                                    ),
                                  ],
                                ),
                              )
                            else
                              const Text('Free forever',
                                style: TextStyle(color: AppColors.textSecondary,
                                  fontFamily: 'Poppins', fontSize: 16)),
                          ],
                        ),

                        const SizedBox(height: 24),

                        // Features list
                        ..._tiers[_selectedTier].features.map((f) => Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: Row(
                            children: [
                              Icon(
                                f.included ? Icons.check_circle : Icons.cancel,
                                color: f.included
                                  ? _tiers[_selectedTier].color
                                  : AppColors.textMuted,
                                size: 18,
                              ),
                              const SizedBox(width: 12),
                              Text(f.label,
                                style: TextStyle(
                                  color: f.included ? Colors.white : AppColors.textMuted,
                                  fontFamily: 'Poppins',
                                  fontSize: 14,
                                  decoration: f.included ? null : TextDecoration.lineThrough,
                                )),
                            ],
                          ),
                        )).toList(),
                      ],
                    ),
                  ),
                ).animate().slideY(begin: 0.1, duration: 300.ms),

                const SizedBox(height: 28),

                // Payment buttons
                if (_selectedTier > 0) ...[
                  GradientButton(
                    text: _isProcessing
                      ? 'Processing...'
                      : 'Subscribe with Card / Net Banking',
                    isLoading: _isProcessing,
                    gradient: LinearGradient(colors: _tiers[_selectedTier].gradient),
                    textColor: _tiers[_selectedTier].name == 'Premium'
                      ? Colors.black
                      : Colors.white,
                    onTap: _isProcessing ? null : _subscribe,
                  ),

                  const SizedBox(height: 12),

                  // UPI Button
                  GestureDetector(
                    onTap: _isProcessing ? null : _payViaUPI,
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      decoration: BoxDecoration(
                        color: AppColors.bgCard,
                        borderRadius: BorderRadius.circular(50),
                        border: Border.all(
                          color: Colors.white.withOpacity(0.15),
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(4),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: const Text('UPI',
                              style: TextStyle(
                                color: Color(0xFF097939),
                                fontFamily: 'Poppins',
                                fontWeight: FontWeight.w900,
                                fontSize: 11,
                              )),
                          ),
                          const SizedBox(width: 10),
                          const Text('Pay via UPI',
                            style: TextStyle(
                              color: Colors.white,
                              fontFamily: 'Poppins',
                              fontWeight: FontWeight.w600,
                              fontSize: 16,
                            )),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 16),

                  // Payment logos
                  Wrap(
                    alignment: WrapAlignment.center,
                    spacing: 12,
                    children: [
                      _PaymentBadge(label: 'Visa'),
                      _PaymentBadge(label: 'Mastercard'),
                      _PaymentBadge(label: 'RuPay'),
                      _PaymentBadge(label: 'GPay'),
                      _PaymentBadge(label: 'PhonePe'),
                      _PaymentBadge(label: 'Paytm'),
                    ],
                  ),

                  const SizedBox(height: 12),

                  Center(
                    child: Text(
                      'Secured by Razorpay. Cancel anytime.',
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.4),
                        fontFamily: 'Poppins',
                        fontSize: 12,
                      ),
                    ),
                  ),
                ] else ...[
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: AppColors.bgCard,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: const Row(
                      children: [
                        Icon(Icons.info_outline, color: AppColors.textSecondary, size: 20),
                        SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            'You are on the Free plan. Upgrade to unlock premium features.',
                            style: TextStyle(color: AppColors.textSecondary,
                              fontFamily: 'Poppins', fontSize: 13),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],

                const SizedBox(height: 40),
              ]),
            ),
          ),
        ],
      ),
    );
  }
}

class _TierConfig {
  final String name;
  final int price;
  final String period;
  final Color color;
  final List<Color> gradient;
  final List<_Feature> features;

  const _TierConfig({
    required this.name,
    required this.price,
    required this.period,
    required this.color,
    required this.gradient,
    required this.features,
  });
}

class _Feature {
  final String label;
  final bool included;
  const _Feature(this.label, this.included);
}

class _PaymentBadge extends StatelessWidget {
  final String label;
  const _PaymentBadge({required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: Colors.white.withOpacity(0.1)),
      ),
      child: Text(label,
        style: TextStyle(
          color: Colors.white.withOpacity(0.5),
          fontFamily: 'Poppins',
          fontSize: 11,
          fontWeight: FontWeight.w500,
        )),
    );
  }
}
