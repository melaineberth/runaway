import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:runaway/core/helper/extensions/extensions.dart';
import 'package:runaway/core/widgets/modal_sheet.dart';
import 'package:runaway/core/widgets/squircle_btn.dart';
import 'package:runaway/core/widgets/squircle_container.dart';
import 'package:hugeicons/hugeicons.dart';

class WelcomeModal extends StatefulWidget {
  final VoidCallback onStartTutorial;
  final VoidCallback onSkip;

  const WelcomeModal({
    super.key,
    required this.onStartTutorial,
    required this.onSkip,
  });

  @override
  State<WelcomeModal> createState() => _WelcomeModalState();
}

class _WelcomeModalState extends State<WelcomeModal> with TickerProviderStateMixin {
  late AnimationController _slideController;
  late AnimationController _pulseController;
  late Animation<Offset> _slideAnimation;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _initializeAnimations();    
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
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // App icon/logo
            AnimatedBuilder(
              animation: _pulseAnimation,
              builder: (context, child) {
                return Transform.scale(
                  scale: _pulseAnimation.value,
                  child: SquircleContainer(     
                    isGlow: true, 
                    radius: 50.0,     
                    height: 100,   
                    width: 100,   
                    color: context.adaptivePrimary,
                    child: Image.asset(
                      "assets/img/icon.png",
                      fit: BoxFit.contain,
                    ),
                  ),
                );
              },
            ),
            
            20.h,
            
            // Title
            Text(
              context.l10n.welcomeTitle,
              style: context.headlineMedium?.copyWith(
                fontWeight: FontWeight.bold,
                fontSize: 25,
              ),
              textAlign: TextAlign.center,
            ),
            
            12.h,
            
            // Description
            Text(
              context.l10n.welcomeDesc,
              style: GoogleFonts.inter(
                color: context.adaptiveTextSecondary,
                fontWeight: FontWeight.w500,
                fontSize: 16,
              ),
              textAlign: TextAlign.center,
            ),
            
            30.h,
            
            // Benefits list
            _buildBenefit(
              context,
              HugeIcons.solidRoundedRoute01,
              context.l10n.benefitsGenerationTitle,
              context.l10n.benefitsGenerationDesc,
            ),
            
            12.h,
            
            _buildBenefit(
              context,
              HugeIcons.solidRoundedPinLocation03,
              context.l10n.benefitsLocationTitle,
              context.l10n.benefitsLocationDesc,
            ),
            
            12.h,
            
            _buildBenefit(
              context,
              HugeIcons.solidRoundedFavourite,
              context.l10n.benefitsSavingTitle,
              context.l10n.benefitsSavingDesc,
            ),
            
            40.h,
            
            // Action buttons
            Column(
              children: [
                SquircleBtn(
                  isPrimary: true,
                  label: context.l10n.onStartTutorial,
                  onTap: widget.onStartTutorial,
                ),
                
                10.h,
        
                SquircleBtn(
                  isGradient: false,
                  label: context.l10n.skipTutorial,
                  onTap: widget.onSkip,
                ),
                
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBenefit(
    BuildContext context,
    IconData icon,
    String title,
    String subtitle,
  ) {
    return SquircleContainer(
      radius: 50.0,
      gradient: false,
      padding: EdgeInsets.all(8.0),
      color: context.adaptiveDisabled.withValues(alpha: 0.05),
      child: Row(
        children: [
          SquircleContainer(
            radius: 30.0,
            gradient: false,
            isGlow: true,
            padding: EdgeInsets.all(15.0),
            color: context.adaptivePrimary,
            child: Icon(
              icon,
              color: Colors.white,
            ),
          ),
                  
          15.w,
          
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: context.bodySmall?.copyWith(
                    fontWeight: FontWeight.w600,
                    fontSize: 15,
                  ),
                ),
                Text(
                  subtitle,
                  style: GoogleFonts.inter(
                    color: context.adaptiveTextSecondary,
                    fontWeight: FontWeight.w500,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}