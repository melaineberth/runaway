import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'package:runaway/features/route_generator/domain/models/route_parameters.dart';

// Classe PriorityQueue nécessaire pour A*
class PriorityQueue<T> {
  final List<T> _items = [];
  final Comparator<T> _comparator;

  PriorityQueue(this._comparator);

  void add(T item) {
    _items.add(item);
    _items.sort(_comparator);
  }

  T removeFirst() {
    return _items.removeAt(0);
  }

  bool get isNotEmpty => _items.isNotEmpty;
  bool get isEmpty => _items.isEmpty;
  int get length => _items.length;
}

/// Service pour construire des itinéraires optimaux à partir du réseau GeoJSON
class RouteBuilderService {
  // Graphe représentant le réseau de chemins
  late Graph _networkGraph;
  
  // Features du GeoJSON pour référence
  late List<Map<String, dynamic>> _features;
  
  // POIs disponibles
  late List<Map<String, dynamic>> _pois;

  /// Charge et prépare le réseau depuis un fichier GeoJSON
  Future<void> loadNetwork(File networkFile, List<Map<String, dynamic>> pois) async {
    final jsonString = await networkFile.readAsString();
    final geoJson = json.decode(jsonString);
    
    _features = List<Map<String, dynamic>>.from(geoJson['features'] ?? []);
    _pois = pois;
    
    print('🔧 Construction du graphe avec ${_features.length} segments...');
    _buildGraph();
  }

  /// Construit le graphe à partir des features GeoJSON
  void _buildGraph() {
    _networkGraph = Graph();
    
    // Phase 1: Créer tous les nœuds et arêtes depuis les features
    for (final feature in _features) {
      final coords = feature['geometry']['coordinates'] as List;
      final properties = feature['properties'] as Map<String, dynamic>;
      
      if (coords.length < 2) continue;
      
      // Convertir toutes les coordonnées
      final List<List<double>> edgeCoordinates = [];
      for (final c in coords) {
        final coord = c as List;
        edgeCoordinates.add([
          (coord[0] as num).toDouble(),
          (coord[1] as num).toDouble(),
        ]);
      }
      
      // Créer les nœuds pour tous les points du segment
      Node? previousNode;
      for (int i = 0; i < edgeCoordinates.length; i++) {
        final coord = edgeCoordinates[i];
        final currentNode = _networkGraph.addNode(coord[0], coord[1]);
        
        // Connecter au nœud précédent si ce n'est pas le premier
        if (previousNode != null && i > 0) {
          // Calculer la distance entre les deux points
          final segmentLength = _calculateDistance(
            previousNode.lat, previousNode.lon,
            currentNode.lat, currentNode.lon
          );
          
          // Créer une sous-section du segment
          final subCoords = [
            [previousNode.lon, previousNode.lat],
            [currentNode.lon, currentNode.lat]
          ];
          
          _networkGraph.addEdge(
            previousNode,
            currentNode,
            EdgeData(
              feature: feature,
              length: segmentLength,
              qualityScore: (properties['quality_score'] as int?)?.toDouble() ?? 5.0,
              suitableRunning: properties['suitable_running'] == true,
              suitableCycling: properties['suitable_cycling'] == true,
              isInPark: properties['is_in_park'] == true,
              isInNature: properties['is_in_nature'] == true,
              surface: properties['surface'] as String? ?? 'unknown',
              highway: properties['highway'] as String? ?? 'unknown',
              elevationGain: 0, // Pour les sous-segments
              coordinates: subCoords,
            ),
          );
        }
        
        previousNode = currentNode;
      }
    }
    
    // Phase 2: Connecter les intersections (nœuds proches)
    _connectNearbyNodes();
    
    print('✅ Graphe construit: ${_networkGraph.nodeCount} nœuds, ${_networkGraph.edgeCount} arêtes');
    
    // Statistiques de connectivité
    _printGraphStats();
  }

  /// Connecte les nœuds proches pour créer un réseau navigable
  void _connectNearbyNodes() {
    const double connectionRadius = 20.0; // 20 mètres
    final nodes = _networkGraph._nodes.values.toList();
    int connectionsAdded = 0;
    
    for (int i = 0; i < nodes.length; i++) {
      final node1 = nodes[i];
      
      for (int j = i + 1; j < nodes.length; j++) {
        final node2 = nodes[j];
        
        final distance = _calculateDistance(
          node1.lat, node1.lon,
          node2.lat, node2.lon
        );
        
        if (distance < connectionRadius && distance > 0.1) {
          // Vérifier si une connexion existe déjà
          final existingEdges = _networkGraph.getEdgesFrom(node1);
          final alreadyConnected = existingEdges.any((edge) => edge.to == node2);
          
          if (!alreadyConnected) {
            // Créer une connexion virtuelle
            _networkGraph.addEdge(
              node1,
              node2,
              EdgeData(
                feature: {'type': 'connection'},
                length: distance,
                qualityScore: 3.0, // Score moyen pour les connexions
                suitableRunning: true,
                suitableCycling: true,
                isInPark: false,
                isInNature: false,
                surface: 'connection',
                highway: 'connection',
                elevationGain: 0,
                coordinates: [
                  [node1.lon, node1.lat],
                  [node2.lon, node2.lat]
                ],
              ),
            );
            connectionsAdded++;
          }
        }
      }
    }
    
    print('🔗 ${connectionsAdded} connexions ajoutées entre nœuds proches');
  }

  /// Affiche des statistiques sur le graphe
  void _printGraphStats() {
    final nodes = _networkGraph._nodes.values.toList();
    int isolatedNodes = 0;
    int wellConnectedNodes = 0;
    
    for (final node in nodes) {
      final edges = _networkGraph.getEdgesFrom(node);
      if (edges.isEmpty) {
        isolatedNodes++;
      } else if (edges.length >= 3) {
        wellConnectedNodes++;
      }
    }
    
    print('📊 Statistiques du graphe:');
    print('   - Nœuds isolés: $isolatedNodes');
    print('   - Nœuds bien connectés (3+ arêtes): $wellConnectedNodes');
  }

  /// Génère un itinéraire optimal selon les paramètres
  Future<List<List<double>>> generateRoute(RouteParameters parameters) async {
    print('🚀 Génération d\'itinéraire: ${parameters.distanceKm}km, ${parameters.terrainType.title}, ${parameters.urbanDensity.title}');
    print('📍 Point de départ: ${parameters.startLatitude}, ${parameters.startLongitude}');
    
    // Trouver le nœud de départ le plus proche
    final startNode = _networkGraph.findNearestNode(
      parameters.startLongitude,
      parameters.startLatitude,
    );
    
    if (startNode == null) {
      throw Exception('Aucun point de départ trouvé dans le réseau');
    }
    
    print('✅ Nœud de départ trouvé: ${startNode.lat}, ${startNode.lon}');
    
    // Générer l'itinéraire avec l'algorithme amélioré
    final route = await _generateSmartRoute(startNode, parameters);
    
    if (route.isEmpty) {
      throw Exception('Impossible de générer un itinéraire avec ces paramètres');
    }
    
    print('✅ Itinéraire généré: ${route.length} points, ${_calculateTotalDistance(route).toStringAsFixed(1)}km');
    
    return route;
  }

  /// Génère un itinéraire intelligent en explorant le graphe
  Future<List<List<double>>> _generateSmartRoute(Node start, RouteParameters params) async {
    final targetDistance = params.distanceKm * 1000; // En mètres
    
    // Stratégie : Exploration en étoile avec retour
    if (params.isLoop) {
      return _generateLoopRoute(start, targetDistance, params);
    } else {
      return _generatePointToPointRoute(start, targetDistance, params);
    }
  }

  /// Génère un parcours en boucle
  Future<List<List<double>>> _generateLoopRoute(Node start, double targetDistance, RouteParameters params) async {
    print('🔄 Génération d\'un parcours en boucle de ${targetDistance}m');
    
    // Stratégie : Explorer dans plusieurs directions et revenir
    final List<List<double>> bestRoute = [];
    double bestScore = -1;
    
    // Essayer plusieurs angles de départ
    for (int angle = 0; angle < 360; angle += 45) {
      final route = await _exploreDirection(start, angle.toDouble(), targetDistance, params);
      
      if (route.isNotEmpty) {
        final score = _evaluateRoute(route, targetDistance, params);
        if (score > bestScore) {
          bestScore = score;
          bestRoute.clear();
          bestRoute.addAll(route);
        }
      }
    }
    
    if (bestRoute.isEmpty) {
      // Fallback : utiliser l'ancien algorithme
      return _generateFallbackRoute(start, targetDistance, params);
    }
    
    return bestRoute;
  }

  /// Explore dans une direction donnée
  Future<List<List<double>>> _exploreDirection(
    Node start, 
    double angle, 
    double targetDistance,
    RouteParameters params,
  ) async {
    final List<Node> visitedNodes = [start];
    final Set<Edge> usedEdges = {};
    double currentDistance = 0;
    Node currentNode = start;
    
    // Phase 1: Aller (50% de la distance)
    while (currentDistance < targetDistance * 0.45) {
      final candidates = _networkGraph.getEdgesFrom(currentNode)
          .where((edge) => !usedEdges.contains(edge))
          .where((edge) => _isEdgeSuitable(edge, params))
          .toList();
      
      if (candidates.isEmpty) break;
      
      // Favoriser la direction cible
      candidates.sort((a, b) {
        final angleA = _calculateAngle(currentNode, a.to);
        final angleB = _calculateAngle(currentNode, b.to);
        final diffA = (angleA - angle).abs();
        final diffB = (angleB - angle).abs();
        return diffA.compareTo(diffB);
      });
      
      final selected = candidates.first;
      usedEdges.add(selected);
      visitedNodes.add(selected.to);
      currentDistance += selected.data.length;
      currentNode = selected.to;
    }
    
    // Phase 2: Retour au point de départ
    final returnPath = _findBestPath(currentNode, start, usedEdges, targetDistance * 0.6, params);
    
    if (returnPath == null) {
      return [];
    }
    
    // Construire la route complète
    final List<List<double>> route = [];
    
    // Ajouter le chemin aller
    for (int i = 0; i < visitedNodes.length - 1; i++) {
      final path = _findPath(visitedNodes[i], visitedNodes[i + 1], {});
      if (path != null) {
        route.addAll(path);
      }
    }
    
    // Ajouter le chemin retour
    route.addAll(returnPath);
    
    return _smoothRoute(route);
  }

  /// Calcule l'angle entre deux nœuds
  double _calculateAngle(Node from, Node to) {
    final dx = to.lon - from.lon;
    final dy = to.lat - from.lat;
    return math.atan2(dy, dx) * 180 / math.pi;
  }

  /// Trouve le meilleur chemin entre deux nœuds avec A*
  List<List<double>>? _findBestPath(
    Node from, 
    Node to, 
    Set<Edge> avoidEdges,
    double maxDistance,
    RouteParameters params,
  ) {
    final queue = PriorityQueue<PathState>((a, b) => a.f.compareTo(b.f));
    final visited = <String, double>{};
    
    queue.add(PathState(
      node: from,
      path: [],
      distance: 0,
      heuristic: _calculateDistance(from.lat, from.lon, to.lat, to.lon),
    ));
    
    while (queue.isNotEmpty) {
      final current = queue.removeFirst();
      final nodeKey = '${current.node.lon}_${current.node.lat}';
      
      // Si on a déjà visité ce nœud avec une meilleure distance, ignorer
      if (visited.containsKey(nodeKey) && visited[nodeKey]! <= current.distance) {
        continue;
      }
      visited[nodeKey] = current.distance;
      
      // Si on a atteint la destination
      if (current.node == to) {
        return _extractPathCoordinates(current.path);
      }
      
      // Si on dépasse la distance max
      if (current.distance > maxDistance) {
        continue;
      }
      
      // Explorer les voisins
      for (final edge in _networkGraph.getEdgesFrom(current.node)) {
        if (avoidEdges.contains(edge)) continue;
        if (!_isEdgeSuitable(edge, params)) continue;
        
        final newDistance = current.distance + edge.data.length;
        final newPath = List<Edge>.from(current.path)..add(edge);
        final heuristic = _calculateDistance(
          edge.to.lat, edge.to.lon,
          to.lat, to.lon
        );
        
        queue.add(PathState(
          node: edge.to,
          path: newPath,
          distance: newDistance,
          heuristic: heuristic,
        ));
      }
    }
    
    return null;
  }

  /// Trouve un chemin simple entre deux nœuds
  List<List<double>>? _findPath(Node from, Node to, Set<Edge> avoidEdges) {
    if (from == to) return [[from.lon, from.lat]];
    
    // Recherche BFS simple
    final queue = <PathState>[];
    final visited = <Node>{};
    
    queue.add(PathState(
      node: from,
      path: [],
      distance: 0,
      heuristic: 0,
    ));
    
    while (queue.isNotEmpty) {
      final current = queue.removeAt(0);
      
      if (visited.contains(current.node)) continue;
      visited.add(current.node);
      
      if (current.node == to) {
        return _extractPathCoordinates(current.path);
      }
      
      for (final edge in _networkGraph.getEdgesFrom(current.node)) {
        if (avoidEdges.contains(edge)) continue;
        if (visited.contains(edge.to)) continue;
        
        final newPath = List<Edge>.from(current.path)..add(edge);
        queue.add(PathState(
          node: edge.to,
          path: newPath,
          distance: current.distance + edge.data.length,
          heuristic: 0,
        ));
      }
    }
    
    return null;
  }

  /// Extrait les coordonnées d'un chemin
  List<List<double>> _extractPathCoordinates(List<Edge> path) {
    final List<List<double>> coordinates = [];
    
    for (final edge in path) {
      coordinates.addAll(edge.data.coordinates);
    }
    
    return coordinates;
  }

  /// Lisse la route en supprimant les doublons
  List<List<double>> _smoothRoute(List<List<double>> route) {
    if (route.isEmpty) return route;
    
    final smoothed = <List<double>>[route.first];
    
    for (int i = 1; i < route.length; i++) {
      final prev = smoothed.last;
      final curr = route[i];
      
      // Ignorer les points trop proches
      final dist = _calculateDistance(prev[1], prev[0], curr[1], curr[0]);
      if (dist > 5) { // Au moins 5 mètres
        smoothed.add(curr);
      }
    }
    
    return smoothed;
  }

  /// Évalue la qualité d'une route
  double _evaluateRoute(List<List<double>> route, double targetDistance, RouteParameters params) {
    if (route.isEmpty) return 0;
    
    final actualDistance = _calculateTotalDistance(route) * 1000; // En mètres
    final distanceError = (actualDistance - targetDistance).abs() / targetDistance;
    
    // Pénaliser les routes trop courtes ou trop longues
    double score = 100 * (1 - distanceError);
    
    // Bonus pour les boucles fermées
    final startEnd = _calculateDistance(
      route.first[1], route.first[0],
      route.last[1], route.last[0]
    );
    if (startEnd < 50 && params.isLoop) {
      score += 20;
    }
    
    return score;
  }

  /// Génère un parcours point à point
  Future<List<List<double>>> _generatePointToPointRoute(
    Node start, 
    double targetDistance,
    RouteParameters params,
  ) async {
    // Pour l'instant, utiliser l'algorithme de fallback
    return _generateFallbackRoute(start, targetDistance, params);
  }

  /// Algorithme de fallback (ancien algorithme amélioré)
  List<List<double>> _generateFallbackRoute(Node start, double targetDistance, RouteParameters params) {
    final List<Edge> route = [];
    final Set<Edge> usedEdges = {};
    Node currentNode = start;
    double currentDistance = 0;
    
    print('⚠️ Utilisation de l\'algorithme de fallback');
    
    int attempts = 0;
    const maxAttempts = 1000;
    
    while (currentDistance < targetDistance * 0.9 && attempts < maxAttempts) {
      attempts++;
      
      final candidates = _networkGraph.getEdgesFrom(currentNode)
          .where((edge) => !usedEdges.contains(edge))
          .where((edge) => _isEdgeSuitable(edge, params))
          .toList();
      
      if (candidates.isEmpty) {
        if (route.isNotEmpty) {
          final lastEdge = route.removeLast();
          usedEdges.remove(lastEdge);
          currentDistance -= lastEdge.data.length;
          currentNode = lastEdge.from;
          continue;
        } else {
          break;
        }
      }
      
      // Sélectionner aléatoirement parmi les meilleurs candidats
      candidates.sort((a, b) {
        final scoreA = _scoreEdge(a, params, currentDistance, targetDistance);
        final scoreB = _scoreEdge(b, params, currentDistance, targetDistance);
        return scoreB.compareTo(scoreA);
      });
      
      final topCandidates = candidates.take(3).toList();
      final selected = topCandidates[math.Random().nextInt(topCandidates.length)];
      
      route.add(selected);
      usedEdges.add(selected);
      currentDistance += selected.data.length;
      currentNode = selected.to;
    }
    
    // Essayer de fermer la boucle si nécessaire
    if (params.isLoop && route.isNotEmpty) {
      final returnPath = _findBestPath(
        currentNode, 
        start, 
        usedEdges, 
        targetDistance * 0.3,
        params
      );
      
      if (returnPath != null) {
        final finalRoute = _extractPathCoordinates(route);
        finalRoute.addAll(returnPath);
        return _smoothRoute(finalRoute);
      }
    }
    
    return _smoothRoute(_extractPathCoordinates(route));
  }

  /// Vérifie si une arête convient aux paramètres
  bool _isEdgeSuitable(Edge edge, RouteParameters params) {
    final data = edge.data;
    
    // Toujours accepter les connexions virtuelles
    if (data.highway == 'connection') return true;
    
    // Vérifier l'activité
    if (params.activityType.id == 'running' && !data.suitableRunning) return false;
    if (params.activityType.id == 'cycling' && !data.suitableCycling) return false;
    
    // Vérifier l'urbanisation avec des critères assouplis
    if (params.urbanDensity.id == 'urban') {
      // En urbain, privilégier les routes et chemins aménagés
      if (data.highway == 'track' && data.surface == 'dirt') return false;
    } else if (params.urbanDensity.id == 'nature') {
      // En nature, éviter les grandes routes
      if (data.highway == 'primary' || data.highway == 'trunk') return false;
    }
    
    return true;
  }

  /// Score une arête selon sa pertinence
  double _scoreEdge(Edge edge, RouteParameters params, double currentDist, double targetDist) {
    double score = 0;
    final data = edge.data;
    
    // Score de base : qualité
    score += data.qualityScore * 10;
    
    // Bonus selon les préférences
    if (params.urbanDensity.id == 'nature') {
      if (data.isInPark) score += 50;
      if (data.isInNature) score += 50;
    } else if (params.urbanDensity.id == 'urban') {
      if (data.highway == 'footway' || data.highway == 'cycleway') score += 30;
      if (data.surface == 'asphalt' || data.surface == 'paved') score += 20;
    }
    
    // Bonus si on privilégie le pittoresque
    if (params.preferScenic && (data.isInPark || data.isInNature)) score += 40;
    
    // Pénalité si l'arête nous éloigne trop de la distance cible
    final projectedDist = currentDist + data.length;
    if (projectedDist > targetDist * 1.1) {
      score -= (projectedDist - targetDist) / 10;
    }
    
    // Bonus pour la proximité des POIs
    final nearbyPois = _countNearbyPois(edge);
    score += nearbyPois * 15;
    
    // Pénaliser les connexions virtuelles
    if (data.highway == 'connection') {
      score *= 0.5;
    }
    
    return score;
  }

  /// Compte les POIs proches d'une arête
  int _countNearbyPois(Edge edge) {
    int count = 0;
    const maxDistance = 200.0; // 200m
    
    for (final poi in _pois) {
      final poiCoord = poi['coordinates'] as List;
      final poiLon = poiCoord[0].toDouble();
      final poiLat = poiCoord[1].toDouble();
      
      // Vérifier la distance avec les points de l'arête
      for (final coord in edge.data.coordinates) {
        final dist = _calculateDistance(poiLat, poiLon, coord[1], coord[0]);
        if (dist <= maxDistance) {
          count++;
          break;
        }
      }
    }
    
    return count;
  }

  /// Calcule la distance totale d'une liste de coordonnées
  double _calculateTotalDistance(List<List<double>> coords) {
    double total = 0;
    for (int i = 0; i < coords.length - 1; i++) {
      total += _calculateDistance(
        coords[i][1], coords[i][0],
        coords[i + 1][1], coords[i + 1][0],
      );
    }
    return total / 1000; // Convertir en km
  }

  /// Calcule la distance entre deux points
  double _calculateDistance(double lat1, double lon1, double lat2, double lon2) {
    const R = 6371000; // Rayon de la Terre en mètres
    final dLat = (lat2 - lat1) * math.pi / 180;
    final dLon = (lon2 - lon1) * math.pi / 180;
    
    final a = math.sin(dLat / 2) * math.sin(dLat / 2) +
              math.cos(lat1 * math.pi / 180) * math.cos(lat2 * math.pi / 180) *
              math.sin(dLon / 2) * math.sin(dLon / 2);
    
    final c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
    return R * c;
  }
}

/// Représente un graphe de chemins
class Graph {
  final Map<String, Node> _nodes = {};
  final List<Edge> _edges = [];
  final Map<Node, List<Edge>> _adjacencyList = {};

  int get nodeCount => _nodes.length;
  int get edgeCount => _edges.length;

  /// Ajoute ou récupère un nœud
  Node addNode(double lon, double lat) {
    final key = '${lon.toStringAsFixed(6)}_${lat.toStringAsFixed(6)}';
    return _nodes.putIfAbsent(key, () => Node(lon, lat));
  }

  /// Ajoute une arête bidirectionnelle
  void addEdge(Node from, Node to, EdgeData data) {
    final edge = Edge(from, to, data);
    final reverseEdge = Edge(to, from, data);
    
    _edges.add(edge);
    _edges.add(reverseEdge);
    
    _adjacencyList.putIfAbsent(from, () => []).add(edge);
    _adjacencyList.putIfAbsent(to, () => []).add(reverseEdge);
  }

  /// Trouve le nœud le plus proche d'une position
  Node? findNearestNode(double lon, double lat) {
    Node? nearest;
    double minDistance = double.infinity;
    
    for (final node in _nodes.values) {
      final dist = _calculateNodeDistance(lat, lon, node.lat, node.lon);
      if (dist < minDistance) {
        minDistance = dist;
        nearest = node;
      }
    }
    
    print('🔍 Nœud le plus proche trouvé à ${minDistance.toStringAsFixed(0)}m');
    
    // Augmenter la distance maximale à 5km
    return minDistance < 5000 ? nearest : null;
  }

  /// Obtient les arêtes partant d'un nœud
  List<Edge> getEdgesFrom(Node node) {
    return _adjacencyList[node] ?? [];
  }

  double _calculateNodeDistance(double lat1, double lon1, double lat2, double lon2) {
    const R = 6371000;
    final dLat = (lat2 - lat1) * math.pi / 180;
    final dLon = (lon2 - lon1) * math.pi / 180;
    
    final a = math.sin(dLat / 2) * math.sin(dLat / 2) +
              math.cos(lat1 * math.pi / 180) * math.cos(lat2 * math.pi / 180) *
              math.sin(dLon / 2) * math.sin(dLon / 2);
    
    final c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
    return R * c;
  }
}

/// Représente un nœud du graphe
class Node {
  final double lon;
  final double lat;

  Node(this.lon, this.lat);

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Node &&
          runtimeType == other.runtimeType &&
          (lon - other.lon).abs() < 0.000001 &&
          (lat - other.lat).abs() < 0.000001;

  @override
  int get hashCode => lon.hashCode ^ lat.hashCode;
}

/// Représente une arête du graphe
class Edge {
  final Node from;
  final Node to;
  final EdgeData data;

  Edge(this.from, this.to, this.data);
}

/// Données associées à une arête
class EdgeData {
  final Map<String, dynamic> feature;
  final double length;
  final double qualityScore;
  final bool suitableRunning;
  final bool suitableCycling;
  final bool isInPark;
  final bool isInNature;
  final String surface;
  final String highway;
  final double elevationGain;
  final List<List<double>> coordinates;

  EdgeData({
    required this.feature,
    required this.length,
    required this.qualityScore,
    required this.suitableRunning,
    required this.suitableCycling,
    required this.isInPark,
    required this.isInNature,
    required this.surface,
    required this.highway,
    required this.elevationGain,
    required this.coordinates,
  });
}

/// État pour le pathfinding
class PathState {
  final Node node;
  final List<Edge> path;
  final double distance;
  final double heuristic;
  
  double get f => distance + heuristic;

  PathState({
    required this.node,
    required this.path,
    required this.distance,
    required this.heuristic,
  });
}