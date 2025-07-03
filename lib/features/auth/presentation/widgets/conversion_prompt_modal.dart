// Fichier : lib/features/auth/presentation/widgets/conversion_prompt_modal.dart

import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:runaway/config/extensions.dart';
import 'package:runaway/core/services/conversion_service.dart';
import 'package:runaway/core/widgets/squircle_container.dart';
import 'package:runaway/features/auth/presentation/screens/login_screen.dart';
import 'package:runaway/features/auth/presentation/screens/signup_screen.dart';
import 'package:runaway/core/widgets/modal_sheet.dart';

class ConversionPromptModal extends StatefulWidget {
  final String? context; // Pour personnaliser le message selon le contexte
  
  const ConversionPromptModal({
    super.key,
    this.context,
  });

  @override
  State<ConversionPromptModal> createState() => _ConversionPromptModalState();
}

class _ConversionPromptModalState extends State<ConversionPromptModal>
    with TickerProviderStateMixin {
  late AnimationController _slideController;
  late AnimationController _pulseController;
  late Animation<Offset> _slideAnimation;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _initializeAnimations();
    
    // Enregistrer que le prompt a été affiché
    ConversionService.instance.recordPromptShown();
  }

  void _initializeAnimations() {
    _slideController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );
    
    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 2000),
      vsync: this,
    );

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 1),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _slideController,
      curve: Curves.easeOutBack,
    ));

    _pulseAnimation = Tween<double>(
      begin: 1.0,
      end: 1.05,
    ).animate(CurvedAnimation(
      parent: _pulseController,
      curve: Curves.easeInOut,
    ));

    _slideController.forward();
    _pulseController.repeat(reverse: true);
  }

  @override
  void dispose() {
    _slideController.dispose();
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SlideTransition(
      position: _slideAnimation,
      child: Container(
        decoration: BoxDecoration(
          color: context.adaptiveBackground,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.2),
              blurRadius: 20,
              offset: const Offset(0, -5),
            ),
          ],
        ),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Handle bar
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: context.adaptiveTextSecondary.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              
              24.h,
              
              // Icône animée et header
              _buildHeader(),
              
              24.h,
              
              // Contenu principal
              _buildContent(),
              
              32.h,
              
              // Boutons d'action
              _buildActionButtons(),
              
              16.h,
              
              // Bouton "Plus tard"
              _buildLaterButton(),
              
              // Espacement pour la safe area
              MediaQuery.of(context).padding.bottom > 0 
                  ? (MediaQuery.of(context).padding.bottom / 2).h
                  : 8.h,
            ],
          ),
        ),
      ),
    );
  }
  
  Widget _buildHeader() {
    return Column(
      children: [
        // Icône principale avec animation
        AnimatedBuilder(
          animation: _pulseAnimation,
          builder: (context, child) {
            return Transform.scale(
              scale: _pulseAnimation.value,
              child: Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      context.adaptivePrimary,
                      context.adaptivePrimary.withValues(alpha: 0.7),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: context.adaptivePrimary.withValues(alpha: 0.3),
                      blurRadius: 15,
                      offset: const Offset(0, 5),
                    ),
                  ],
                ),
                child: Icon(
                  HugeIcons.strokeRoundedUserStar01,
                  color: Colors.white,
                  size: 36,
                ),
              ),
            );
          },
        ),
        
        20.h,
        
        // Titre principal
        Text(
          _getContextualTitle(),
          style: context.titleLarge?.copyWith(
            fontWeight: FontWeight.w700,
            fontSize: 24,
          ),
          textAlign: TextAlign.center,
        ),
        
        12.h,
        
        // Sous-titre
        Text(
          _getContextualSubtitle(),
          style: context.bodyMedium?.copyWith(
            color: context.adaptiveTextSecondary,
            height: 1.4,
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }
  
  Widget _buildContent() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: context.adaptiveBorder.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          Text(
            'Avec un compte, débloquez :',
            style: context.bodyMedium?.copyWith(
              fontWeight: FontWeight.w600,
              color: context.adaptiveTextPrimary,
            ),
          ),
          
          16.h,
          
          ..._buildBenefitsList(),
        ],
      ),
    );
  }
  
  List<Widget> _buildBenefitsList() {
    final benefits = [
      {
        'icon': HugeIcons.strokeRoundedBookmark01,
        'title': 'Sauvegarde de vos parcours',
        'subtitle': 'Retrouvez vos routes favorites à tout moment',
      },
      {
        'icon': HugeIcons.strokeRoundedTarget03,
        'title': 'Objectifs personnalisés',
        'subtitle': 'Suivez vos progrès et atteignez vos buts',
      },
      {
        'icon': HugeIcons.strokeRoundedAnalytics01,
        'title': 'Statistiques détaillées',
        'subtitle': 'Analysez vos performances au fil du temps',
      },
      {
        'icon': HugeIcons.strokeRoundedAnalytics01,
        'title': 'Synchronisation multi-appareils',
        'subtitle': 'Accédez à vos données partout',
      },
    ];
    
    return benefits.asMap().entries.map((entry) {
      final index = entry.key;
      final benefit = entry.value;
      
      return Container(
        margin: EdgeInsets.only(bottom: index < benefits.length - 1 ? 12 : 0),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: context.adaptivePrimary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                benefit['icon'] as IconData,
                color: context.adaptivePrimary,
                size: 18,
              ),
            ),
            
            12.w,
            
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    benefit['title'] as String,
                    style: context.bodySmall?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Text(
                    benefit['subtitle'] as String,
                    style: context.bodySmall?.copyWith(
                      color: context.adaptiveTextSecondary,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }).toList();
  }
  
  Widget _buildActionButtons() {
    return Column(
      children: [
        // Bouton principal - Créer un compte
        SizedBox(
          width: double.infinity,
          child: SquircleContainer(
            onTap: () {
              Navigator.of(context).pop();
              _showAuthModal(const SignupScreen());
            },
            height: 56,
            color: context.adaptivePrimary,
            radius: 16,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  HugeIcons.strokeRoundedUserAdd01,
                  color: Colors.white,
                  size: 20,
                ),
                8.w,
                Text(
                  'Créer un compte gratuit',
                  style: context.bodyMedium?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ),
        
        12.h,
        
        // Bouton secondaire - Se connecter
        SizedBox(
          width: double.infinity,
          child: SquircleContainer(
            onTap: () {
              Navigator.of(context).pop();
              _showAuthModal(const LoginScreen());
            },
            height: 48,
            color: Colors.transparent,
            radius: 16,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  HugeIcons.strokeRoundedLogin01,
                  color: context.adaptivePrimary,
                  size: 18,
                ),
                8.w,
                Text(
                  'J\'ai déjà un compte',
                  style: context.bodyMedium?.copyWith(
                    color: context.adaptivePrimary,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
  
  Widget _buildLaterButton() {
    return TextButton(
      onPressed: () {
        // Enregistrer que l'utilisateur a refusé
        ConversionService.instance.recordUserDeclined();
        Navigator.of(context).pop();
      },
      child: Text(
        'Plus tard',
        style: context.bodySmall?.copyWith(
          color: context.adaptiveTextSecondary,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }
  
  void _showAuthModal(Widget screen) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => screen,
    );
  }
  
  String _getContextualTitle() {
    switch (widget.context) {
      case 'route_generated':
        return 'Super parcours ! 🎉';
      case 'activity_viewed':
        return 'Motivé(e) par vos stats ! 📊';
      case 'multiple_routes':
        return 'Vous adorez explorer ! 🗺️';
      default:
        return 'Prêt(e) pour la suite ? 🚀';
    }
  }
  
  String _getContextualSubtitle() {
    switch (widget.context) {
      case 'route_generated':
        return 'Sauvegardez ce parcours et bien plus encore avec un compte gratuit.';
      case 'activity_viewed':
        return 'Créez un compte pour suivre vos progrès et définir des objectifs.';
      case 'multiple_routes':
        return 'Sauvegardez tous vos parcours favoris et suivez vos performances.';
      default:
        return 'Créez votre compte gratuit pour débloquer toutes les fonctionnalités.';
    }
  }
}