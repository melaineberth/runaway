import 'dart:convert';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';
import '../../domain/models/activity_stats.dart';
import '../../../route_generator/domain/models/saved_route.dart';
import '../../../route_generator/domain/models/activity_type.dart';

class ActivityRepository {
  final SupabaseClient _supabase = Supabase.instance.client;
  final Uuid _uuid = const Uuid();
  static const String _goalsKey = 'personal_goals';
  static const String _recordsKey = 'personal_records';

  /// Calcule les statistiques générales à partir des parcours
  Future<ActivityStats> getActivityStats(List<SavedRoute> routes) async {
    if (routes.isEmpty) {
      final now = DateTime.now();
      return ActivityStats(
        totalDistanceKm: 0,
        totalDurationMinutes: 0,
        totalRoutes: 0,
        averageSpeedKmh: 0,
        firstRouteDate: now,
        lastRouteDate: now,
      );
    }

    final totalDistance = routes.fold<double>(
      0, (sum, route) => sum + route.parameters.distanceKm
    );

    final totalDuration = routes.fold<int>(
      0, (sum, route) => sum + (route.actualDuration ?? 
        route.parameters.estimatedDuration.inMinutes)
    );

    final averageSpeed = totalDuration > 0 
      ? (totalDistance / (totalDuration / 60.0))
      : 0.0;

    routes.sort((a, b) => a.createdAt.compareTo(b.createdAt));

    return ActivityStats(
      totalDistanceKm: totalDistance,
      totalDurationMinutes: totalDuration,
      totalRoutes: routes.length,
      averageSpeedKmh: averageSpeed,
      firstRouteDate: routes.first.createdAt,
      lastRouteDate: routes.last.createdAt,
    );
  }

  /// Calcule les statistiques par type d'activité
  Future<List<ActivityTypeStats>> getActivityTypeStats(List<SavedRoute> routes) async {
    final Map<ActivityType, List<SavedRoute>> routesByType = {};
    
    for (final route in routes) {
      final type = route.parameters.activityType;
      routesByType[type] = [...(routesByType[type] ?? []), route];
    }

    final List<ActivityTypeStats> stats = [];
    
    for (final entry in routesByType.entries) {
      final type = entry.key;
      final typeRoutes = entry.value;
      
      final totalDistance = typeRoutes.fold<double>(
        0, (sum, route) => sum + route.parameters.distanceKm
      );
      
      final totalDuration = typeRoutes.fold<int>(
        0, (sum, route) => sum + (route.actualDuration ?? 
          route.parameters.estimatedDuration.inMinutes)
      );
      
      final averageSpeed = totalDuration > 0 
        ? (totalDistance / (totalDuration / 60.0))
        : 0.0;
      
      final speeds = typeRoutes.map((route) {
        final duration = route.actualDuration ?? 
          route.parameters.estimatedDuration.inMinutes;
        return duration > 0 ? (route.parameters.distanceKm / (duration / 60.0)) : 0.0;
      }).toList();
      
      final bestSpeed = speeds.isNotEmpty ? speeds.reduce((a, b) => a > b ? a : b) : 0.0;
      final longestDistance = typeRoutes.map((r) => r.parameters.distanceKm)
        .reduce((a, b) => a > b ? a : b);
      
      final totalElevation = typeRoutes.fold<double>(
        0, (sum, route) => sum + route.parameters.elevationGain
      );
      
      final maxElevation = typeRoutes.map((r) => r.parameters.elevationGain)
        .reduce((a, b) => a > b ? a : b);

      stats.add(ActivityTypeStats(
        activityType: type,
        totalDistanceKm: totalDistance,
        totalDurationMinutes: totalDuration,
        totalRoutes: typeRoutes.length,
        averageSpeedKmh: averageSpeed,
        bestSpeedKmh: bestSpeed,
        longestDistanceKm: longestDistance,
        totalElevationGain: totalElevation,
        maxElevationGain: maxElevation,
      ));
    }

    return stats;
  }

  /// Calcule les statistiques périodiques
  Future<List<PeriodStats>> getPeriodStats(
    List<SavedRoute> routes, 
    PeriodType period
  ) async {
    final Map<DateTime, List<SavedRoute>> routesByPeriod = {};
    
    for (final route in routes) {
      final periodKey = _getPeriodKey(route.createdAt, period);
      routesByPeriod[periodKey] = [...(routesByPeriod[periodKey] ?? []), route];
    }

    final List<PeriodStats> stats = [];
    
    for (final entry in routesByPeriod.entries) {
      final periodRoutes = entry.value;
      
      final distance = periodRoutes.fold<double>(
        0, (sum, route) => sum + route.parameters.distanceKm
      );
      
      final duration = periodRoutes.fold<int>(
        0, (sum, route) => sum + (route.actualDuration ?? 
          route.parameters.estimatedDuration.inMinutes)
      );
      
      final elevation = periodRoutes.fold<int>(
        0, (sum, route) => sum + _calculateElevation(route)
      );

      stats.add(PeriodStats(
        period: entry.key,
        distanceKm: distance,
        durationMinutes: duration,
        routeCount: periodRoutes.length,
        elevation: elevation,
      ));
    }

    stats.sort((a, b) => a.period.compareTo(b.period));
    return stats;
  }

  /// Gestion des objectifs personnels
  Future<List<PersonalGoal>> getPersonalGoals() async {
    try {
      final user = _supabase.auth.currentUser;
      if (user != null) {
        final response = await _supabase
            .from('user_goals')
            .select()
            .eq('user_id', user.id);
        
        return (response as List)
            .map((json) => PersonalGoal.fromJson(json))
            .toList();
      }
    } catch (e) {
      print('Erreur chargement objectifs: $e');
    }

    // Fallback local
    final prefs = await SharedPreferences.getInstance();
    final goalsJson = prefs.getString(_goalsKey);
    if (goalsJson != null) {
      final List<dynamic> goalsList = jsonDecode(goalsJson);
      return goalsList.map((json) => PersonalGoal.fromJson(json)).toList();
    }
    
    return [];
  }

  Future<void> savePersonalGoal(PersonalGoal goal) async {
    try {
      final user = _supabase.auth.currentUser;
      if (user != null) {
        await _supabase.from('user_goals').upsert({
          ...goal.toJson(),
          'user_id': user.id,
        });
      }
    } catch (e) {
      print('Erreur sauvegarde objectif: $e');
    }

    // Sauvegarde locale
    final goals = await getPersonalGoals();
    final existingIndex = goals.indexWhere((g) => g.id == goal.id);
    
    if (existingIndex >= 0) {
      goals[existingIndex] = goal;
    } else {
      goals.add(goal);
    }

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_goalsKey, jsonEncode(goals.map((g) => g.toJson()).toList()));
  }

  Future<void> deletePersonalGoal(String goalId) async {
    try {
      final user = _supabase.auth.currentUser;
      if (user != null) {
        await _supabase
            .from('user_goals')
            .delete()
            .eq('id', goalId)
            .eq('user_id', user.id);
      }
    } catch (e) {
      print('Erreur suppression objectif: $e');
    }

    // Suppression locale
    final goals = await getPersonalGoals();
    goals.removeWhere((g) => g.id == goalId);
    
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_goalsKey, jsonEncode(goals.map((g) => g.toJson()).toList()));
  }

  /// Mise à jour des objectifs avec les nouveaux parcours
  Future<void> updateGoalsProgress(List<SavedRoute> routes) async {
    final goals = await getPersonalGoals();
    final now = DateTime.now();
    
    for (final goal in goals) {
      if (goal.isCompleted) continue;
      
      double newValue = 0;
      
      switch (goal.type) {
        case GoalType.distance:
          final thisMonth = routes.where((r) => 
            r.createdAt.year == now.year && r.createdAt.month == now.month &&
            (goal.activityType == null || r.parameters.activityType == goal.activityType)
          );
          newValue = thisMonth.fold(0, (sum, r) => sum + r.parameters.distanceKm);
          break;
          
        case GoalType.routes:
          final thisMonth = routes.where((r) => 
            r.createdAt.year == now.year && r.createdAt.month == now.month &&
            (goal.activityType == null || r.parameters.activityType == goal.activityType)
          );
          newValue = thisMonth.length.toDouble();
          break;
          
        case GoalType.speed:
          final relevantRoutes = routes.where((r) => 
            goal.activityType == null || r.parameters.activityType == goal.activityType
          );
          if (relevantRoutes.isNotEmpty) {
            final speeds = relevantRoutes.map((r) {
              final duration = r.actualDuration ?? r.parameters.estimatedDuration.inMinutes;
              return duration > 0 ? (r.parameters.distanceKm / (duration / 60.0)) : 0.0;
            });
            newValue = speeds.reduce((a, b) => a + b) / speeds.length;
          }
          break;
          
        case GoalType.elevation:
          final thisMonth = routes.where((r) => 
            r.createdAt.year == now.year && r.createdAt.month == now.month &&
            (goal.activityType == null || r.parameters.activityType == goal.activityType)
          );
          newValue = thisMonth.fold(0, (sum, r) => sum + r.parameters.elevationGain);
          break;
      }
      
      final updatedGoal = goal.copyWith(
        currentValue: newValue,
        isCompleted: newValue >= goal.targetValue,
      );
      
      await savePersonalGoal(updatedGoal);
    }
  }

  /// Gestion des records personnels
  Future<List<PersonalRecord>> getPersonalRecords() async {
    try {
      final user = _supabase.auth.currentUser;
      if (user != null) {
        final response = await _supabase
            .from('user_records')
            .select()
            .eq('user_id', user.id);
        
        return (response as List)
            .map((json) => PersonalRecord.fromJson(json))
            .toList();
      }
    } catch (e) {
      print('Erreur chargement records: $e');
    }

    // Fallback local
    final prefs = await SharedPreferences.getInstance();
    final recordsJson = prefs.getString(_recordsKey);
    if (recordsJson != null) {
      final List<dynamic> recordsList = jsonDecode(recordsJson);
      return recordsList.map((json) => PersonalRecord.fromJson(json)).toList();
    }
    
    return [];
  }

  /// Met à jour les records avec un nouveau parcours
  Future<void> updatePersonalRecords(SavedRoute route) async {
    final records = await getPersonalRecords();
    bool hasNewRecord = false;

    // Vérifier distance maximale
    final distanceRecord = records.where((r) => 
      r.type == RecordType.longestDistance && 
      r.activityType == route.parameters.activityType
    ).toList();
    
    if (distanceRecord.isEmpty || 
        distanceRecord.first.value < route.parameters.distanceKm) {
      await _saveRecord(
        RecordType.longestDistance,
        route.parameters.distanceKm,
        'km',
        route,
      );
      hasNewRecord = true;
    }

    // Vérifier dénivelé maximal
    final elevationRecord = records.where((r) => 
      r.type == RecordType.highestElevation && 
      r.activityType == route.parameters.activityType
    ).toList();
    
    if (elevationRecord.isEmpty || 
        elevationRecord.first.value < route.parameters.elevationGain) {
      await _saveRecord(
        RecordType.highestElevation,
        route.parameters.elevationGain,
        'm',
        route,
      );
      hasNewRecord = true;
    }

    // Vérifier vitesse (si durée disponible)
    if (route.actualDuration != null) {
      final speed = route.parameters.distanceKm / (route.actualDuration! / 60.0);
      
      final speedRecord = records.where((r) => 
        r.type == RecordType.fastestSpeed && 
        r.activityType == route.parameters.activityType
      ).toList();
      
      if (speedRecord.isEmpty || speedRecord.first.value < speed) {
        await _saveRecord(
          RecordType.fastestSpeed,
          speed,
          'km/h',
          route,
        );
        hasNewRecord = true;
      }

      // Vérifier durée maximale
      final durationRecord = records.where((r) => 
        r.type == RecordType.longestDuration && 
        r.activityType == route.parameters.activityType
      ).toList();
      
      if (durationRecord.isEmpty || 
          durationRecord.first.value < route.actualDuration!) {
        await _saveRecord(
          RecordType.longestDuration,
          route.actualDuration!.toDouble(),
          'min',
          route,
        );
        hasNewRecord = true;
      }
    }
  }

  /// Utilitaires privés
  int _calculateElevation(SavedRoute route) {
    final duration = route.actualDuration ?? route.parameters.estimatedDuration.inMinutes;
    final distance = route.parameters.distanceKm;
    
    // Calcul approximatif basé sur l'activité
    switch (route.parameters.activityType) {
      case ActivityType.running:
        return (distance * 62).round(); // ~62 cal/km pour la course
      case ActivityType.cycling:
        return (distance * 28).round(); // ~28 cal/km pour le vélo
      case ActivityType.walking:
        return (distance * 45).round(); // ~45 cal/km pour la marche
    }
  }

  DateTime _getPeriodKey(DateTime date, PeriodType period) {
    switch (period) {
      case PeriodType.weekly:
        final weekStart = date.subtract(Duration(days: date.weekday - 1));
        return DateTime(weekStart.year, weekStart.month, weekStart.day);
      case PeriodType.monthly:
        return DateTime(date.year, date.month, 1);
    }
  }

  Future<void> _saveRecord(
    RecordType type,
    double value,
    String unit,
    SavedRoute route,
  ) async {
    final record = PersonalRecord(
      id: _uuid.v4(),
      type: type,
      value: value,
      unit: unit,
      achievedAt: route.createdAt,
      routeId: route.id,
      routeName: route.name,
      activityType: route.parameters.activityType,
    );

    try {
      final user = _supabase.auth.currentUser;
      if (user != null) {
        await _supabase.from('user_records').upsert({
          ...record.toJson(),
          'user_id': user.id,
        });
      }
    } catch (e) {
      print('Erreur sauvegarde record: $e');
    }

    // Sauvegarde locale
    final records = await getPersonalRecords();
    records.removeWhere((r) => 
      r.type == type && r.activityType == route.parameters.activityType
    );
    records.add(record);

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_recordsKey, jsonEncode(records.map((r) => r.toJson()).toList()));
  }
}

enum PeriodType { weekly, monthly }