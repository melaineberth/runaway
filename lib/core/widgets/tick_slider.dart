import 'package:animated_flip_counter/animated_flip_counter.dart';
import 'package:flutter/material.dart';
import 'package:flutter/physics.dart';
import 'package:flutter/services.dart';
import 'package:runaway/config/extensions.dart';
import 'package:runaway/core/widgets/squircle_container.dart';

/// ✅ NOUVEAU : Enum pour l'intensité haptique
enum HapticIntensity {
  light,   // HapticFeedback.lightImpact()
  medium,  // HapticFeedback.mediumImpact()  
  heavy,   // HapticFeedback.heavyImpact()
  custom   // Mix intelligent selon vitesse
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

  // ✅ NOUVEAU : Configuration haptique
  final bool enableHapticFeedback;
  final HapticIntensity hapticIntensity;

  const TickSlider({
    super.key,
    required this.min,
    required this.max,
    required this.initialValue,
    required this.onChanged,
    required this.unit,
    this.stretch = .80,        // 8 % par défaut
    this.minorTickCount = 48,
    this.majorEvery = 6,
    this.majorTickColor = Colors.grey,
    this.minorTickColor = const Color(0xFF555555),
    this.enableHapticFeedback = true, // ✅ Activé par défaut
    this.hapticIntensity = HapticIntensity.medium,
  });

  @override
  State<TickSlider> createState() => _TickSliderState();
}

/*────────────────────────────────────────────────────────────*/
class _TickSliderState extends State<TickSlider> with TickerProviderStateMixin {
  static const _trackH  = 46.0;
  static const _radius  = 30.0;

  late double _value;                   // valeur effective
  double _overscroll = 0;               // zone de stretch (signée)
  double _trackW = 0;                   // largeur de la piste (Layout)

  // ✅ NOUVEAU : Variables pour le feedback haptique
  int _currentTick = 0;              // Cran actuel
  DateTime _lastHapticTime = DateTime.now();
  double _lastPosition = 0;          // Position précédente pour calcul vitesse
  DateTime _lastMoveTime = DateTime.now();
  final List<double> _velocityHistory = [];  // Historique des vitesses
  bool _isDragging = false;

  late final AnimationController _spring =
      AnimationController.unbounded(vsync: this)
        ..addListener(() => setState(() => _overscroll = _spring.value));

  double get _maxStretchPx =>
      widget.stretch <= 1 ? _trackW * widget.stretch : widget.stretch;

  @override
  void initState() {
    super.initState();
    _value = widget.initialValue.clamp(widget.min, widget.max);
    _currentTick = _valueToTick(_value);
  }

  @override
  void dispose() {
    _spring.dispose();
    super.dispose();
  }

/*──────────────── helpers ────────────────*/
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
    
    // ✅ Limiter la fréquence selon la vitesse
    final minInterval = _getMinHapticInterval(velocity);
    if (now.difference(_lastHapticTime).inMilliseconds < minInterval) {
      return;
    }
    
    _lastHapticTime = now;
    
    // ✅ Choisir le type de feedback selon l'intensité configurée et la vitesse
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
      return 80;  // Moyen : max 12.5 haptics/sec
    } else if (velocity < 500) {
      return 50;  // Rapide : max 20 haptics/sec
    } else {
      return 30;  // Très rapide : max 33 haptics/sec
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

    // ✅ Calculer la vitesse pour le feedback haptique
    final velocity = _calculateVelocity(x);

    if (x >= 0 && x <= _trackW) {
      _overscroll = 0;
      final p = x / _trackW;
      final v = widget.min + (widget.max - widget.min) * p;

      // ✅ NOUVEAU : Détection des changements de cran
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
    
    // ✅ Feedback haptique de début de drag
    if (widget.enableHapticFeedback) {
      HapticFeedback.selectionClick();
    }
  }

  void _endDrag() {
    _isDragging = false;
    _velocityHistory.clear();
    
    // ✅ Feedback haptique de fin de drag si overscroll
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


/*──────────────── build ─────────────*/
  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        /* pill valeur */
        SquircleContainer(
          radius: _radius,
          width: 90,
          height: _trackH,
          color: context.adaptivePrimary,
          isGlow: true,
          gradient: false,
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
                _startDrag(); // ✅ NOUVEAU
                _updateDrag(d.localPosition);
              },
              onHorizontalDragStart: (d) {
                _startDrag(); // ✅ NOUVEAU  
                _updateDrag(d.localPosition);
              },
              onHorizontalDragUpdate:(d) => _updateDrag(d.localPosition),
              onHorizontalDragEnd:   (_)  => _endDrag(),
              onHorizontalDragCancel:     _endDrag,
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

