import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:app_tracking_transparency/app_tracking_transparency.dart';
import '../theme/app_theme.dart';
import 'home_screen.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  double _progress = 0.0;
  Timer? _timer;
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();

    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeIn),
    );

    _animationController.forward();
    
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _requestTrackingPermission().then((_) {
        _startLoading();
      });
    });
  }

  Future<void> _requestTrackingPermission() async {
    try {
      final TrackingStatus status =
          await AppTrackingTransparency.trackingAuthorizationStatus;
      
      if (status == TrackingStatus.notDetermined) {
        // Wait a brief moment before showing the dialog for better UX
        await Future.delayed(const Duration(milliseconds: 200));
        await AppTrackingTransparency.requestTrackingAuthorization();
      }
    } catch (e) {
      debugPrint('Error requesting ATT permission: $e');
    }
  }

  void _startLoading() {
    const totalDuration = Duration(seconds: 5);
    const interval = Duration(milliseconds: 50);
    final totalSteps = totalDuration.inMilliseconds / interval.inMilliseconds;
    int currentStep = 0;

    _timer = Timer.periodic(interval, (timer) {
      currentStep++;
      setState(() {
        _progress = currentStep / totalSteps;
      });

      if (currentStep >= totalSteps) {
        _timer?.cancel();
        _navigateToHome();
      }
    });
  }

  void _navigateToHome() {
    if (mounted) {
      Navigator.of(
        context,
      ).pushReplacement(MaterialPageRoute(builder: (_) => const HomeScreen()));
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Using current AppTheme.bgDark as the base background color
    return Scaffold(
      backgroundColor: AppTheme.bgDark,
      body: FadeTransition(
        opacity: _fadeAnimation,
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Logo
              Container(
                width: 150,
                height: 150,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(32),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.3),
                      blurRadius: 20,
                      offset: const Offset(0, 10),
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(32),
                  child: Image.asset(
                    'assets/icon.png',
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) {
                      return const Icon(
                        Icons.live_tv_rounded,
                        size: 80,
                        color: Colors.white,
                      );
                    },
                  ),
                ),
              ),
              const SizedBox(height: 48),
              // App Name
              Text(
                'Smarters Pro',
                style: GoogleFonts.outfit(
                  fontSize: 32,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                  letterSpacing: 1.2,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'PRO IPTV PLAYER',
                style: GoogleFonts.inter(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: Colors.white.withValues(alpha: 0.5),
                  letterSpacing: 4,
                ),
              ),
              const SizedBox(height: 64),
              // Progress Bar
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 64),
                child: Column(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: LinearProgressIndicator(
                        value: _progress,
                        minHeight: 6,
                        backgroundColor: Colors.white.withValues(alpha: 0.1),
                        valueColor: const AlwaysStoppedAnimation<Color>(
                          AppTheme.accent,
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      '${(_progress * 100).toInt()}%',
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        color: Colors.white.withValues(alpha: 0.7),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
