import 'package:flutter/material.dart';
import 'package:runaway/config/extensions.dart';
import 'package:runaway/core/widgets/squircle_container.dart';

class ShimmerHistoricCard extends StatefulWidget {
  const ShimmerHistoricCard({super.key});

  @override
  State<ShimmerHistoricCard> createState() => _ShimmerHistoricCardState();
}

class _ShimmerHistoricCardState extends State<ShimmerHistoricCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );
    _animation = Tween<double>(begin: -1.0, end: 2.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );
    _animationController.repeat();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const innerRadius = 30.0;
    const double paddingValue = 15.0;
    const padding = EdgeInsets.all(paddingValue);
    final outerRadius = padding.calculateOuterRadius(innerRadius);

    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        return IntrinsicHeight(
          child: SquircleContainer(
            radius: outerRadius,
            padding: padding,
            color: Colors.white10,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // 🖼️ Image placeholder
                SizedBox(
                  height: 250,
                  child: SquircleContainer(
                    radius: innerRadius,
                    color: Colors.grey[800],
                    padding: EdgeInsets.zero,
                    child: _buildShimmerContainer(
                      width: double.infinity,
                      height: 250,
                    ),
                  ),
                ),
                paddingValue.h,
                
                // Zone texte et bouton
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Titre et informations
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Titre placeholder
                            _buildShimmerContainer(
                              width: 300,
                              height: 24,
                              borderRadius: BorderRadius.circular(4),
                            ),
                            4.h,
                            
                            // Sous-titre placeholder  
                            _buildShimmerContainer(
                              width: 200,
                              height: 16,
                              borderRadius: BorderRadius.circular(4),
                            ),
                            15.h,
                            
                            // Chips placeholder
                            Wrap(
                              spacing: 8.0,
                              runSpacing: 8.0,
                              children: [
                                _buildShimmerChip(width: 90),
                                _buildShimmerChip(width: 90),
                                _buildShimmerChip(width: 80),
                                _buildShimmerChip(width: 80),
                                _buildShimmerChip(width: 80),
                                _buildShimmerChip(width: 90),
                              ],
                            ),
                          ],
                        ),
                      ),
                      paddingValue.h,
                      
                      // Boutons placeholder
                      Row(
                        children: [
                          // Bouton principal placeholder
                          Expanded(
                            child: SquircleContainer(
                              radius: 20.0,
                              child: _buildShimmerContainer(
                                width: double.infinity,
                                height: 50,
                              ),
                            ),
                          ),
                          12.w,
                          
                          // Bouton supprimer placeholder
                          SquircleContainer(
                            radius: 20.0,
                            child: _buildShimmerContainer(
                              width: 50,
                              height: 50,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  /// Construit un container avec effet shimmer
  Widget _buildShimmerContainer({
    required double width,
    required double height,
    BorderRadius? borderRadius,
  }) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        borderRadius: borderRadius,
        gradient: LinearGradient(
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
          stops: [
            (_animation.value - 1.0).clamp(0.0, 1.0),
            _animation.value.clamp(0.0, 1.0),
            (_animation.value + 1.0).clamp(0.0, 1.0),
          ],
          colors: [
            Colors.grey[800]!,
            Colors.grey[700]!,
            Colors.grey[800]!,
          ],
        ),
      ),
    );
  }

  /// Construit un chip shimmer
  Widget _buildShimmerChip({required double width}) {
    return _buildShimmerContainer(
      width: width,
      height: 40,
      borderRadius: BorderRadius.circular(100),
    );
  }
}