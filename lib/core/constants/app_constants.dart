// lib/core/constants/app_constants.dart

class AppConstants {
  AppConstants._();

  static const String appName = 'Photo Booth';
  static const String appVersion = '1.0.0';
  static const String appBundleId = 'com.photobooth.app';

  // API
  static const String baseUrl = String.fromEnvironment(
    'BASE_URL',
    defaultValue: 'https://api.photobooth.app',
  );
  static const String wsUrl = String.fromEnvironment(
    'WS_URL',
    defaultValue: 'wss://api.photobooth.app/ws',
  );
  static const int apiTimeoutSeconds = 30;

  // Razorpay
  static const String razorpayKeyId = String.fromEnvironment(
    'RAZORPAY_KEY_ID',
    defaultValue: 'rzp_live_YOUR_KEY_HERE',
  );
  static const String razorpayKeySecret = String.fromEnvironment(
    'RAZORPAY_KEY_SECRET',
    defaultValue: '',
  );

  // UPI
  static const String upiId = 'parulsinhaa5@okaxis';
  static const String upiName = 'Photo Booth';
  static const String upiMerchantCode = 'PHOTOBOOTH';

  // Firebase
  static const String fcmTopic = 'photobooth_all';

  // Storage Keys
  static const String tokenKey = 'auth_token';
  static const String refreshTokenKey = 'refresh_token';
  static const String userKey = 'user_data';
  static const String themeKey = 'app_theme';
  static const String onboardingKey = 'onboarding_done';

  // Photo Booth
  static const int minPhotos = 2;
  static const int maxPhotos = 8;
  static const int countdownSeconds = 3;
  static const double stripAspectRatio = 1.0 / 3.0;

  // Filters
  static const int totalFilters = 120;
  static const int freeFilters = 20;

  // Pricing (in paise for Razorpay)
  static const int proPriceMonthly = 9900;       // Rs 99
  static const int premiumPriceMonthly = 29900;  // Rs 299
  static const int filterUnlockPrice = 900;      // Rs 9
  static const int printBasePrice = 4900;        // Rs 49 per print

  // Chat
  static const int disappearingMessageSeconds = 10;
  static const int maxChatMediaSizeMB = 50;

  // Image Quality
  static const int captureQuality = 100;
  static const double stripDpi = 300.0;
  static const int thumbnailSize = 300;

  // Pagination
  static const int pageSize = 20;

  // Supported Countries & Currencies
  static const Map<String, CountryConfig> countries = {
    'IN': CountryConfig(
      name: 'India',
      currency: 'INR',
      symbol: '₹',
      phoneCode: '+91',
      gateway: 'razorpay',
    ),
    'US': CountryConfig(
      name: 'United States',
      currency: 'USD',
      symbol: '\$',
      phoneCode: '+1',
      gateway: 'stripe',
    ),
    'GB': CountryConfig(
      name: 'United Kingdom',
      currency: 'GBP',
      symbol: '£',
      phoneCode: '+44',
      gateway: 'stripe',
    ),
    'AE': CountryConfig(
      name: 'UAE',
      currency: 'AED',
      symbol: 'AED',
      phoneCode: '+971',
      gateway: 'stripe',
    ),
    'AU': CountryConfig(
      name: 'Australia',
      currency: 'AUD',
      symbol: 'A\$',
      phoneCode: '+61',
      gateway: 'stripe',
    ),
    'CA': CountryConfig(
      name: 'Canada',
      currency: 'CAD',
      symbol: 'C\$',
      phoneCode: '+1',
      gateway: 'stripe',
    ),
    'SG': CountryConfig(
      name: 'Singapore',
      currency: 'SGD',
      symbol: 'S\$',
      phoneCode: '+65',
      gateway: 'stripe',
    ),
    'EU': CountryConfig(
      name: 'Europe',
      currency: 'EUR',
      symbol: '€',
      phoneCode: '+49',
      gateway: 'stripe',
    ),
  };
}

class CountryConfig {
  final String name;
  final String currency;
  final String symbol;
  final String phoneCode;
  final String gateway;

  const CountryConfig({
    required this.name,
    required this.currency,
    required this.symbol,
    required this.phoneCode,
    required this.gateway,
  });
}
