import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:runaway/core/helper/extensions/extensions.dart';
import 'package:runaway/core/helper/services/conversion_service.dart';
import 'package:runaway/core/widgets/modal_sheet.dart';
import 'package:runaway/core/widgets/squircle_container.dart';

class ConversionPromptModal extends StatefulWidget {
  final String? context; // Pour personnaliser le message selon le contexte
  
  const ConversionPromptModal({
    super.key,
    this.context,
  });

  @override
  State<ConversionPromptModal> createState() => _ConversionPromptModalState();
}

class _ConversionPromptModalState extends State<ConversionPromptModal> with TickerProviderStateMixin {
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
    return ModalSheet(
      child: SlideTransition(
        position: _slideAnimation,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Icône animée et header
              _buildHeader(),
              
              24.h,
              
              // Contenu principal
              _buildContent(),
              
              32.h,
              
              // Boutons d'action
              _buildActionButtons(),
              
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
              child: SquircleContainer(
                width: 80,
                height: 80,
                radius: 50.0,
                isGlow: true,
                color: context.adaptivePrimary,
                child: Icon(
                  HugeIcons.solidRoundedUserStar01,
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
          style: context.bodyLarge?.copyWith(
            fontWeight: FontWeight.w700,
            fontSize: 25,
          ),
          textAlign: TextAlign.center,
        ),
        
        12.h,
        
        // Sous-titre
        Text(
          _getContextualSubtitle(),
          style: context.bodyMedium?.copyWith(
            color: context.adaptiveTextSecondary,
            fontSize: 18,
            height: 1.4,
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }
  
  Widget _buildContent() {
    return Column(
      children: [          
        ..._buildBenefitsList(),
      ],
    );
  }
  
  List<Widget> _buildBenefitsList() {
    final benefits = [
      {
        'icon': HugeIcons.solidRoundedBookmark01,
        'title': 'Sauvegarde de vos parcours',
        'subtitle': 'Retrouvez vos routes favorites à tout moment',
      },
      {
        'icon': HugeIcons.solidRoundedTarget03,
        'title': 'Objectifs personnalisés',
        'subtitle': 'Suivez vos progrès et atteignez vos buts',
      },
      {
        'icon': HugeIcons.solidRoundedAnalytics01,
        'title': 'Statistiques détaillées',
        'subtitle': 'Analysez vos performances au fil du temps',
      },
      {
        'icon': HugeIcons.solidRoundedAnalytics01,
        'title': 'Synchronisation multi-appareils',
        'subtitle': 'Accédez à vos données partout',
      },
    ];
    
    return benefits.asMap().entries.map((entry) {
      final index = entry.key;
      final benefit = entry.value;
      
      return Container(
        margin: EdgeInsets.only(bottom: index < benefits.length - 1 ? 8 : 0),
        child: SquircleContainer(
          radius: 50.0,
          gradient: false,
          padding: EdgeInsets.all(8.0),
          color: context.adaptiveDisabled.withValues(alpha: 0.08),
          child: Row(
            children: [
              SquircleContainer(
                radius: 30.0,
                gradient: false,
                isGlow: true,
                padding: EdgeInsets.all(15.0),
                color: context.adaptivePrimary,
                child: Icon(
                  benefit['icon'] as IconData,
                  color: Colors.white,
                ),
              ),
              
              15.w,
              
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      benefit['title'] as String,
                      style: context.bodySmall?.copyWith(
                        fontWeight: FontWeight.w600,
                        fontSize: 15,
                      ),
                    ),
                    Text(
                      benefit['subtitle'] as String,
                      style: context.bodySmall?.copyWith(
                        color: context.adaptiveTextSecondary,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
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
              // _showAuthModal(const SignupScreen());
            },
            height: 60,
            color: context.adaptivePrimary,
            radius: 40.0,
            child: Center(
              child: Text(
                'Créer un compte gratuit',
                style: context.bodySmall?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ),
        
        10.h,
        
        // Bouton secondaire - Se connecter
        SizedBox(
          width: double.infinity,
          child: SquircleContainer(
            onTap: () {
              Navigator.of(context).pop();
              // _showAuthModal(const LoginScreen());
            },
            height: 60,
            gradient: false,
            color: context.adaptiveDisabled.withValues(alpha: 0),
            radius: 40.0,
            child: Center(
              child: Text(
                'J\'ai déjà un compte',
                style: context.bodySmall?.copyWith(
                  color: context.adaptiveDisabled,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ),
      ],
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