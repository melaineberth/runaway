import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';
import '../../../../core/helper/extensions/extensions.dart';
import '../../../../core/widgets/squircle_container.dart';
import '../../domain/models/activity_stats.dart';

class RecordsSection extends StatelessWidget {
  final List<PersonalRecord> records;

  const RecordsSection({
    super.key,
    required this.records,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          context.l10n.personalRecords,
          style: context.bodyMedium?.copyWith(
            fontSize: 18,
            color: context.adaptiveTextSecondary,
            fontWeight: FontWeight.w600,
          ),
        ),
        15.h,
        SquircleContainer(
          radius: 50.0,
          padding: const EdgeInsets.all(10),
          color: context.adaptiveBorder.withValues(alpha: 0.05),
          child: Column(
            children: [
              if (records.isEmpty)
                _buildEmptyState(context)
              else
                ...records.map((record) => _buildRecordCard(record)),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildRecordCard(PersonalRecord record) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white10,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.amber.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              _getRecordIcon(record.type),
              color: Colors.amber,
              size: 20,
            ),
          ),
          12.w,
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  record.type.label,
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                4.h,
                Row(
                  children: [
                    Icon(
                      record.activityType.icon,
                      size: 14,
                      color: Colors.white60,
                    ),
                    4.w,
                    Text(
                      '${record.routeName} • ${record.achievedAt.day}/${record.achievedAt.month}/${record.achievedAt.year}',
                      style: TextStyle(
                        color: Colors.white60,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                record.value.toStringAsFixed(record.unit == 'km/h' ? 1 : 0),
                style: TextStyle(
                  color: Colors.amber,
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                ),
              ),
              Text(
                record.unit,
                style: TextStyle(
                  color: Colors.white60,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(20.0),
      child: Column(
        children: [
          Icon(
            HugeIcons.strokeRoundedRoute01,
            size: 48,
            color: context.adaptiveDisabled,
          ),
          8.h,
          Text(
            context.l10n.empryPersonalRecords,
            style: context.bodySmall?.copyWith(
              color: context.adaptiveDisabled,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  IconData _getRecordIcon(RecordType type) {
    switch (type) {
      case RecordType.longestDistance:
        return HugeIcons.strokeRoundedRoute01;
      case RecordType.fastestSpeed:
        return HugeIcons.strokeRoundedRoute01;
      case RecordType.highestElevation:
        return HugeIcons.strokeRoundedRoute01;
      case RecordType.longestDuration:
        return HugeIcons.strokeRoundedTime01;
    }
  }
}