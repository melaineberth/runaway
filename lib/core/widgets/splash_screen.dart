import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:runaway/core/helper/extensions/extensions.dart';
import 'package:runaway/core/blocs/connectivity/connectivity_cubit.dart';
import 'package:runaway/core/helper/services/connectivity_service.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> with TickerProviderStateMixin {
  late AnimationController _fadeController;
  late AnimationController _pulseController;
  late Animation<double> _fadeAnimation;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    
    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    
    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );
    
    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeInOut,
    ));
    
    _pulseAnimation = Tween<double>(
      begin: 0.8,
      end: 1.1,
    ).animate(CurvedAnimation(
      parent: _pulseController,
      curve: Curves.easeInOut,
    ));
    
    // Démarrer les animations
    _fadeController.forward();
    _pulseController.repeat(reverse: true);
  }

  @override
  void dispose() {
    _fadeController.dispose();
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.adaptiveBackground,
      body: AnimatedBuilder(
        animation: _fadeAnimation,
        builder: (context, child) {
          return Opacity(
            opacity: _fadeAnimation.value,
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Logo ou animation avec pulse
                  AnimatedBuilder(
                    animation: _pulseAnimation,
                    builder: (context, child) {
                      return Transform.scale(
                        scale: _pulseAnimation.value,
                        child: SizedBox(
                          width: 120,
                          height: 120,
                          child: ClipRRect(
                            borderRadius: BorderRadiusGeometry.circular(25.0),
                            child: Image.asset(
                              'assets/img/icon.png',
                              fit: BoxFit.contain,
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                  
                  32.h,
                  
                  // Texte de chargement
                  Text(
                    'Trailix',
                    style: context.bodyLarge?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: context.adaptiveTextPrimary,
                    ),
                  ),
                  
                  24.h,
                  
                  // Message de statut avec gestion réseau
                  BlocBuilder<ConnectivityCubit, ConnectionStatus>(
                    builder: (context, connectionStatus) {
                      String statusText = 'Connexion en cours...';
                      Color statusColor = context.adaptiveTextPrimary.withValues(alpha: 0.7);
                      
                      if (connectionStatus == ConnectionStatus.offline) {
                        statusText = 'Réseau faible, veuillez patienter...';
                        statusColor = Colors.red.withValues(alpha: 0.8);
                      } else if (connectionStatus == ConnectionStatus.onlineWifi || 
                                 connectionStatus == ConnectionStatus.onlineMobile) {
                        statusText = 'Récupération des données...';
                        statusColor = context.adaptivePrimary.withValues(alpha: 0.8);
                      }
                      
                      return Text(
                        statusText,
                        style: context.bodyMedium?.copyWith(
                          color: statusColor,
                        ),
                        textAlign: TextAlign.center,
                      );
                    },
                  ),
                  
                  16.h,
                  
                  // Indicateur de chargement
                  SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(
                        context.adaptivePrimary.withValues(alpha: 0.6),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}