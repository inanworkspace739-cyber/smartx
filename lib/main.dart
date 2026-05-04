import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:media_kit/media_kit.dart';
import 'providers/playlist_provider.dart';
import 'screens/splash_screen.dart';
import 'theme/app_theme.dart';

import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'services/ad_manager.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Force portrait mode globally
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  MediaKit.ensureInitialized();

  // Initialize MobileAds and setup the AppLifecycleReactor for App Open Ads
  await MobileAds.instance.initialize();
  final adManager = AdManager.instance;
  adManager.loadAppOpenAd();
  adManager.loadInterstitialAd();
  AppLifecycleReactor(adManager: adManager).listenToAppStateChanges();

  final playlistProvider = PlaylistProvider();
  await playlistProvider.init();

  runApp(
    ChangeNotifierProvider.value(
      value: playlistProvider,
      child: const M3uPlayerApp(),
    ),
  );
}

class M3uPlayerApp extends StatelessWidget {
  const M3uPlayerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Smarters Pro: Premium IPTV',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.darkTheme,
      home: const SplashScreen(),
    );
  }
}
