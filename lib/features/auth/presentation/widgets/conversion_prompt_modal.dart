import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:runaway/core/helper/extensions/extensions.dart';
import 'package:runaway/core/helper/services/conversion_service.dart';
import 'package:runaway/core/utils/constant/constants.dart';
import 'package:runaway/core/widgets/modal_sheet.dart';
import 'package:runaway/core/widgets/squircle_btn.dart';
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
      end: 1.1,
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
        'title': context.l10n.saveRoutesTitle,
        'subtitle': context.l10n.saveRoutesSubtitle,
      },
      {
        'icon': HugeIcons.solidRoundedTarget03,
        'title': context.l10n.customGoalsTitle,
        'subtitle': context.l10n.customGoalsSubtitle,
      },
      {
        'icon': HugeIcons.solidRoundedDownloadCircle01,
        'title': context.l10n.exportRouteTitle,
        'subtitle': context.l10n.exportRoutesSubtitle,
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
          child: SquircleBtn(
            isPrimary: true,
            label: context.l10n.createFreeAccount,
            onTap: () {
              showSignModal(context, 0);
            },
          ),
        ),
        
        10.h,
        
        // Bouton secondaire - Se connecter
        SizedBox(
          width: double.infinity,
          child: SquircleBtn(
            backgroundColor: Colors.transparent,
            onTap: () {
              showSignModal(context, 1);
            },
            label: context.l10n.alreadyHaveAnAccount,
          ),
        ),
      ],
    );
  }
    
  String _getContextualTitle() {
    switch (widget.context) {
      case 'route_generated':
        return context.l10n.conversionTitleRouteGenerated;
      case 'activity_viewed':
        return context.l10n.conversionTitleActivityViewed;
      case 'multiple_routes':
        return context.l10n.conversionTitleMultipleRoutes;
      case 'manual_test':
        return context.l10n.conversionTitleManualTest;
      default:
        return context.l10n.conversionTitleDefault;
    }
  }
  
  String _getContextualSubtitle() {
    switch (widget.context) {
      case 'route_generated':
        return context.l10n.conversionSubtitleRouteGenerated;
      case 'activity_viewed':
        return context.l10n.conversionSubtitleActivityViewed;
      case 'multiple_routes':
        return context.l10n.conversionSubtitleMultipleRoutes;
      case 'manual_test':
        return context.l10n.conversionSubtitleManualTest;
      default:
        return context.l10n.conversionSubtitleDefault;
    }
  }
}