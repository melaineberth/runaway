import 'dart:convert';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:path/path.dart' as p;   // pour basename
import 'package:intl/intl.dart';

class RouteExportService {
  
  /// Exporte la route dans le format choisi
  static Future<void> exportRoute({
    required List<List<double>> coordinates,
    required Map<String, dynamic> metadata,
    required RouteExportFormat format,
    String? customName,
  }) async {
    try {
      final routeName = customName ?? _generateRouteName(metadata);
      final content = _generateContent(coordinates, metadata, format, routeName);
      final fileName = '$routeName.${format.extension}';
      
      await _saveAndShareFile(content, fileName, format);
      
    } catch (e) {
      throw RouteExportException('Erreur lors de l\'export: $e');
    }
  }

  /// Génère le contenu du fichier selon le format
  static String _generateContent(
    List<List<double>> coordinates,
    Map<String, dynamic> metadata,
    RouteExportFormat format,
    String routeName,
  ) {
    switch (format) {
      case RouteExportFormat.gpx:
        return _generateGPX(coordinates, metadata, routeName);
      case RouteExportFormat.kml:
        return _generateKML(coordinates, metadata, routeName);
      case RouteExportFormat.json:
        return _generateJSON(coordinates, metadata, routeName);
    }
  }

  /// Génère un fichier GPX (GPS Exchange Format)
  static String _generateGPX(
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
    buffer.writeln('    <desc>Parcours ${activityType} de ${distanceKm.toStringAsFixed(1)}km généré par Runaway</desc>');
    buffer.writeln('    <time>${dateFormat.format(now)}</time>');
    buffer.writeln('  </metadata>');
    
    // Route (pour la navigation)
    buffer.writeln('  <rte>');
    buffer.writeln('    <name>$routeName</name>');
    buffer.writeln('    <desc>Route de ${distanceKm.toStringAsFixed(1)}km</desc>');
    
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
    buffer.writeln('    <description>Parcours ${activityType} de ${distanceKm.toStringAsFixed(1)}km</description>');
    
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
    buffer.writeln('      <description>Distance: ${distanceKm.toStringAsFixed(1)}km</description>');
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
      buffer.writeln('      <name>Départ</name>');
      buffer.writeln('      <Point>');
      buffer.writeln('        <coordinates>${start[0]},${start[1]},${start.length > 2 ? start[2] : 0}</coordinates>');
      buffer.writeln('      </Point>');
      buffer.writeln('    </Placemark>');
      
      // Point d'arrivée (si différent)
      if (coordinates.length > 1 && (start[0] != end[0] || start[1] != end[1])) {
        buffer.writeln('    <Placemark>');
        buffer.writeln('      <name>Arrivée</name>');
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

  /// Génère un fichier JSON
  static String _generateJSON(
    List<List<double>> coordinates,
    Map<String, dynamic> metadata,
    String routeName,
  ) {
    final data = {
      'name': routeName,
      'type': 'Feature',
      'properties': {
        'name': routeName,
        'description': 'Parcours généré par Runaway',
        'distance_km': metadata['distanceKm'],
        'duration_minutes': metadata['durationMinutes'],
        'elevation_gain': metadata['elevationGain'],
        'activity_type': metadata['parameters']?['activity_type'],
        'is_loop': metadata['is_loop'],
        'generated_at': metadata['generatedAt'],
        'points_count': coordinates.length,
      },
      'geometry': {
        'type': 'LineString',
        'coordinates': coordinates,
      },
    };
    
    return const JsonEncoder.withIndent('  ').convert(data);
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
    String content,
    String fileName,
    RouteExportFormat format,
  ) async {
    // 1. Dossier temporaire
    final dir = await getTemporaryDirectory();
    final filePath = p.join(dir.path, fileName);

    // 2. Écriture du fichier
    final file = File(filePath);
    await file.writeAsString(content, encoding: utf8);

    // 3. Partage
    final params = ShareParams(
      text: 'Parcours exporté depuis Runaway',
      files: [XFile(filePath, mimeType: _mimeFromFormat(format))], 
    );
    
    final result = await SharePlus.instance.share(params);

    if (result.status == ShareResultStatus.success) {
        print('Thank you for sharing the picture!');
    }
  }

  /// Petit helper pour donner un MIME type cohérent
  static String _mimeFromFormat(RouteExportFormat format) {
    switch (format) {
      case RouteExportFormat.gpx:
        return 'application/gpx+xml';
      case RouteExportFormat.kml:
        return 'application/vnd.google-earth.kml+xml';
      case RouteExportFormat.json:
        return 'application/json';
    }
  }
}

/// Formats d'export disponibles
enum RouteExportFormat {
  gpx('gpx', 'GPX', 'Format standard GPS (Garmin, Strava, Komoot)'),
  kml('kml', 'KML', 'Google Earth / Google Maps'),
  json('json', 'JSON', 'Format universel de données');

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
