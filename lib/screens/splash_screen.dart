import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../core/gen/assets.gen.dart';
import 'auth/login_screen.dart';
import 'home/home_screen.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with TickerProviderStateMixin {
  late AnimationController _fadeController;
  late AnimationController _scaleController;
  late Animation<double> _fadeAnimation;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();

    // Initialize animations
    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 1200),
      vsync: this,
    );

    _scaleController = AnimationController(
      duration: const Duration(milliseconds: 1200),
      vsync: this,
    );

    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeInOut,
    ));

    _scaleAnimation = Tween<double>(
      begin: 0.5,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _scaleController,
      curve: Curves.easeInOut,
    ));

    _startAnimations();
    _navigateToNextScreen();
  }

  void _startAnimations() {
    // Mulai semua animasi sekaligus untuk smooth transition tanpa kedip
    _fadeController.forward();
    _scaleController.forward();
  }

  void _navigateToNextScreen() {
    // Delay sesuai dengan durasi animasi (1500ms fade + sedikit buffer)
    Future.delayed(const Duration(milliseconds: 2000), () {
      if (mounted) {
        final authProvider = Provider.of<AuthProvider>(context, listen: false);

        Navigator.of(context).pushReplacement(
          PageRouteBuilder(
            pageBuilder: (context, animation, secondaryAnimation) {
              if (!authProvider.isAuthenticated) {
                return const LoginScreen();
              }
              return const HomeScreen();
            },
            transitionsBuilder:
                (context, animation, secondaryAnimation, child) {
              return FadeTransition(opacity: animation, child: child);
            },
            transitionDuration: const Duration(milliseconds: 500),
          ),
        );
      }
    });
  }

  @override
  void dispose() {
    _fadeController.dispose();
    _scaleController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // Background Image
          Positioned.fill(
            child: Image(
              image: Assets.images.splashScreen.provider(),
              fit: BoxFit.cover,
            ),
          ),

          // Gradient Overlay
          Positioned(
            left: 0,
            top: 109,
            child: Container(
              width: MediaQuery.of(context).size.width,
              height: MediaQuery.of(context).size.height,
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment(0.50, 0.00),
                  end: Alignment(0.50, 1.00),
                  colors: [
                    Color(0x007A0006),
                    Color(0xBF4E0006),
                    Color(0xFF230007)
                  ],
                ),
              ),
            ),
          ),

          // Content
          SafeArea(
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
          
                  const Spacer(flex: 2),

                    // Main Logo - Full Image
                      ScaleTransition(
                      scale: _scaleAnimation,
                      child: FadeTransition(
                        opacity: _fadeAnimation,
                        child: SizedBox(
                        height: MediaQuery.of(context).size.height * 0.3,
                        child: Image(
                          image: Assets.logo.splash.provider(),
                          fit: BoxFit.contain,
                        ),
                        ),
                      ),
                      ),

                  const Spacer(flex: 2),

                  // Footer with "by" and logo
                  FadeTransition(
                    opacity: _fadeAnimation,
                    child: Padding(
                      padding: const EdgeInsets.only(bottom: 40),
                      child: Column(
                        children: [
                        
                          const SizedBox(height: 12),
                          Image(
                            image: Assets.logo.mekansm.provider(),
                            height: 20,
                            fit: BoxFit.contain,
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

}
