import 'package:flutter/material.dart';
import 'package:runaway/config/extensions.dart';
import 'package:runaway/core/widgets/particles_spark.dart';
import 'package:runaway/core/widgets/particles_spark_loader.dart';

class LoadingOverlay extends StatefulWidget {
  const LoadingOverlay({super.key});

  @override
  State<LoadingOverlay> createState() => _LoadingOverlayState();
}

class _LoadingOverlayState extends State<LoadingOverlay> {
  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.black.withValues(alpha: 0.9),
      height: double.infinity,
      width: double.infinity,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: Stack(
          alignment: Alignment.center,
          children: [
            Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                SizedBox(
                  width: 40,
                  height: 40,
                  child: StepRotatingShape(
                    size: 25,
                    rotationDuration: const Duration(milliseconds: 600), // Duration of each 45° rotation
                    pauseDuration: const Duration(milliseconds: 300), // Pause duration between rotations
                    color: Color(0xFF8157E8),
                  ),
                ),
                16.h,
                Text(
                  'Génération en cours..',
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.white,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
            Positioned.fill(
              child: ParticlesSpark(
                quantity: 20,
                maxSize: 8,
                minSize: 5,
              ),
            ),
          ],
        ),
      ),
    );
  }
}