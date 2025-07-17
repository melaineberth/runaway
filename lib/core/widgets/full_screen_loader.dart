import 'package:flutter/material.dart';
import 'package:runaway/core/helper/extensions/extensions.dart';
import 'package:runaway/core/widgets/particles_spark.dart';
import 'package:runaway/core/widgets/particles_spark_loader.dart';

class FullScreenLoader extends StatelessWidget {
  final String? message;

  const FullScreenLoader({
    super.key,
    required this.message,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: Container(
        color: Colors.black,
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
                    message ?? context.l10n.currentGeneration,
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
      ),
    );
  }
}
