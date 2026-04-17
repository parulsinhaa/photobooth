// lib/core/utils/app_router.dart
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../features/auth/screens/splash_screen.dart';
import '../../features/auth/screens/onboarding_screen.dart';
import '../../features/auth/screens/login_screen.dart';
import '../../features/auth/screens/register_screen.dart';
import '../../features/auth/screens/otp_screen.dart';
import '../../features/auth/bloc/auth_bloc.dart';
import '../../features/camera/screens/camera_screen.dart';
import '../../features/photobooth/screens/photobooth_screen.dart';
import '../../features/photobooth/screens/strip_result_screen.dart';
import '../../features/editor/screens/editor_screen.dart';
import '../../features/discover/screens/discover_screen.dart';
import '../../features/chat/screens/chat_list_screen.dart';
import '../../features/chat/screens/chat_conversation_screen.dart';
import '../../features/orders/screens/orders_screen.dart';
import '../../features/orders/screens/order_detail_screen.dart';
import '../../features/orders/screens/checkout_screen.dart';
import '../../features/profile/screens/profile_screen.dart';
import '../../features/profile/screens/settings_screen.dart';
import '../../features/profile/screens/subscription_screen.dart';
import '../widgets/main_shell.dart';

class AppRouter {
  static GoRouter router(AuthState authState) {
    return GoRouter(
      initialLocation: '/splash',
      redirect: (context, state) {
        final isAuth = authState is AuthAuthenticated;
        final isLoading = authState is AuthLoading || authState is AuthInitial;
        final isSplash = state.matchedLocation == '/splash';
        final isOnboarding = state.matchedLocation == '/onboarding';
        final isAuthRoute = state.matchedLocation.startsWith('/auth');

        if (isLoading || isSplash) return null;
        if (!isAuth && !isAuthRoute && !isOnboarding) return '/auth/login';
        if (isAuth && isAuthRoute) return '/camera';
        return null;
      },
      routes: [
        GoRoute(
          path: '/splash',
          builder: (_, __) => const SplashScreen(),
        ),
        GoRoute(
          path: '/onboarding',
          builder: (_, __) => const OnboardingScreen(),
        ),
        GoRoute(
          path: '/auth/login',
          builder: (_, __) => const LoginScreen(),
        ),
        GoRoute(
          path: '/auth/register',
          builder: (_, __) => const RegisterScreen(),
        ),
        GoRoute(
          path: '/auth/otp',
          builder: (_, state) => OtpScreen(
            phone: state.extra as String? ?? '',
          ),
        ),

        // Main shell with bottom navigation
        ShellRoute(
          builder: (context, state, child) => MainShell(child: child),
          routes: [
            GoRoute(
              path: '/camera',
              builder: (_, __) => const CameraScreen(),
            ),
            GoRoute(
              path: '/photobooth',
              builder: (_, __) => const PhotoBoothScreen(),
            ),
            GoRoute(
              path: '/photobooth/result',
              builder: (_, state) => StripResultScreen(
                stripData: state.extra as Map<String, dynamic>? ?? {},
              ),
            ),
            GoRoute(
              path: '/editor',
              builder: (_, state) => EditorScreen(
                imageData: state.extra as Map<String, dynamic>?,
              ),
            ),
            GoRoute(
              path: '/discover',
              builder: (_, __) => const DiscoverScreen(),
            ),
            GoRoute(
              path: '/chat',
              builder: (_, __) => const ChatListScreen(),
            ),
            GoRoute(
              path: '/chat/:userId',
              builder: (_, state) => ChatConversationScreen(
                userId: state.pathParameters['userId']!,
                userName: (state.extra as Map<String, dynamic>?)?['name'] ?? '',
                userAvatar: (state.extra as Map<String, dynamic>?)?['avatar'],
              ),
            ),
            GoRoute(
              path: '/orders',
              builder: (_, __) => const OrdersScreen(),
            ),
            GoRoute(
              path: '/orders/:orderId',
              builder: (_, state) => OrderDetailScreen(
                orderId: state.pathParameters['orderId']!,
              ),
            ),
            GoRoute(
              path: '/checkout',
              builder: (_, state) => CheckoutScreen(
                checkoutData: state.extra as Map<String, dynamic>? ?? {},
              ),
            ),
            GoRoute(
              path: '/profile',
              builder: (_, __) => const ProfileScreen(),
            ),
            GoRoute(
              path: '/settings',
              builder: (_, __) => const SettingsScreen(),
            ),
            GoRoute(
              path: '/subscription',
              builder: (_, __) => const SubscriptionScreen(),
            ),
          ],
        ),
      ],
      errorBuilder: (context, state) => Scaffold(
        backgroundColor: const Color(0xFF0D0D0D),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, color: Colors.pink, size: 64),
              const SizedBox(height: 16),
              Text(
                'Page not found',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(color: Colors.white),
              ),
              const SizedBox(height: 8),
              TextButton(
                onPressed: () => context.go('/camera'),
                child: const Text('Go Home', style: TextStyle(color: Colors.pink)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
