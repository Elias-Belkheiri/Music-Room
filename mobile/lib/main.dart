import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:provider/provider.dart';
import 'providers/user_profile_provider.dart';
import 'providers/audio_provider.dart';
import 'providers/playlist_provider.dart';
import 'config/app_theme.dart';
import 'providers/auth_provider.dart';
import 'providers/connectivity_provider.dart';
import 'providers/subscription_provider.dart';
import 'router/app_router_delegate.dart';
import 'router/app_route_information_parser.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Load environment variables from .env asset
  try {
    await dotenv.load(fileName: '.env');
  } catch (e) {
    debugPrint('Could not load .env file: $e');
  }

  // Pre-initialize Google Sign-In with platform-specific client IDs
  await AuthProvider.initializeGoogleSignIn();

  // Force dark status bar to match the app theme
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.light,
    systemNavigationBarColor: AppTheme.background,
    systemNavigationBarIconBrightness: Brightness.light,
  ));

    runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthProvider()),
        ChangeNotifierProvider(create: (_) => ConnectivityProvider()),
        ChangeNotifierProvider(create: (_) => SubscriptionProvider()),
        ChangeNotifierProxyProvider<AuthProvider, UserProfileProvider>(
          create: (_) => UserProfileProvider(),
          update: (_, auth, userProfile) => userProfile!..updateAuthProvider(auth),
        ),
        ChangeNotifierProvider(create: (_) => AudioProvider()),
        ChangeNotifierProxyProvider<AuthProvider, PlaylistProvider>(
          create: (_) => PlaylistProvider(),
          update: (_, auth, playlistProvider) =>
              playlistProvider!..updateAuthProvider(auth),
        ),
      ],
      child: const MusicRoomApp(),
    ),
  );
}

/// Root widget for MusicRoom.
/// Uses [MaterialApp.router] with Navigator 2.0 for declarative routing
/// driven by [AuthProvider] state.
class MusicRoomApp extends StatefulWidget {
  const MusicRoomApp({super.key});

  @override
  State<MusicRoomApp> createState() => _MusicRoomAppState();
}

class _MusicRoomAppState extends State<MusicRoomApp> {
  late final AppRouterDelegate _routerDelegate;
  final _routeInformationParser = AppRouteInformationParser();

  @override
  void initState() {
    super.initState();
    // Create the router delegate with a reference to AuthProvider.
    // We use `listen: false` because the delegate registers its own listener.
    _routerDelegate = AppRouterDelegate(
      authProvider: Provider.of<AuthProvider>(context, listen: false),
    );
  }

  @override
  void dispose() {
    _routerDelegate.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'MusicRoom',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.darkTheme,
      routerDelegate: _routerDelegate,
      routeInformationParser: _routeInformationParser,
    );
  }
}
