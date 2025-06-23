import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart' as gl;

class NavigationArgs {
  final List<List<double>> route;
  final double routeDistanceKm;
  final int estimatedDurationMinutes;

  NavigationArgs({
    required this.route,
    required this.routeDistanceKm,
    required this.estimatedDurationMinutes,
  });
}

class NavigationScreen extends StatefulWidget {
  final NavigationArgs args;
  const NavigationScreen({super.key, required this.args});

  @override
  State<NavigationScreen> createState() => _NavigationScreenState();
}

class _NavigationScreenState extends State<NavigationScreen> {
  Timer? _timer;
  int _elapsedSeconds = 0;
  StreamSubscription<gl.Position>? _posSub;
  final List<gl.Position> _positions = [];
  double _distanceMeters = 0;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      setState(() {
        _elapsedSeconds;
      });
    });

    _posSub = gl.Geolocator.getPositionStream(
      locationSettings: const gl.LocationSettings(
        accuracy: gl.LocationAccuracy.best,
        distanceFilter: 1,
      ),
    ).listen(_onPosition);
  }

  void _onPosition(gl.Position pos) {
    if (_positions.isNotEmpty) {
      final prev = _positions.last;
      _distanceMeters = _distanceBetween(
        prev.latitude,
        prev.longitude,
        pos.latitude,
        pos.longitude,
      );
    }
    setState(() {
      _positions.add(pos);
    });
  }

  double get _distanceKm => _distanceMeters / 1000.0;

  double get _speedKmh =>
      _elapsedSeconds > 0 ? _distanceKm / (_elapsedSeconds / 3600) : 0.0;

  double get _paceSecPerKm =>
      _distanceKm > 0 ? _elapsedSeconds / _distanceKm : 0.0;

  double get _currentAltitude =>
      _positions.isNotEmpty ? _positions.last.altitude : 0.0;

  Duration get _estimatedRemaining {
    final remainingKm = (widget.args.routeDistanceKm - _distanceKm).clamp(
      0,
      double.infinity,
    );
    final speedKmh = _speedKmh;
    if (speedKmh <= 0) return Duration.zero;
    final hours = remainingKm / speedKmh;
    return Duration(seconds: (hours * 3600).round());
  }

  String _formatDuration(Duration d) {
    final hours = d.inHours;
    final minutes = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return hours > 0 ? '$hours:$minutes:$seconds' : '$minutes:$seconds';
  }

  String _formatPace(double secPerKm) {
    if (secPerKm.isInfinite || secPerKm.isNaN || secPerKm == 0) {
      return '--';
    }
    final minutes = (secPerKm / 60).floor();
    final seconds = (secPerKm % 60).round().toString().padLeft(2, '0');
    return '$minutes:$seconds /km';
  }

  double _distanceBetween(double lat1, double lon1, double lat2, double lon2) {
    const earthRadius = 6371000.0;
    final dLat = _toRad(lat2 - lat1);
    final dLon = _toRad(lon2 - lon1);
    final a = (sin(dLat / 2) * sin(dLat / 2));
    cos(_toRad(lat1)) * cos(_toRad(lat2)) * sin(dLon / 2) * sin(dLon / 2);
    final c = 2 * atan2(sqrt(a), sqrt(1 - a));
    return earthRadius * c;
  }

  double _toRad(double deg) => deg * 3.141592653589793 / 180;

  @override
  void dispose() {
    _timer?.cancel();
    _posSub?.cancel();
    super.dispose();
  }

  void _stopNavigation() {
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Navigation')),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Temps écoulé: ${_formatDuration(Duration(seconds: _elapsedSeconds))}',
              ),
              const SizedBox(height: 8),
              Text('Distance: ${_distanceKm.toStringAsFixed(2)} km'),
              const SizedBox(height: 8),
              Text('Dénivelé: ${_currentAltitude.toStringAsFixed(0)} m'),
              const SizedBox(height: 8),
              Text('Rythme: ${_formatPace(_paceSecPerKm)}'),
              const SizedBox(height: 8),
              Text('Temps restant: ${_formatDuration(_estimatedRemaining)}'),
              const SizedBox(height: 8),
              Text('Vitesse: ${_speedKmh.toStringAsFixed(1)} km/h'),
              const Spacer(),
              Center(
                child: ElevatedButton(
                  onPressed: _stopNavigation,
                  child: const Text('Stop'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
