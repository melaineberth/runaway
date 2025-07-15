import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:runaway/config/extensions.dart';
import 'package:runaway/core/widgets/modal_sheet.dart';
import 'package:runaway/core/widgets/squircle_container.dart';
import 'package:runaway/features/route_generator/data/services/route_export_service.dart';

class ExportFormatDialog extends StatelessWidget {
  final VoidCallback onGpxSelected;
  final VoidCallback onKmlSelected;

  const ExportFormatDialog({
    super.key,
    required this.onGpxSelected,
    required this.onKmlSelected,
  });

  @override
  Widget build(BuildContext context) {
    return ModalSheet(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Exporter le parcours',
            style: context.bodySmall?.copyWith(
              color: context.adaptiveTextPrimary,
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Choisissez le format d\'export',
                style: context.bodySmall?.copyWith(
                  color: context.adaptiveTextSecondary,
                  fontSize: 15,
                  fontWeight: FontWeight.w500
                ),
              ),
            
              20.h,
          
              ...RouteExportFormat.values.asMap().entries.map(
                (entry) {
                  final i = entry.key;
                  final format = entry.value;
      
                  return Padding(
                    padding: EdgeInsets.only(
                      bottom: i == RouteExportFormat.values.length - 1 ? 0 : 10,
                    ),
                    child: _buildFormatOption(
                      context, 
                      format: format, 
                      onTap: () {
                      Navigator.of(context).pop();
                        switch (format) {
                          case RouteExportFormat.gpx:
                            onGpxSelected();
                            break;
                          case RouteExportFormat.kml:
                            onKmlSelected();
                            break;
                        }
                      },
                    ),
                  );
                },
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildFormatOption(BuildContext context, {required RouteExportFormat format, required VoidCallback onTap}) {
    IconData icon;

    switch (format) {
      case RouteExportFormat.gpx:
        icon = HugeIcons.strokeRoundedGps01;
        break;
      case RouteExportFormat.kml:
        icon = HugeIcons.strokeRoundedEarth;
        break;
    }

    return SquircleContainer(
      onTap: onTap,
      radius: 50,
      gradient: false,
      color: context.adaptiveBorder.withValues(alpha: 0.08),
      padding: const EdgeInsets.all(8),
      child: Row(
        children: [
          SquircleContainer(
            radius: 30,
            isGlow: true,
            color: context.adaptivePrimary,
            padding: const EdgeInsets.all(15),
            child: Icon(
              icon, 
              color: Colors.white, 
              size: 25,
            ),
          ),
          10.w,
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
                Text(
                  format.description,
                  style: context.bodySmall?.copyWith(
                    fontSize: 14,
                    color: context.adaptiveTextSecondary,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(right: 8.0),
            child: Icon(
              HugeIcons.strokeRoundedArrowRight01,
              color: context.adaptiveTextPrimary,
              size: 20,
            ),
          ),
        ],
      ),
    );
  }
}
