import 'dart:ui';

import 'package:animated_flip_counter/animated_flip_counter.dart';
import 'package:flutter/material.dart';
import 'package:flutter/physics.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:runaway/core/helper/extensions/extensions.dart';
import 'package:runaway/core/widgets/squircle_container.dart';
import 'package:runaway/core/widgets/top_snackbar.dart';
import 'package:top_snackbar_flutter/top_snack_bar.dart';

/// Enum pour l'intensité haptique
enum HapticIntensity {
  light, // HapticFeedback.lightImpact()
  medium, // HapticFeedback.mediumImpact()  
  heavy, // HapticFeedback.heavyImpact()
  custom // Mix intelligent selon vitesse
}

/// Slider squircle avec graduations + **stretch élastique façon iOS**.
class TickSlider extends StatefulWidget {
  final double min, max, initialValue;
  final String unit;
  final ValueChanged<double> onChanged;

  /// `stretch` ≤ 1 → pourcentage de la largeur ;  > 1 → pixels.
  final double stretch;

  // graduations
  final int minorTickCount, majorEvery;
  final Color majorTickColor, minorTickColor;

  // Configuration haptique
  final bool enableHapticFeedback;
  final HapticIntensity hapticIntensity;

  const TickSlider({
    super.key,
    required this.min,
    required this.max,
    required this.initialValue,
    required this.onChanged,
    required this.unit,
    this.stretch = .80, // 8 % par défaut
    this.minorTickCount = 48,
    this.majorEvery = 6,
    this.majorTickColor = Colors.grey,
    this.minorTickColor = const Color(0xFF555555),
    this.enableHapticFeedback = true, // Activé par défaut
    this.hapticIntensity = HapticIntensity.medium,
  });

  @override
  State<TickSlider> createState() => _TickSliderState();
}

class _TickSliderState extends State<TickSlider> with TickerProviderStateMixin {
  static const _trackH  = 46.0;
  static const _radius  = 30.0;

  late double _value; // valeur effective
  double _overscroll = 0; // zone de stretch (signée)
  double _trackW = 0; // largeur de la piste (Layout)

  // Variables pour le feedback haptique
  int _currentTick = 0; // Cran actuel
  DateTime _lastHapticTime = DateTime.now();
  double _lastPosition = 0; // Position précédente pour calcul vitesse
  DateTime _lastMoveTime = DateTime.now();
  final List<double> _velocityHistory = []; // Historique des vitesses
  bool _isDragging = false;

  late final AnimationController _spring;

  double get _maxStretchPx => widget.stretch <= 1 ? _trackW * widget.stretch : widget.stretch;

  @override
  void initState() {
    super.initState();
    _value = widget.initialValue.clamp(widget.min, widget.max);
    _currentTick = _valueToTick(_value);

    // Initialiser dans initState au lieu de la déclaration
    _spring = AnimationController.unbounded(vsync: this)
      ..addListener(() {
        if (mounted) {
          setState(() => _overscroll = _spring.value);
        }
      });
  }

  @override
  void dispose() {
    _spring.dispose();
    super.dispose();
  }

  /// Convertit une valeur en numéro de cran
  int _valueToTick(double value) {
    final normalizedValue = (value - widget.min) / (widget.max - widget.min);
    return (normalizedValue * widget.minorTickCount).round();
  }

  /// Calcule la vitesse de déplacement (pixels/seconde)
  double _calculateVelocity(double currentPosition) {
    final now = DateTime.now();
    final deltaTime = now.difference(_lastMoveTime).inMicroseconds / 1000000.0;
    final deltaPosition = (currentPosition - _lastPosition).abs();
    
    if (deltaTime > 0) {
      final velocity = deltaPosition / deltaTime;
      
      // Garder un historique des 5 dernières vitesses pour lisser
      _velocityHistory.add(velocity);
      if (_velocityHistory.length > 5) {
        _velocityHistory.removeAt(0);
      }
      
      _lastPosition = currentPosition;
      _lastMoveTime = now;
      
      // Retourner la vitesse moyennée
      return _velocityHistory.reduce((a, b) => a + b) / _velocityHistory.length;
    }
    
    return 0;
  }

  /// Déclenche le feedback haptique intelligent
  void _triggerHapticFeedback(double velocity) {
    if (!widget.enableHapticFeedback) return;
    
    final now = DateTime.now();
    
    // Limiter la fréquence selon la vitesse
    final minInterval = _getMinHapticInterval(velocity);
    if (now.difference(_lastHapticTime).inMilliseconds < minInterval) {
      return;
    }
    
    _lastHapticTime = now;
    
    // Choisir le type de feedback selon l'intensité configurée et la vitesse
    switch (widget.hapticIntensity) {
      case HapticIntensity.light:
        HapticFeedback.lightImpact();
        break;
      case HapticIntensity.medium:
        HapticFeedback.mediumImpact();
        break;
      case HapticIntensity.heavy:
        HapticFeedback.heavyImpact();
        break;
      case HapticIntensity.custom:
        _triggerAdaptiveHaptic(velocity);
        break;
    }
  }

  /// Feedback haptique adaptatif selon la vitesse
  void _triggerAdaptiveHaptic(double velocity) {
    if (velocity < 50) {
      // Mouvement lent : feedback léger
      HapticFeedback.lightImpact();
    } else if (velocity < 200) {
      // Mouvement moyen : feedback medium
      HapticFeedback.mediumImpact();
    } else {
      // Mouvement rapide : feedback lourd
      HapticFeedback.heavyImpact();
    }
  }

  /// Calcule l'intervalle minimum entre haptics selon la vitesse
  int _getMinHapticInterval(double velocity) {
    if (velocity < 50) {
      return 150; // Lent : max 6.7 haptics/sec
    } else if (velocity < 200) {
      return 80; // Moyen : max 12.5 haptics/sec
    } else if (velocity < 500) {
      return 50; // Rapide : max 20 haptics/sec
    } else {
      return 30; // Très rapide : max 33 haptics/sec
    }
  }

  /// courbe « rubber-band » (même formule qu’iOS UIKit)
  double _rubberBand(double x, double limit) {
    final absX = x.abs();
    final res = limit * (1 - (1 / ((absX * .35 / limit) + 1))); // .35 au lieu de .55
    return x.isNegative ? -res : res;
  }

/*──────────────── drag logic ─────────────*/
  void _updateDrag(Offset pos) {
    final x = pos.dx;

    // Calculer la vitesse pour le feedback haptique
    final velocity = _calculateVelocity(x);

    if (x >= 0 && x <= _trackW) {
      _overscroll = 0;
      final p = x / _trackW;
      final v = widget.min + (widget.max - widget.min) * p;

      // Détection des changements de cran
      final newTick = _valueToTick(v);
      if (_isDragging && newTick != _currentTick) {
        _currentTick = newTick;
        _triggerHapticFeedback(velocity);
      }

      setState(() => _value = v);
      widget.onChanged(v);
    } else {
      final raw = x < 0 ? x : x - _trackW;
      _overscroll = _rubberBand(raw, _maxStretchPx);
      setState(() {});
    }
  }

  void _startDrag() {
    _isDragging = true;
    _lastMoveTime = DateTime.now();
    _velocityHistory.clear();
    
    // Feedback haptique de début de drag
    if (widget.enableHapticFeedback) {
      HapticFeedback.selectionClick();
    }
  }

  void _endDrag() {
    _isDragging = false;
    _velocityHistory.clear();
    
    // Feedback haptique de fin de drag si overscroll
    if (_overscroll != 0 && widget.enableHapticFeedback) {
      HapticFeedback.lightImpact();
    }
    
    if (_overscroll == 0) return;
    _spring
      ..stop()
      ..value = _overscroll;
    const spring = SpringDescription(
      mass: 0.7, stiffness: 250, damping: 20,
    );
    _spring.animateWith(SpringSimulation(spring, _overscroll, 0, 0));
  }

  void _openModificator(BuildContext context) async {
    final result = await Navigator.of(context, rootNavigator: true).push(
      PageRouteBuilder(
        opaque: false,
        barrierColor: Colors.transparent,
        transitionDuration: const Duration(milliseconds: 200),
        reverseTransitionDuration: const Duration(milliseconds: 200),

        pageBuilder: (_, Animation<double> animation, __) {
          return _OverleyView(
            unit: widget.unit,
            minValue: widget.min,
            maxValue: widget.max,
            initialValue: _value.toStringAsFixed(0),
            animation: animation,
            onTap: () {
              context.pop();
            },
          );
        },
      ),
    );

    if (result != null && mounted) {
      final clamped = result.clamp(widget.min, widget.max);
      setState(() {
        _value = clamped;
        _currentTick = _valueToTick(_value);
      });
      widget.onChanged(_value);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        SquircleContainer(
          radius: _radius,
          width: 90,
          height: _trackH,
          color: context.adaptivePrimary,
          isGlow: true,
          gradient: false,
          onTap: () => _openModificator(context),
          child: Center(
            child: AnimatedFlipCounter(
              duration: Duration(milliseconds: 500),
              suffix: " ${widget.unit}",
              value: _value, // pass in a value like 2014
              textStyle: context.bodySmall?.copyWith(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: Colors.white,
              ),
            ),
          ),
        ),
        12.w,

        /* piste */
        Expanded(
          child: LayoutBuilder(builder: (ctx, cst) {
            _trackW = cst.maxWidth;
            /* remplissage corrigé */
            final p = (_value - widget.min) / (widget.max - widget.min);
            final baseFill = (_trackW * p).clamp(8.0, _trackW);
            final stretch = _overscroll.abs();

            // Ajuster le remplissage selon le type de stretch
            double fillWidth;
            double fillLeftShift = 0;

            if (_overscroll < 0) {
              // Stretch vers la gauche (minimum) : réduire progressivement le remplissage vers zéro
              final stretchRatio = (stretch / _maxStretchPx).clamp(0.0, 1.0);
              fillWidth = baseFill * (1 - stretchRatio);
            } else {
              // Pas de stretch ou stretch vers la droite : garder le remplissage normal
              fillWidth = baseFill;
            }

            final anchor = _overscroll >= 0
                ? Alignment.centerLeft
                : Alignment.centerRight;
            final scaleFactor = 1 + (stretch / _maxStretchPx) * .25; // .25 au lieu de .10;

            return GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTapDown: (d) {
                _startDrag();
                _updateDrag(d.localPosition);
              },
              onHorizontalDragStart: (d) {
                _startDrag();  
                _updateDrag(d.localPosition);
              },
              onHorizontalDragUpdate:(d) => _updateDrag(d.localPosition),
              onHorizontalDragEnd:   (_)  => _endDrag(),
              onHorizontalDragCancel: _endDrag,
              child: Transform(
                alignment: anchor,
                transform: Matrix4.diagonal3Values(scaleFactor, 1, 1),
                child: Stack(children: [
                  /* fond */
                  SquircleContainer(
                    radius: _radius,
                    height: _trackH,
                    gradient: false,
                    color: context.adaptiveDisabled.withValues(alpha: .09),
                  ),

                  /* graduations clippées */
                  ClipPath(
                    clipper: ShapeBorderClipper(
                      shape: ContinuousRectangleBorder(
                        borderRadius: BorderRadius.circular(_radius),
                      ),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 8.0),
                      child: CustomPaint(
                        size: Size(_trackW, _trackH),
                        painter: _RulerPainter(
                          divisions: widget.minorTickCount,
                          majorEvery: widget.majorEvery,
                          majorColor: widget.majorTickColor,
                          minorColor: widget.minorTickColor,
                        ),
                      ),
                    ),
                  ),

                  /* remplissage */
                  Positioned(
                    left: fillLeftShift,
                    top: 0,
                    bottom: 0,
                    child: ClipPath(
                      clipper: ShapeBorderClipper(
                        shape: ContinuousRectangleBorder(
                          borderRadius: BorderRadius.circular(_radius),
                        ),
                      ),
                      child: SquircleContainer(
                        radius: _radius,
                        width: fillWidth.clamp(0.0, _trackW - fillLeftShift.abs()),
                        height: _trackH,
                        gradient: false,
                        color: context.adaptivePrimary,
                      ),
                    ),
                  ),
                ]),
              ),
            );
          }),
        ),
      ],
    );
  }
}

/*──────────────── graduations ─────────────*/
class _RulerPainter extends CustomPainter {
  final int divisions, majorEvery;
  final Color majorColor, minorColor;

  const _RulerPainter({
    required this.divisions,
    required this.majorEvery,
    required this.majorColor,
    required this.minorColor,
  });

  @override
  void paint(Canvas c, Size s) {
    final big = s.height * .50, small = s.height * .25;
    final step = s.width / divisions;

    final bigPaint   = Paint()
      ..color = majorColor
      ..strokeWidth = 1.6
      ..strokeCap = StrokeCap.round;
    final smallPaint = Paint()
      ..color = minorColor
      ..strokeWidth = 1.1
      ..strokeCap = StrokeCap.round;

    for (int i = 0; i <= divisions; i++) {
      final x = i * step;
      final isMajor = i % majorEvery == 0;
      final len = isMajor ? big : small;
      c.drawLine(
        Offset(x, s.height / 2 - len / 2),
        Offset(x, s.height / 2 + len / 2),
        isMajor ? bigPaint : smallPaint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _RulerPainter old) =>
      old.divisions   != divisions ||
      old.majorEvery  != majorEvery ||
      old.majorColor  != majorColor ||
      old.minorColor  != minorColor;
}

class _OverleyView extends StatefulWidget {
  final String initialValue;
  final String unit;
  final double maxValue, minValue;
  final Animation<double> animation;
  final VoidCallback onTap;

  const _OverleyView({
    required this.unit, 
    required this.initialValue, 
    required this.minValue, 
    required this.maxValue, 
    required this.animation,
    required this.onTap,
  });

  @override
  State<_OverleyView> createState() => __OverleyViewState();
}

class __OverleyViewState extends State<_OverleyView> with TickerProviderStateMixin {
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

    // Écouteur : synchronise le champ _value si tu veux
    _ctl.addListener(() {
      setState(() {
        _value = _ctl.text;
      });
    });
  }

  @override
  void dispose() {
    _ctl.dispose();
    super.dispose();
  }

  String? _validateInput(String? value) {
    if (value == null || value.trim().isEmpty) {
      return context.l10n.requiredField;
    }
    final parsed = double.tryParse(value.trim().replaceAll(',', '.'));
    if (parsed == null) {
      return context.l10n.enterValidNumber;
    }
    if (parsed <= widget.minValue) {
      return context.l10n.greaterValue(widget.minValue.toStringAsFixed(0));
    }
    if (parsed > widget.maxValue) {
      return context.l10n.lessValue(widget.maxValue.toStringAsFixed(0));
    }
    return null;
  }

  void _handleSubmit() {
    final errorMessage = _validateInput(_ctl.text);
    if (errorMessage == null) {
      setState(() {
        _showError = false;
      });
      final value = double.parse(_ctl.text.trim().replaceAll(',', '.'));
      Navigator.of(context).pop(value);
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
        // sigma passe de 0 à 30
        final sigma = 30 * widget.animation.value;
        // opacité du voile passe de 0 à 0.25
        final veilOpacity = 0.6 * widget.animation.value;

        return Scaffold(
          extendBody: true,
          backgroundColor: Colors.transparent,
          body: Stack(
            alignment: Alignment.bottomCenter,
            children: [
              // fond flouté / assombri
              Positioned.fill(
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque, // capte toute la surface
                  onTap: _handleSubmit,
                  child: FadeTransition(
                    opacity: widget.animation,
                    child: BackdropFilter(
                      filter: ImageFilter.blur(sigmaX: sigma, sigmaY: sigma),
                      child: Container(
                        color: context.adaptiveTextPrimary.withValues(
                          alpha: veilOpacity,
                        ),
                      ),
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
                          keyboardType: TextInputType.number,
                          textAlign: TextAlign.center,
                          style: context.bodyLarge?.copyWith(
                            fontSize: 60,
                            fontWeight: FontWeight.w700,
                            color: _showError ? Colors.red : context.adaptiveBackground,
                          ),
                          cursorColor: _showError ? Colors.red : context.adaptivePrimary,
                          decoration: InputDecoration(
                            border: InputBorder.none,
                            hintText: widget.unit,
                            hintStyle: context.bodyLarge?.copyWith(
                              fontSize: 60,
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
