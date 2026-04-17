// lib/main.dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'core/theme/app_theme.dart';
import 'core/constants/app_constants.dart';
import 'core/network/dio_client.dart';
import 'core/storage/local_storage.dart';
import 'core/utils/app_router.dart';
import 'features/auth/bloc/auth_bloc.dart';
import 'features/auth/repo/auth_repo.dart';
import 'features/camera/bloc/camera_bloc.dart';
import 'features/chat/bloc/chat_bloc.dart';
import 'features/orders/bloc/orders_bloc.dart';
import 'features/profile/bloc/profile_bloc.dart';
import 'shared/services/notification_service.dart';
import 'shared/services/analytics_service.dart';

void main() async {
  runZonedGuarded(() async {
    WidgetsFlutterBinding.ensureInitialized();

    // Lock orientation
    await SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
    ]);

    // Status bar transparent
    SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
      systemNavigationBarColor: Colors.black,
      systemNavigationBarIconBrightness: Brightness.light,
    ));

    // Init Firebase
    await Firebase.initializeApp();

    // Init Hive local storage
    await Hive.initFlutter();
    await LocalStorage.init();

    // Init notifications
    await NotificationService.instance.initialize();

    // Analytics
    await AnalyticsService.instance.initialize();

    runApp(const PhotoBoothApp());
  }, (error, stack) {
    // Global error handler
    debugPrint('UNCAUGHT ERROR: $error');
    debugPrint('STACK: $stack');
  });
}

class PhotoBoothApp extends StatelessWidget {
  const PhotoBoothApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiRepositoryProvider(
      providers: [
        RepositoryProvider<AuthRepo>(create: (_) => AuthRepo(DioClient.instance)),
      ],
      child: MultiBlocProvider(
        providers: [
          BlocProvider<AuthBloc>(
            create: (ctx) => AuthBloc(ctx.read<AuthRepo>())..add(AuthCheckStatusEvent()),
          ),
          BlocProvider<CameraBloc>(
            create: (_) => CameraBloc(),
          ),
          BlocProvider<ChatBloc>(
            create: (_) => ChatBloc(),
          ),
          BlocProvider<OrdersBloc>(
            create: (_) => OrdersBloc(),
          ),
          BlocProvider<ProfileBloc>(
            create: (_) => ProfileBloc(),
          ),
        ],
        child: BlocBuilder<AuthBloc, AuthState>(
          builder: (context, authState) {
            return MaterialApp.router(
              title: AppConstants.appName,
              theme: AppTheme.darkTheme,
              darkTheme: AppTheme.darkTheme,
              themeMode: ThemeMode.dark,
              routerConfig: AppRouter.router(authState),
              debugShowCheckedModeBanner: false,
              builder: (context, child) {
                return MediaQuery(
                  data: MediaQuery.of(context).copyWith(
                    textScaleFactor: 1.0, // Prevent system font scaling from breaking UI
                  ),
                  child: child!,
                );
              },
            );
          },
        ),
      ),
    );
  }
}
