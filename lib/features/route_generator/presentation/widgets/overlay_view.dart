import 'dart:ui';

import 'package:blur/blur.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:runaway/core/helper/extensions/extensions.dart';
import 'package:runaway/core/widgets/top_snackbar.dart';
import 'package:top_snackbar_flutter/top_snack_bar.dart';

class OverleyView extends StatefulWidget {
  final String initialValue;
  final String unit;
  final double? maxValue, minValue;
  final Animation<double> animation;
  final VoidCallback onTap;
  final bool isNumber;
  
  // 🆕 Nouveaux paramètres pour le mode texte
  final int? maxLength; // Pour limiter la longueur du texte
  final String? Function(String?)? validator; // Validateur personnalisé
  final TextCapitalization textCapitalization;

  const OverleyView({
    super.key, 
    required this.unit, 
    required this.initialValue, 
    this.minValue = 0.0, 
    this.maxValue = 1.0, 
    required this.animation,
    required this.onTap,
    this.isNumber = true,
    // 🆕 Paramètres pour le mode texte
    this.maxLength,
    this.validator,
    this.textCapitalization = TextCapitalization.none,
  });

  @override
  State<OverleyView> createState() => _OverleyViewState();
}

class _OverleyViewState extends State<OverleyView> with TickerProviderStateMixin {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  late final TextEditingController _ctl;
  late String _value;

  bool _showError = false;

  late final AnimationController _bounceController;
  late final Animation<double> _bounceAnimation;

  @override
  void initState() {
    super.initState();
    _value = widget.initialValue;
    _ctl = TextEditingController(text: widget.initialValue);

    _bounceController = AnimationController(
      duration: const Duration(milliseconds: 200),
      vsync: this,
    );
    
    _bounceAnimation = Tween<double>(
      begin: 0.0,
      end: 10.0,
    ).animate(CurvedAnimation(
      parent: _bounceController,
      curve: Curves.elasticOut,
    ));

    _ctl.addListener(() {
      setState(() {
        _value = _ctl.text;
      });
    });
  }

  @override
  void dispose() {
    _bounceController.dispose();
    _ctl.dispose();
    super.dispose();
  }

  String? _validateInput(String? value) {
    if (value == null || value.trim().isEmpty) {
      return context.l10n.requiredField;
    }

    // 🆕 Mode texte avec validateur personnalisé
    if (!widget.isNumber) {
      if (widget.validator != null) {
        return widget.validator!(value.trim());
      }
      
      // Validation par défaut pour le texte
      if (widget.maxLength != null && value.trim().length > widget.maxLength!) {
        return context.l10n.routeNameUpdateExceptionCountCharacters;
      }
      
      // Validation des caractères interdits pour les noms de fichiers
      if (value.trim().contains(RegExp(r'[<>:"/\\|?*]'))) {
        return context.l10n.routeNameUpdateExceptionForbiddenCharacters;
      }
      
      if (value.trim().length < 2) {
        return context.l10n.routeNameUpdateExceptionMinCharacters;
      }
      
      return null;
    }

    // 🔄 Mode nombre (logique existante)
    final parsed = double.tryParse(value.trim().replaceAll(',', '.'));
    if (parsed == null) {
      return context.l10n.enterValidNumber;
    }
    if (parsed <= widget.minValue!) {
      return context.l10n.greaterValue(widget.minValue!.toStringAsFixed(0));
    }
    if (parsed > widget.maxValue!) {
      return context.l10n.lessValue(widget.maxValue!.toStringAsFixed(0));
    }
    return null;
  }

  void _handleSubmit() {
    final errorMessage = _validateInput(_ctl.text);
    if (errorMessage == null) {
      setState(() {
        _showError = false;
      });
      
      // 🆕 Retourner le bon type selon le mode
      if (widget.isNumber) {
        final value = double.parse(_ctl.text.trim().replaceAll(',', '.'));
        Navigator.of(context).pop(value);
      } else {
        Navigator.of(context).pop(_ctl.text.trim());
      }
    } else {
      showTopSnackBar(
        Overlay.of(context),
        TopSnackBar(
          isError: true,
          title: errorMessage,
        ),
      );
      setState(() {
        _showError = true;
      });
      _bounceController.forward().then((_) {
        _bounceController.reset();
      });
      HapticFeedback.mediumImpact();
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: widget.animation,
      builder: (context, child) {
        final sigma = 20 * widget.animation.value;
        final veilOpacity = 0.5 * widget.animation.value;

        return Scaffold(
          extendBody: true,
          backgroundColor: Colors.transparent,
          body: Stack(
            clipBehavior: Clip.hardEdge,
            alignment: Alignment.bottomCenter,
            children: [
              Positioned.fill(
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: _handleSubmit,
                  child: FadeTransition(
                    opacity: widget.animation,
                    child: Container(
                      color: context.adaptiveDisabled.withValues(
                        alpha: veilOpacity,
                      ),
                    ).frosted(
                      blur: sigma
                    ),
                  ),
                ),
              ),

              Center(
                child: AnimatedBuilder(
                  animation: _bounceAnimation,
                  builder: (context, child) {
                    return Transform.translate(
                      offset: Offset(_bounceAnimation.value * ((_bounceController.value * 4).round() % 2 == 0 ? 1 : -1), 0),
                      child: Form(
                        key: _formKey,
                        child: TextFormField(
                          controller: _ctl,
                          autofocus: true,
                          keyboardType: widget.isNumber ? TextInputType.number : TextInputType.text,
                          textAlign: TextAlign.center,
                          textCapitalization: widget.textCapitalization,
                          maxLength: widget.maxLength,
                          style: context.bodyLarge?.copyWith(
                            fontSize: widget.isNumber ? 60 : 40, // 🆕 Taille adaptée selon le mode
                            fontWeight: FontWeight.w700,
                            color: _showError ? Colors.red : context.adaptiveBackground,
                          ),
                          cursorColor: _showError ? Colors.red : context.adaptivePrimary,
                          decoration: InputDecoration(
                            border: InputBorder.none,
                            counterText: '', // 🆕 Cache le compteur de caractères
                            hintText: widget.unit,
                            hintStyle: context.bodyLarge?.copyWith(
                              fontSize: widget.isNumber ? 60 : 40,
                              fontWeight: FontWeight.w700,
                              color: context.adaptiveBackground.withValues(alpha: 0.5),
                            ),
                          ),
                          onChanged: (value) {
                            final errorMessage = _validateInput(value);
                            setState(() {
                              _showError = errorMessage != null && _showError;
                            });
                          },
                          onFieldSubmitted: (_) => _handleSubmit(), // 🆕 Support Enter/Done
                        ),
                      ),
                    );
                  }
                ),
              )
            ],
          ),
        );
      },
    );
  }
}