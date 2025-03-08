import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:dynamic_color/dynamic_color.dart';
import 'package:quick_actions/quick_actions.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:provider/provider.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'dart:developer' as developer;
import 'package:page_transition/page_transition.dart';
// import 'config/edge_to_edge_config.dart';
import 'firebase_options.dart';
import 'main/chat/chats/ai_page.dart';
import 'main/board/boards/search_subpage.dart';
import 'main/pages/upload_posts.dart';
import 'main/pages/settings_provider.dart';
import 'auth/login_screen.dart';
import 'auth/onboarding_screen.dart';
import 'main/main_page.dart';

// Quick Actions Service class to handle platform-specific functionality

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

class QuickActionsService {
  final QuickActions? _quickActions;
  final bool enableLogging;

  QuickActionsService({this.enableLogging = true})
      : _quickActions = kIsWeb ? null : const QuickActions();

  bool get isQuickActionSupported => !kIsWeb;

  Future<void> setupQuickActions() async {
    // No need for context parameter anymore
    if (kIsWeb) {
      if (enableLogging)
        developer.log('Quick Actions: Skipped setup on web platform');
      return;
    }

    // Rest of setup code remains the same
    if (enableLogging) developer.log('Quick Actions: Setting up shortcuts');

    try {
      await _quickActions?.setShortcutItems(<ShortcutItem>[
        const ShortcutItem(
            type: 'search_page',
            localizedTitle: 'Pencarian',
            icon: 'icon_search'),
        const ShortcutItem(
            type: 'ai_page', localizedTitle: 'AI Chat', icon: 'icon_ai'),
        const ShortcutItem(
            type: 'upload_post',
            localizedTitle: 'Unggah Foto',
            icon: 'icon_upload'),
      ]);

      if (enableLogging)
        developer.log('Quick Actions: Shortcuts setup successful');

      await _quickActions?.initialize((shortcutType) {
        if (enableLogging)
          developer.log('Quick Actions: Shortcut triggered: $shortcutType');

        if (shortcutType == 'search_page') {
          _navigateToSearch();
        } else if (shortcutType == 'ai_page') {
          _navigateToAIPage();
        } else if (shortcutType == 'upload_post') {
          _navigateToUploadPost();
        }
      });

      if (enableLogging)
        developer.log('Quick Actions: Initialization successful');
    } catch (e) {
      if (enableLogging) developer.log('Quick Actions: Error during setup: $e');
    }
  }

  void _navigateToSearch() {
    // No longer needs context
    if (enableLogging)
      developer.log('Quick Actions: Navigating to search page');

    Future.delayed(const Duration(milliseconds: 100), () {
      // Use the global navigator key
      final navigator = navigatorKey.currentState;
      if (navigator != null) {
        navigator.pushNamed('/search');
        if (enableLogging) developer.log('Quick Actions: Navigation executed');
      } else {
        if (enableLogging)
          developer.log(
              'Quick Actions: Navigator not available, navigation skipped');
      }
    });
  }

  void _navigateToAIPage() {
    if (enableLogging) developer.log('Quick Actions: Navigating to ai page');

    Future.delayed(const Duration(milliseconds: 100), () {
      final navigator = navigatorKey.currentState;
      if (navigator != null) {
        navigator.push(
          PageTransition(
            type: PageTransitionType.sharedAxisVertical,
            child: AIPage(),
          ),
        );
        if (enableLogging) developer.log('Quick Actions: Navigation executed');
      } else {
        if (enableLogging)
          developer.log(
              'Quick Actions: Navigator not available, navigation skipped');
      }
    });
  }

  void _navigateToUploadPost() {
    if (enableLogging)
      developer.log('Quick Actions: Navigating to upload post page');

    Future.delayed(const Duration(milliseconds: 100), () {
      final navigator = navigatorKey.currentState;
      if (navigator != null) {
        navigator.push(
          PageTransition(
            type: PageTransitionType.sharedAxisVertical,
            child: UploadPosts(),
          ),
        );
        if (enableLogging) developer.log('Quick Actions: Navigation executed');
      } else {
        if (enableLogging)
          developer.log(
              'Quick Actions: Navigator not available, navigation skipped');
      }
    });
  }

  // Simulate quick action on web for testing
  void simulateQuickAction(String type) {
    // No longer needs context
    if (!kIsWeb) return;

    developer.log('Quick Actions Simulator: Simulating shortcut: $type');
    if (type == 'search_page') {
      _navigateToSearch();
    } else if (type == 'ai_page') {
      _navigateToAIPage();
    } else if (type == 'upload_post') {
      _navigateToUploadPost();
    }
  }
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);

  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  runApp(
    ChangeNotifierProvider(
      create: (_) => ViewStyleProvider(),
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  bool? _onboardingCompleted;
  bool? _isLoggedIn;
  late final QuickActionsService _quickActionsService;

  @override
  void initState() {
    super.initState();
    _quickActionsService = QuickActionsService(enableLogging: true);
    _checkInitialStatus();

    // We'll set up quick actions after we know the user's login state
  }

  Future<void> _checkInitialStatus() async {
    final prefs = await SharedPreferences.getInstance();
    final bool onboardingCompleted =
        prefs.getBool('onboardingCompleted') ?? false;
    final String? uid = prefs.getString('uid');
    final bool isLoggedIn = uid != null;

    setState(() {
      _onboardingCompleted = onboardingCompleted;
      _isLoggedIn = isLoggedIn;
    });

    // Set up quick actions after we know the login state
    if (mounted && onboardingCompleted && isLoggedIn) {
      // Use post-frame callback to ensure context is ready
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _quickActionsService.setupQuickActions();
          developer
              .log('Quick Actions: Setup completed after checking login state');
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(
          create: (context) => ThemeProvider()..initialize(),
        ),
        ChangeNotifierProvider(
          create: (context) => ViewStyleProvider(),
        ),
      ],
      child: Consumer2<ThemeProvider, ViewStyleProvider>(
        builder: (context, themeProvider, viewStyleProvider, child) {
          if (!themeProvider.isInitialized) {
            return const MaterialApp(
              home: Scaffold(
                body: Center(
                  child: CircularProgressIndicator(),
                ),
              ),
            );
          }

          return DynamicColorBuilder(
            builder: (ColorScheme? lightDynamic, ColorScheme? darkDynamic) {
              ColorScheme lightScheme;
              ColorScheme darkScheme;

              if (lightDynamic != null &&
                  darkDynamic != null &&
                  themeProvider.isDynamic) {
                lightScheme = lightDynamic.harmonized();
                darkScheme = darkDynamic.harmonized();
              } else {
                lightScheme = ColorScheme.fromSeed(
                  seedColor: themeProvider.primaryColor,
                );
                darkScheme = ColorScheme.fromSeed(
                  seedColor: themeProvider.primaryColor,
                  brightness: Brightness.dark,
                );
              }

              Widget appWithDebugOverlay(Widget app) {
                if (!kIsWeb) return app;

                // Add a debug overlay button for web testing
                return Directionality(
                  textDirection:
                      TextDirection.ltr, // Explicitly provide text direction
                  child: Stack(
                    children: [
                      app,
                      // if (_onboardingCompleted == true && _isLoggedIn == true)
                      //   Positioned(
                      //     bottom: 100,
                      //     right: 20,
                      //     child: Column(
                      //       mainAxisSize: MainAxisSize.min,
                      //       crossAxisAlignment: CrossAxisAlignment.end,
                      //       children: [
                      //         FloatingActionButton.extended(
                      //           heroTag: 'search_shortcut',
                      //           label: const Text('Simulate Search'),
                      //           icon: const Icon(Icons.search),
                      //           onPressed: () => _quickActionsService
                      //               .simulateQuickAction('search_page'),
                      //           backgroundColor:
                      //               lightScheme.primaryContainer.withOpacity(0.8),
                      //         ),
                      //         const SizedBox(height: 8),
                      //         FloatingActionButton.extended(
                      //           heroTag: 'ai_shortcut',
                      //           label: const Text('Simulate AI_page'),
                      //           icon: const Icon(Icons.auto_awesome),
                      //           onPressed: () => _quickActionsService
                      //               .simulateQuickAction('ai_page'),
                      //           backgroundColor:
                      //               lightScheme.secondaryContainer.withOpacity(0.8),
                      //         ),
                      //         const SizedBox(height: 8),
                      //         FloatingActionButton.extended(
                      //           heroTag: 'upload_shortcut',
                      //           label: const Text('Simulate Upload'),
                      //           icon: const Icon(Icons.add),
                      //           onPressed: () => _quickActionsService
                      //               .simulateQuickAction('upload_post'),
                      //           backgroundColor:
                      //               lightScheme.tertiaryContainer.withOpacity(0.8),
                      //         ),
                      //       ],
                      //     ),
                      //   ),
                    ],
                  ),
                );
              }

              return appWithDebugOverlay(
                MaterialApp(
                  navigatorKey: navigatorKey,
                  title: 'Gnoo',
                  debugShowCheckedModeBanner: false,
                  theme: _buildThemeData(lightScheme, Brightness.light),
                  darkTheme: _buildThemeData(darkScheme, Brightness.dark),
                  themeMode: themeProvider.themeMode,
                  // builder: (context, child) {
                  //   return EdgeToEdgeWrapperWidget(
                  //     child: child!,
                  //   );
                  // },
                  builder: (context, child) {
                    return child!;
                  },
                  home: _onboardingCompleted == null || _isLoggedIn == null
                      ? const Scaffold(
                          body: Center(
                            child: CircularProgressIndicator(),
                          ),
                        )
                      : _onboardingCompleted!
                          ? (_isLoggedIn!
                              ? const MainPage()
                              : const LoginScreen())
                          : const OnboardingScreen(),
                  routes: {
                    '/search': (context) => const SearchPage(), // Route statis
                  },
                  onGenerateRoute: (settings) {
                    if (settings.name == '/search') {
                      return MaterialPageRoute(
                        builder: (context) => const SearchPage(),
                      );
                    }
                    return null;
                  },
                ),
              );
            },
          );
        },
      ),
    );
  }

  ThemeData _buildThemeData(ColorScheme colorScheme, Brightness brightness) {
    return ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      fontFamily: 'Outfit',
      textTheme: const TextTheme(
        displayLarge: TextStyle(fontFamily: 'NoyhR'),
        displayMedium: TextStyle(fontFamily: 'NoyhR'),
        displaySmall: TextStyle(fontFamily: 'NoyhR'),
        headlineLarge: TextStyle(fontFamily: 'NoyhR'),
        headlineMedium: TextStyle(fontFamily: 'NoyhR'),
        headlineSmall: TextStyle(fontFamily: 'NoyhR'),
        titleLarge: TextStyle(fontFamily: 'NoyhR'),
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: colorScheme.surface,
        foregroundColor: colorScheme.onSurface,
        systemOverlayStyle: SystemUiOverlayStyle(
          statusBarColor: Colors.transparent,
          statusBarIconBrightness: brightness == Brightness.light
              ? Brightness.dark
              : Brightness.light,
          statusBarBrightness: brightness == Brightness.light
              ? Brightness.light
              : Brightness.dark,
          systemNavigationBarColor: colorScheme.surface,
          systemNavigationBarIconBrightness: brightness == Brightness.light
              ? Brightness.dark
              : Brightness.light,
        ),
        scrolledUnderElevation: 0,
      ),
      cardTheme: CardTheme(
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
      ),
      navigationBarTheme: const NavigationBarThemeData(
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        elevation: 0,
      ),
    );
  }
}
