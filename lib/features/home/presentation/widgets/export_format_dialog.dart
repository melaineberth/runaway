import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:runaway/config/extensions.dart';
import 'package:runaway/core/widgets/squircle_container.dart';
import 'package:runaway/features/route_generator/data/services/route_export_service.dart';

class ExportFormatDialog extends StatelessWidget {
  final VoidCallback onGpxSelected;
  final VoidCallback onKmlSelected;
  final VoidCallback onJsonSelected;

  const ExportFormatDialog({
    super.key,
    required this.onGpxSelected,
    required this.onKmlSelected,
    required this.onJsonSelected,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(30.0),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Exporter le parcours',
            style: context.bodyMedium?.copyWith(
              color: Colors.white,
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Choisissez le format d\'export :',
                style: context.bodySmall?.copyWith(
                  color: Colors.white38,
                ),
              ),
              SizedBox(height: 20),
          
              ...RouteExportFormat.values.map(
                (format) => _buildFormatOption(context, format, () {
                  Navigator.of(context).pop();
                  switch (format) {
                    case RouteExportFormat.gpx:
                      onGpxSelected();
                      break;
                    case RouteExportFormat.kml:
                      onKmlSelected();
                      break;
                    case RouteExportFormat.json:
                      onJsonSelected();
                      break;
                  }
                }),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildFormatOption(
    BuildContext context,
    RouteExportFormat format,
    VoidCallback onTap,
  ) {
    IconData icon;
    Color color;

    switch (format) {
      case RouteExportFormat.gpx:
        icon = HugeIcons.strokeRoundedGps01;
        color = Colors.green;
        break;
      case RouteExportFormat.kml:
        icon = HugeIcons.strokeRoundedEarth;
        color = Colors.blue;
        break;
      case RouteExportFormat.json:
        icon = HugeIcons.strokeRoundedFileScript;
        color = Colors.orange;
        break;
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0),
      child: SquircleContainer(
        radius: 40,
        color: Colors.white10,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Container(
            padding: EdgeInsets.all(16),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                SquircleContainer(
                  padding: EdgeInsets.all(8),
                  radius: 18,
                  color: color.withValues(alpha: 0.1),
                  child: Icon(icon, color: color, size: 30),
                ),
                SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        format.displayName,
                        style: context.bodyMedium?.copyWith(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      SizedBox(height: 4),
                      Text(
                        format.description,
                        style: context.bodySmall?.copyWith(
                          fontSize: 14,
                          color: Colors.white38,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(
                  HugeIcons.strokeRoundedArrowRight01,
                  color: Colors.grey[400],
                  size: 20,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
