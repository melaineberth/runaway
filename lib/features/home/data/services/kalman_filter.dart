import 'dart:math' as math;

/// Filtre de Kalman pour lisser les positions GPS
/// Implémentation adaptée pour la navigation en temps réel
class GPSKalmanFilter {
  // États : [latitude, longitude, vitesse_lat, vitesse_lon]
  List<double> _state = [0.0, 0.0, 0.0, 0.0];
  
  // Matrice de covariance de l'erreur
  List<List<double>> _P = [
    [1.0, 0.0, 0.0, 0.0],
    [0.0, 1.0, 0.0, 0.0],
    [0.0, 0.0, 1.0, 0.0],
    [0.0, 0.0, 0.0, 1.0]
  ];
  
  // Bruit de processus (mouvement imprévisible)
  final double _processNoise;
  
  // Dernière mise à jour
  DateTime? _lastUpdate;
  
  // Historique pour calculs dérivés
  final List<_StateSnapshot> _history = [];
  static const int _maxHistorySize = 10;

  bool _isInitialized = false;

  GPSKalmanFilter({
    double processNoise = 0.1,
  }) : _processNoise = processNoise;

  /// Initialise le filtre avec la première position
  void initialize(double latitude, double longitude, double accuracy) {
    _state = [latitude, longitude, 0.0, 0.0];
    
    // Covariance initiale basée sur la précision GPS
    final initialVar = math.max(accuracy * accuracy, 1.0);
    _P = [
      [initialVar, 0.0, 0.0, 0.0],
      [0.0, initialVar, 0.0, 0.0],
      [0.0, 0.0, 1.0, 0.0],
      [0.0, 0.0, 0.0, 1.0]
    ];
    
    _lastUpdate = DateTime.now();
    _isInitialized = true;
    
    print('🔧 Kalman Filter initialisé: lat=${latitude.toStringAsFixed(6)}, '
          'lon=${longitude.toStringAsFixed(6)}, accuracy=${accuracy.toStringAsFixed(1)}m');
  }

  /// Met à jour le filtre avec une nouvelle mesure GPS
  FilteredGPSState update(
    double latitude,
    double longitude,
    double accuracy,
    DateTime timestamp,
  ) {
    if (!_isInitialized) {
      initialize(latitude, longitude, accuracy);
      return FilteredGPSState(
        latitude: latitude,
        longitude: longitude,
        filteredLatitude: latitude,
        filteredLongitude: longitude,
        speed: 0.0,
        heading: 0.0,
        confidence: 0.5, // Première mesure = confiance modérée
      );
    }

    final deltaTime = timestamp.difference(_lastUpdate!).inMilliseconds / 1000.0;
    
    // Étape de prédiction
    _predict(deltaTime);
    
    // Étape de correction avec la mesure GPS
    final corrected = _correct(latitude, longitude, accuracy);
    
    // Calculer vitesse et cap lissés
    final smoothedMetrics = _calculateSmoothedMetrics(deltaTime);
    
    // Sauvegarder dans l'historique
    _saveSnapshot(timestamp);
    
    _lastUpdate = timestamp;

    return FilteredGPSState(
      latitude: latitude,
      longitude: longitude,
      filteredLatitude: corrected[0],
      filteredLongitude: corrected[1],
      speed: smoothedMetrics.speed,
      heading: smoothedMetrics.heading,
      confidence: _calculateConfidence(accuracy),
    );
  }

  /// Prédiction du prochain état
  void _predict(double deltaTime) {
    // Matrices de transition (modèle de vitesse constante)
    final F = [
      [1.0, 0.0, deltaTime, 0.0],
      [0.0, 1.0, 0.0, deltaTime],
      [0.0, 0.0, 1.0, 0.0],
      [0.0, 0.0, 0.0, 1.0]
    ];
    
    // Prédiction de l'état
    final newState = _multiplyMatrixVector(F, _state);
    _state = newState;
    
    // Prédiction de la covariance
    final Ft = _transpose(F);
    final FP = _multiplyMatrix(F, _P);
    final FPFt = _multiplyMatrix(FP, Ft);
    
    // Ajout du bruit de processus
    final Q = _createProcessNoiseMatrix(deltaTime);
    _P = _addMatrix(FPFt, Q);
  }

  /// Correction avec la mesure GPS
  List<double> _correct(double latitude, double longitude, double accuracy) {
    // Matrice d'observation (on observe seulement lat/lon)
    final H = [
      [1.0, 0.0, 0.0, 0.0],
      [0.0, 1.0, 0.0, 0.0]
    ];
    
    // Bruit de mesure basé sur la précision GPS
    final R = [
      [accuracy * accuracy, 0.0],
      [0.0, accuracy * accuracy]
    ];
    
    // Innovation (différence mesure - prédiction)
    final z = [latitude, longitude];
    final Hx = _multiplyMatrixVector(H, _state);
    final y = [z[0] - Hx[0], z[1] - Hx[1]];
    
    // Calcul du gain de Kalman
    final Ht = _transpose(H);
    final HP = _multiplyMatrix(H, _P);
    final HPHt = _multiplyMatrix(HP, Ht);
    final S = _addMatrix(HPHt, R);
    final Sinv = _invertMatrix2x2(S);
    final PHt = _multiplyMatrix(_P, Ht);
    final K = _multiplyMatrix(PHt, Sinv);
    
    // Mise à jour de l'état
    final Ky = _multiplyMatrixVector(K, y);
    _state = [
      _state[0] + Ky[0],
      _state[1] + Ky[1],
      _state[2] + Ky[2],
      _state[3] + Ky[3]
    ];
    
    // Mise à jour de la covariance
    final KH = _multiplyMatrix(K, H);
    final I_KH = _subtractFromIdentity(KH);
    _P = _multiplyMatrix(I_KH, _P);
    
    return [_state[0], _state[1]];
  }

  /// Calcule les métriques lissées (vitesse et cap)
  _SmoothedMetrics _calculateSmoothedMetrics(double deltaTime) {
    if (_history.isEmpty || deltaTime <= 0) {
      return _SmoothedMetrics(speed: 0.0, heading: 0.0);
    }

    // Calculer la vitesse moyenne sur les dernières positions
    double totalDistance = 0.0;
    double totalTime = 0.0;
    
    for (int i = 1; i < _history.length; i++) {
      final prev = _history[i - 1];
      final curr = _history[i];
      
      final distance = _calculateDistance(
        prev.latitude, prev.longitude,
        curr.latitude, curr.longitude,
      );
      
      final timeDiff = curr.timestamp.difference(prev.timestamp).inMilliseconds / 1000.0;
      
      totalDistance += distance;
      totalTime += timeDiff;
    }
    
    final speed = totalTime > 0 ? totalDistance / totalTime : 0.0;
    
    // Calculer le cap moyen (direction générale)
    double heading = 0.0;
    if (_history.length >= 2) {
      final start = _history.first;
      final end = _history.last;
      heading = _calculateBearing(
        start.latitude, start.longitude,
        end.latitude, end.longitude,
      );
    }
    
    return _SmoothedMetrics(speed: speed, heading: heading);
  }

  /// Sauvegarde un snapshot de l'état actuel
  void _saveSnapshot(DateTime timestamp) {
    _history.add(_StateSnapshot(
      latitude: _state[0],
      longitude: _state[1],
      timestamp: timestamp,
    ));
    
    if (_history.length > _maxHistorySize) {
      _history.removeAt(0);
    }
  }

  /// Calcule la confiance basée sur la précision
  double _calculateConfidence(double accuracy) {
    // Confiance inverse de la précision (plus précis = plus confiant)
    if (accuracy <= 5) return 0.95;
    if (accuracy <= 10) return 0.8;
    if (accuracy <= 20) return 0.6;
    if (accuracy <= 50) return 0.4;
    return 0.2;
  }

  /// Crée la matrice de bruit de processus
  List<List<double>> _createProcessNoiseMatrix(double deltaTime) {
    final q = _processNoise;
    final dt2 = deltaTime * deltaTime;
    final dt3 = dt2 * deltaTime / 2;
    
    return [
      [dt3 * q, 0.0, dt2 * q, 0.0],
      [0.0, dt3 * q, 0.0, dt2 * q],
      [dt2 * q, 0.0, deltaTime * q, 0.0],
      [0.0, dt2 * q, 0.0, deltaTime * q]
    ];
  }

  // === Utilitaires mathématiques ===
  
  List<double> _multiplyMatrixVector(List<List<double>> matrix, List<double> vector) {
    final result = <double>[];
    for (int i = 0; i < matrix.length; i++) {
      double sum = 0.0;
      for (int j = 0; j < vector.length; j++) {
        sum += matrix[i][j] * vector[j];
      }
      result.add(sum);
    }
    return result;
  }
  
  List<List<double>> _multiplyMatrix(List<List<double>> a, List<List<double>> b) {
    final rows = a.length;
    final cols = b[0].length;
    final result = List.generate(rows, (_) => List.filled(cols, 0.0));
    
    for (int i = 0; i < rows; i++) {
      for (int j = 0; j < cols; j++) {
        for (int k = 0; k < a[i].length; k++) {
          result[i][j] += a[i][k] * b[k][j];
        }
      }
    }
    return result;
  }
  
  List<List<double>> _transpose(List<List<double>> matrix) {
    final rows = matrix[0].length;
    final cols = matrix.length;
    final result = List.generate(rows, (_) => List.filled(cols, 0.0));
    
    for (int i = 0; i < rows; i++) {
      for (int j = 0; j < cols; j++) {
        result[i][j] = matrix[j][i];
      }
    }
    return result;
  }
  
  List<List<double>> _addMatrix(List<List<double>> a, List<List<double>> b) {
    final result = <List<double>>[];
    for (int i = 0; i < a.length; i++) {
      final row = <double>[];
      for (int j = 0; j < a[i].length; j++) {
        row.add(a[i][j] + b[i][j]);
      }
      result.add(row);
    }
    return result;
  }
  
  List<List<double>> _invertMatrix2x2(List<List<double>> matrix) {
    final det = matrix[0][0] * matrix[1][1] - matrix[0][1] * matrix[1][0];
    if (det.abs() < 1e-10) {
      // Matrice singulière, retourner l'identité
      return [[1.0, 0.0], [0.0, 1.0]];
    }
    
    return [
      [matrix[1][1] / det, -matrix[0][1] / det],
      [-matrix[1][0] / det, matrix[0][0] / det]
    ];
  }
  
  List<List<double>> _subtractFromIdentity(List<List<double>> matrix) {
    final result = <List<double>>[];
    for (int i = 0; i < matrix.length; i++) {
      final row = <double>[];
      for (int j = 0; j < matrix[i].length; j++) {
        row.add((i == j ? 1.0 : 0.0) - matrix[i][j]);
      }
      result.add(row);
    }
    return result;
  }

  double _calculateDistance(double lat1, double lon1, double lat2, double lon2) {
    const double R = 6371000; // Rayon terrestre en mètres
    final dLat = (lat2 - lat1) * math.pi / 180;
    final dLon = (lon2 - lon1) * math.pi / 180;
    
    final a = math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(lat1 * math.pi / 180) * math.cos(lat2 * math.pi / 180) *
        math.sin(dLon / 2) * math.sin(dLon / 2);
    
    final c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
    return R * c;
  }
  
  double _calculateBearing(double lat1, double lon1, double lat2, double lon2) {
    final dLon = (lon2 - lon1) * math.pi / 180;
    final lat1Rad = lat1 * math.pi / 180;
    final lat2Rad = lat2 * math.pi / 180;
    
    final y = math.sin(dLon) * math.cos(lat2Rad);
    final x = math.cos(lat1Rad) * math.sin(lat2Rad) - 
             math.sin(lat1Rad) * math.cos(lat2Rad) * math.cos(dLon);
    
    final bearing = math.atan2(y, x) * 180 / math.pi;
    return (bearing + 360) % 360;
  }

  /// Réinitialise le filtre
  void reset() {
    _isInitialized = false;
    _history.clear();
    _lastUpdate = null;
    print('🔄 Kalman Filter réinitialisé');
  }

  // Getters pour l'état actuel
  double get currentLatitude => _state[0];
  double get currentLongitude => _state[1];
  bool get isInitialized => _isInitialized;
}

/// État GPS filtré
class FilteredGPSState {
  final double latitude;
  final double longitude;
  final double filteredLatitude;
  final double filteredLongitude;
  final double speed;
  final double heading;
  final double confidence;

  FilteredGPSState({
    required this.latitude,
    required this.longitude,
    required this.filteredLatitude,
    required this.filteredLongitude,
    required this.speed,
    required this.heading,
    required this.confidence,
  });
}

/// Métriques lissées
class _SmoothedMetrics {
  final double speed;
  final double heading;

  _SmoothedMetrics({required this.speed, required this.heading});
}

/// Snapshot d'état pour l'historique
class _StateSnapshot {
  final double latitude;
  final double longitude;
  final DateTime timestamp;

  _StateSnapshot({
    required this.latitude,
    required this.longitude,
    required this.timestamp,
  });
}