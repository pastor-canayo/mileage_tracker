import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:sensors_plus/sensors_plus.dart';

void main() => runApp(MaterialApp(home: MovementTracker(), theme: ThemeData.dark()));

class MovementTracker extends StatefulWidget {
  @override
  _MovementTrackerState createState() => _MovementTrackerState();
}

class _MovementTrackerState extends State<MovementTracker> {
  double _miles = 0.0;
  int _steps = 0;
  bool _isTracking = false;
  Position? _lastPos;
  FlutterTts _tts = FlutterTts();
  bool _milestoneSaid = false;

  void _toggleTracking() async {
    if (!_isTracking) {
      LocationPermission perm = await Geolocator.requestPermission();
      if (perm == LocationPermission.denied) return;
      
      setState(() { _isTracking = true; _miles = 0.0; _steps = 0; _milestoneSaid = false; });
      
      Geolocator.getPositionStream(locationSettings: LocationSettings(accuracy: LocationAccuracy.high, distanceFilter: 2))
          .listen((pos) {
        if (!_isTracking) return;
        if (_lastPos != null) {
          double dist = Geolocator.distanceBetween(_lastPos!.latitude, _lastPos!.longitude, pos.latitude, pos.longitude);
          setState(() {
            _miles += dist * 0.000621371;
            if (_miles >= 1.0 && !_milestoneSaid) {
              _tts.speak("You have completed one mile!");
              _milestoneSaid = true;
            }
          });
        }
        _lastPos = pos;
      });

      double magnitudePrevious = 0.0;
      userAccelerometerEvents.listen((UserAccelerometerEvent event) {
        if (!_isTracking) return;
        double magnitude = event.x * event.x + event.y * event.y + event.z * event.z;
        if ((magnitude - magnitudePrevious).abs() > 12.0) {
          setState(() { _steps++; });
        }
        magnitudePrevious = magnitude;
      });
    } else {
      setState(() { _isTracking = false; _lastPos = null; });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text('${_miles.toStringAsFixed(2)} Mi', style: TextStyle(fontSize: 70, fontWeight: FontWeight.bold)),
            SizedBox(height: 10),
            Text('$_steps Steps', style: TextStyle(fontSize: 30, color: Colors.grey)),
            SizedBox(height: 50),
            ElevatedButton(
              onPressed: _toggleTracking,
              child: Text(_isTracking ? 'STOP TRACKING' : 'START TRACKING', style: TextStyle(fontSize: 20)),
              style: ElevatedButton.styleFrom(backgroundColor: _isTracking ? Colors.red : Colors.green, padding: EdgeInsets.symmetric(horizontal: 40, vertical: 15)),
            )
          ],
        ),
      ),
    );
  }
}
