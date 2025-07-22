import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:runaway/core/helper/extensions/extensions.dart';
import 'package:runaway/core/widgets/top_snackbar.dart';
import 'package:share_plus/share_plus.dart';
import 'package:path/path.dart' as p;   // pour basename
import 'package:intl/intl.dart';
import 'package:top_snackbar_flutter/top_snack_bar.dart';

class RouteExportService {
  
  /// Exporte la route dans le format choisi
  static Future<void> exportRoute({
    required BuildContext context,          // 🆕
    required List<List<double>> coordinates,
    required Map<String, dynamic> metadata,
    required RouteExportFormat format,
    String? customName,
  }) async {
    try {
      final routeName = customName ?? _generateRouteName(metadata);
      final content = _generateContent(context, coordinates, metadata, format, routeName);
      final fileName = '$routeName.${format.extension}';
      
      await _saveAndShareFile(context, content, fileName, format);
      
    } catch (e) {
      if (context.mounted) {
        throw RouteExportException(context.l10n.routeExportError(e.toString()));
      }
    }
  }

  /// Génère le contenu du fichier selon le format
  static String _generateContent(
    BuildContext context,
    List<List<double>> coordinates,
    Map<String, dynamic> metadata,
    RouteExportFormat format,
    String routeName,
  ) {
    switch (format) {
      case RouteExportFormat.gpx:
        return _generateGPX(context, coordinates, metadata, routeName);
      case RouteExportFormat.kml:
        return _generateKML(context, coordinates, metadata, routeName);
    }
  }

  /// Génère un fichier GPX (GPS Exchange Format)
  static String _generateGPX(
    BuildContext context,
    List<List<double>> coordinates,
    Map<String, dynamic> metadata,
    String routeName,
  ) {
    final now = DateTime.now();
    final dateFormat = DateFormat("yyyy-MM-ddTHH:mm:ssZ");
    final distanceKm = metadata['distanceKm'] ?? 0;
    final activityType = metadata['parameters']?['activity_type'] ?? 'unknown';
    
    final buffer = StringBuffer();
    
    // En-tête GPX
    buffer.writeln('<?xml version="1.0" encoding="UTF-8"?>');
    buffer.writeln('<gpx version="1.1" creator="Runaway App" xmlns="http://www.topografix.com/GPX/1/1">');
    
    // Métadonnées
    buffer.writeln('  <metadata>');
    buffer.writeln('    <name>$routeName</name>');
    buffer.writeln('    <desc>${context.l10n.routeDescription(activityType, distanceKm.toStringAsFixed(1))}</desc>');
    buffer.writeln('    <time>${dateFormat.format(now)}</time>');
    buffer.writeln('  </metadata>');
    
    // Route (pour la navigation)
    buffer.writeln('  <rte>');
    buffer.writeln('    <name>$routeName</name>');
    buffer.writeln('    <desc>${context.l10n.routeDistanceLabel(distanceKm.toStringAsFixed(1))}</desc>');
    
    for (int i = 0; i < coordinates.length; i++) {
      final coord = coordinates[i];
      final lon = coord[0];
      final lat = coord[1];
      final ele = coord.length > 2 ? coord[2] : 0;
      
      buffer.writeln('    <rtept lat="$lat" lon="$lon">');
      if (ele > 0) buffer.writeln('      <ele>$ele</ele>');
      buffer.writeln('      <name>Point ${i + 1}</name>');
      buffer.writeln('    </rtept>');
    }
    
    buffer.writeln('  </rte>');
    
    // Track (pour l'enregistrement)
    buffer.writeln('  <trk>');
    buffer.writeln('    <name>$routeName Track</name>');
    buffer.writeln('    <type>$activityType</type>');
    buffer.writeln('    <trkseg>');
    
    for (final coord in coordinates) {
      final lon = coord[0];
      final lat = coord[1];
      final ele = coord.length > 2 ? coord[2] : 0;
      
      buffer.writeln('      <trkpt lat="$lat" lon="$lon">');
      if (ele > 0) buffer.writeln('        <ele>$ele</ele>');
      buffer.writeln('      </trkpt>');
    }
    
    buffer.writeln('    </trkseg>');
    buffer.writeln('  </trk>');
    buffer.writeln('</gpx>');
    
    return buffer.toString();
  }

  /// Génère un fichier KML (Google Earth/Maps)
  static String _generateKML(
    BuildContext context,
    List<List<double>> coordinates,
    Map<String, dynamic> metadata,
    String routeName,
  ) {
    final distanceKm = metadata['distanceKm'] ?? 0;
    final activityType = metadata['parameters']?['activity_type'] ?? 'unknown';
    
    final buffer = StringBuffer();
    
    // En-tête KML
    buffer.writeln('<?xml version="1.0" encoding="UTF-8"?>');
    buffer.writeln('<kml xmlns="http://www.opengis.net/kml/2.2">');
    buffer.writeln('  <Document>');
    buffer.writeln('    <name>$routeName</name>');
    buffer.writeln('    <description>${context.l10n.routeDescription(activityType, distanceKm.toStringAsFixed(1))}</description>');
    
    // Style de la ligne
    buffer.writeln('    <Style id="routeStyle">');
    buffer.writeln('      <LineStyle>');
    buffer.writeln('        <color>ff0066ff</color>'); // Rouge en ABGR
    buffer.writeln('        <width>4</width>');
    buffer.writeln('      </LineStyle>');
    buffer.writeln('    </Style>');
    
    // Placemark pour la route
    buffer.writeln('    <Placemark>');
    buffer.writeln('      <name>$routeName</name>');
    buffer.writeln('      <description>${context.l10n.routeDistanceLabel(distanceKm.toStringAsFixed(1))}</description>');
    buffer.writeln('      <styleUrl>#routeStyle</styleUrl>');
    buffer.writeln('      <LineString>');
    buffer.writeln('        <tessellate>1</tessellate>');
    buffer.writeln('        <coordinates>');
    
    // Coordonnées (lon,lat,alt)
    for (final coord in coordinates) {
      final lon = coord[0];
      final lat = coord[1];
      final ele = coord.length > 2 ? coord[2] : 0;
      buffer.writeln('          $lon,$lat,$ele');
    }
    
    buffer.writeln('        </coordinates>');
    buffer.writeln('      </LineString>');
    buffer.writeln('    </Placemark>');
    
    // Points de départ et fin
    if (coordinates.isNotEmpty) {
      final start = coordinates.first;
      final end = coordinates.last;
      
      // Point de départ
      buffer.writeln('    <Placemark>');
      buffer.writeln('      <name>${context.l10n.start}</name>');
      buffer.writeln('      <Point>');
      buffer.writeln('        <coordinates>${start[0]},${start[1]},${start.length > 2 ? start[2] : 0}</coordinates>');
      buffer.writeln('      </Point>');
      buffer.writeln('    </Placemark>');
      
      // Point d'arrivée (si différent)
      if (coordinates.length > 1 && (start[0] != end[0] || start[1] != end[1])) {
        buffer.writeln('    <Placemark>');
        buffer.writeln('      <name>${context.l10n.endPoint}</name>');
        buffer.writeln('      <Point>');
        buffer.writeln('        <coordinates>${end[0]},${end[1]},${end.length > 2 ? end[2] : 0}</coordinates>');
        buffer.writeln('      </Point>');
        buffer.writeln('    </Placemark>');
      }
    }
    
    buffer.writeln('  </Document>');
    buffer.writeln('</kml>');
    
    return buffer.toString();
  }

  /// Génère un nom de fichier basé sur les métadonnées
  static String _generateRouteName(Map<String, dynamic> metadata) {
    final now = DateTime.now();
    final dateFormat = DateFormat('yyyyMMdd_HHmm');
    final distanceKm = metadata['distanceKm'] ?? 0;
    final activityType = metadata['parameters']?['activity_type'] ?? 'route';
    
    return '${activityType}_${distanceKm.toStringAsFixed(0)}km_${dateFormat.format(now)}';
  }

  /// Sauvegarde et partage le fichier
  static Future<void> _saveAndShareFile(
    BuildContext context,
    String content,
    String fileName,
    RouteExportFormat format,
  ) async {
    final dir = await getTemporaryDirectory();
    final path = p.join(dir.path, fileName);
    await File(path).writeAsString(content, encoding: utf8);

    if (context.mounted) {
      final box = context.findRenderObject() as RenderBox?;
      
      final origin = box != null
        ? box.localToGlobal(Offset.zero) & box.size
        : const Rect.fromLTWH(0, 0, 1, 1); // fallback

      // 3. Partage
      final params = ShareParams(
        text: context.l10n.routeExportedFrom,
        files: [XFile(path, mimeType: _mimeFromFormat(format))], 
        sharePositionOrigin: origin
      );
      
      final result = await SharePlus.instance.share(params);

      if (result.status == ShareResultStatus.success) {
        if (context.mounted) {
          showTopSnackBar(
            Overlay.of(context),
            TopSnackBar(
              title: context.l10n.formatRouteExport(format.displayName),
            ),
          );
        }
      }
    }
  }

  /// Petit helper pour donner un MIME type cohérent
  static String _mimeFromFormat(RouteExportFormat format) {
    switch (format) {
      case RouteExportFormat.gpx:
        return 'application/gpx+xml';
      case RouteExportFormat.kml:
        return 'application/vnd.google-earth.kml+xml';
    }
  }
}

/// Formats d'export disponibles
enum RouteExportFormat {
  gpx('gpx', 'Fichier GPS (GPX)', 'À importer dans Garmin, Strava…'),
  kml('kml', 'Google Maps / Earth (KML)', 'Pour visualiser le parcours en 2D / 3D');

  const RouteExportFormat(this.extension, this.displayName, this.description);
  
  final String extension;
  final String displayName;
  final String description;
}

/// Exception d'export
class RouteExportException implements Exception {
  final String message;
  const RouteExportException(this.message);
  
  @override
  String toString() => 'RouteExportException: $message';
}
