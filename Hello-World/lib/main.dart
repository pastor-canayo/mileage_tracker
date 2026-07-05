import 'dart:async';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:pedometer/pedometer.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:permission_handler/permission_handler.dart';

void main() => runApp(const MaterialApp(home: TrackerApp()));

class TrackerApp extends StatefulWidget {
  const TrackerApp({super.key});

  @override
  State<TrackerApp> createState() => _TrackerAppState();
}

class _TrackerAppState extends State<TrackerApp> {
  // Logic variables
  final FlutterTts _tts = FlutterTts();
  StreamSubscription<Position>? _positionStream;
  StreamSubscription<StepCount>? _stepCountStream;

  double _totalMiles = 0.0;
  int _steps = 0;
  int _initialSteps = -1;
  Position? _lastPosition;
  bool _isTracking = false;
  bool _mileAnnounced = false;

  @override
  void initState() {
    super.initState();
    _initTTS();
  }

  void _initTTS() async {
    await _tts.setLanguage("en-US");
    await _tts.setSpeechRate(0.5);
  }

  Future<void> _startTracking() async {
    // 1. Request Permissions
    Map<Permission, PermissionStatus> statuses = await [
      Permission.location,
      Permission.activityRecognition,
    ].request();

    if (statuses[Permission.location] != PermissionStatus.granted ||
        statuses[Permission.activityRecognition] != PermissionStatus.granted) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text("Permissions required to track activity.")),
        );
      }
      return;
    }

    setState(() {
      _isTracking = true;
      _totalMiles = 0.0;
      _steps = 0;
      _initialSteps = -1;
      _mileAnnounced = false;
      _lastPosition = null;
    });

    // 2. Start Step Tracking
    _stepCountStream = Pedometer.stepCountStream.listen((StepCount event) {
      if (_initialSteps == -1) {
        _initialSteps = event.steps;
      }
      setState(() {
        _steps = event.steps - _initialSteps;
      });
    });

    // 3. Start GPS Tracking (Miles)
    const locationSettings = LocationSettings(
      accuracy: LocationAccuracy.high,
      distanceFilter: 2, // Only update if moved 2 meters (reduces GPS jitter)
    );

    _positionStream =
        Geolocator.getPositionStream(locationSettings: locationSettings)
            .listen((Position position) {
      if (_lastPosition != null) {
        double distanceInMeters = Geolocator.distanceBetween(
          _lastPosition!.latitude,
          _lastPosition!.longitude,
          position.latitude,
          position.longitude,
        );

        // Convert meters to miles
        double milesGained = distanceInMeters * 0.000621371;

        setState(() {
          _totalMiles += milesGained;

          // Trigger voice announcement at exactly 1.0 mile
          if (_totalMiles >= 1.0 && !_mileAnnounced) {
            _mileAnnounced = true;
            _tts.speak("You have completed one mile!");
          }
        });
      }
      _lastPosition = position;
    });
  }

  void _stopTracking() {
    _positionStream?.cancel();
    _stepCountStream?.cancel();
    setState(() => _isTracking = false);
  }

  @override
  void dispose() {
    _positionStream?.cancel();
    _stepCountStream?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(30.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const Text(
                "TOTAL DISTANCE",
                style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey,
                    fontWeight: FontWeight.bold),
              ),
              Text(
                "${_totalMiles.toStringAsFixed(2)} Mi",
                style: const TextStyle(
                    fontSize: 80,
                    fontWeight: FontWeight.w900,
                    color: Colors.black),
              ),
              const SizedBox(height: 40),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.directions_walk, color: Colors.blueAccent),
                  const SizedBox(width: 10),
                  Text(
                    "$_steps Steps",
                    style: const TextStyle(
                        fontSize: 24, fontWeight: FontWeight.w500),
                  ),
                ],
              ),
              const SizedBox(height: 80),
              SizedBox(
                width: double.infinity,
                height: 60,
                child: ElevatedButton(
                  onPressed: _isTracking ? _stopTracking : _startTracking,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _isTracking
                        ? Colors.redAccent
                        : Colors.greenAccent[700],
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(15)),
                  ),
                  child: Text(
                    _isTracking ? "STOP TRACKING" : "START TRACKING",
                    style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.white),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
