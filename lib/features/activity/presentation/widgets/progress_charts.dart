import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:runaway/config/colors.dart';
import 'package:runaway/core/widgets/squircle_container.dart';
import 'package:runaway/features/activity/data/repositories/activity_repository.dart';
import '../../../../config/extensions.dart';
import '../../domain/models/activity_stats.dart';

class ProgressChartsSection extends StatefulWidget {
  final List<PeriodStats> periodStats;
  final PeriodType currentPeriod;
  final Function(PeriodType) onPeriodChanged;

  const ProgressChartsSection({
    super.key,
    required this.periodStats,
    required this.currentPeriod,
    required this.onPeriodChanged,
  });

  @override
  State<ProgressChartsSection> createState() => _ProgressChartsSectionState();
}

class _ProgressChartsSectionState extends State<ProgressChartsSection> {
  ChartType _selectedChart = ChartType.distance;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Progression',
              style: context.bodyMedium?.copyWith(color: Colors.white, fontWeight: FontWeight.w700),
            ),
            _buildPeriodSelector(),
          ],
        ),
        15.h,
        SquircleContainer(
          radius: 40.0,
          color: Colors.white10,
          child: Column(
            children: [
              16.h,
              _buildChartTypeSelector(),
              20.h,
              if (widget.periodStats.isEmpty)
                _buildEmptyState()
              else
                SizedBox(
                  height: 200,
                  child: _buildChart(),
                ),
            ],
          ),
        )
      ],
    );
  }

  Widget _buildPeriodSelector() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white10,
        borderRadius: BorderRadius.circular(100),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildPeriodOption(PeriodType.weekly, 'Semaine'),
          _buildPeriodOption(PeriodType.monthly, 'Mois'),
        ],
      ),
    );
  }

  Widget _buildPeriodOption(PeriodType period, String label) {
    final isSelected = widget.currentPeriod == period;
    
    return GestureDetector(
      onTap: () => widget.onPeriodChanged(period),
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 15.0, vertical: 8.0),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primary : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
    );
  }

  Widget _buildChartTypeSelector() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: ChartType.values.map((type) {
          final isSelected = _selectedChart == type;
          
          return GestureDetector(
            onTap: () => setState(() => _selectedChart = type),
            child: Container(
              margin: const EdgeInsets.only(left: 12),
              padding: EdgeInsets.symmetric(horizontal: 15.0, vertical: 8.0),
              decoration: BoxDecoration(
                color: isSelected ? Colors.white30 : Colors.white10,
                borderRadius: BorderRadius.circular(100),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    _getChartIcon(type),
                    color: Colors.white,
                    size: 18,
                  ),
                  8.w,
                  Text(
                    type.label,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildChart() {
    final data = _getChartData();
    
    if (data.isEmpty) {
      return _buildEmptyState();
    }

    return Padding(
      padding: const EdgeInsets.all(12.0),
      child: LineChart(
        LineChartData(
          gridData: FlGridData(
            show: true,
            drawVerticalLine: false,
            horizontalInterval: _getHorizontalInterval(),
            getDrawingHorizontalLine: (value) {
              return FlLine(
                color: Colors.white24,
                strokeWidth: 1,
              );
            },
          ),
          titlesData: FlTitlesData(
            show: true,
            rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
            topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 30,
                interval: 1,
                getTitlesWidget: (value, meta) {
                  final index = value.toInt();
                  if (index < 0 || index >= data.length) return Container();
                  
                  final date = widget.periodStats[index].period;
                  final label = widget.currentPeriod == PeriodType.weekly
                      ? '${date.day}/${date.month}'
                      : '${date.month}/${date.year}';
                  
                  return SideTitleWidget(
                    meta: meta,
                    child: Text(
                      label,
                      style: TextStyle(
                        color: Colors.white60,
                        fontSize: 10,
                      ),
                    ),
                  );
                },
              ),
            ),
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                interval: _getHorizontalInterval(),
                reservedSize: 40,
                getTitlesWidget: (value, meta) {
                  return SideTitleWidget(
                    meta: meta,
                    child: Text(
                      _formatValue(value),
                      style: TextStyle(
                        color: Colors.white60,
                        fontSize: 10,
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
          borderData: FlBorderData(show: false),
          minX: 0,
          maxX: data.length.toDouble() - 1,
          minY: 0,
          maxY: data.isNotEmpty ? data.map((e) => e.y).reduce((a, b) => a > b ? a : b) * 1.1 : 1,
          lineBarsData: [
            LineChartBarData(
              spots: data,
              isCurved: true,
              gradient: LinearGradient(
                colors: [
                  AppColors.primary,
                  AppColors.primary.withValues(alpha: 0.3),
                ],
              ),
              barWidth: 3,
              isStrokeCapRound: true,
              dotData: FlDotData(
                show: true,
                getDotPainter: (spot, percent, barData, index) {
                  return FlDotCirclePainter(
                    radius: 4,
                    color: AppColors.primary,
                    strokeWidth: 2,
                    strokeColor: Colors.white,
                  );
                },
              ),
              belowBarData: BarAreaData(
                show: true,
                gradient: LinearGradient(
                  colors: [
                    AppColors.primary.withValues(alpha: 0.2),
                    AppColors.primary.withValues(alpha: 0.05),
                  ],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            HugeIcons.strokeRoundedChartLineData02,
            size: 48,
            color: Colors.white30,
          ),
          8.h,
          Text(
            'Pas encore de données',
            style: TextStyle(
              color: Colors.white60,
              fontSize: 14,
            ),
          ),
          4.h,
          Text(
            'Complétez des parcours pour voir votre progression',
            style: TextStyle(
              color: Colors.white38,
              fontSize: 12,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  List<FlSpot> _getChartData() {
    return widget.periodStats.asMap().entries.map((entry) {
      final index = entry.key.toDouble();
      final stat = entry.value;
      
      double value;
      switch (_selectedChart) {
        case ChartType.distance:
          value = stat.distanceKm;
          break;
        case ChartType.duration:
          value = stat.durationMinutes.toDouble();
          break;
        case ChartType.elevation:
          value = stat.elevation.toDouble();
          break;
        case ChartType.routes:
          value = stat.routeCount.toDouble();
          break;
      }
      
      return FlSpot(index, value);
    }).toList();
  }

  double _getHorizontalInterval() {
    final data = _getChartData();
    if (data.isEmpty) return 1;
    
    final maxValue = data.map((e) => e.y).reduce((a, b) => a > b ? a : b);
    return maxValue / 5; // 5 lignes horizontales
  }

  String _formatValue(double value) {
    switch (_selectedChart) {
      case ChartType.distance:
        return '${value.toStringAsFixed(0)}km';
      case ChartType.duration:
        return '${value.toStringAsFixed(0)}min';
      case ChartType.elevation:
        return '${value.toStringAsFixed(0)}den';
      case ChartType.routes:
        return value.toStringAsFixed(0);
    }
  }

  IconData _getChartIcon(ChartType type) {
    switch (type) {
      case ChartType.distance:
        return HugeIcons.strokeRoundedRoute01;
      case ChartType.duration:
        return HugeIcons.strokeRoundedTime01;
      case ChartType.elevation:
        return HugeIcons.strokeRoundedMountain;
      case ChartType.routes:
        return HugeIcons.strokeRoundedActivity01;
    }
  }
}

enum ChartType {
  distance('Distance'),
  duration('Durée'),
  elevation('Élevation'),
  routes('Parcours');

  const ChartType(this.label);
  final String label;
}
