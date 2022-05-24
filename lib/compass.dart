import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_compass/flutter_compass.dart';
import 'package:permission_handler/permission_handler.dart';

class Kompass {
  StreamSubscription? _sub;

  void start(Function listener(CompassEvent)) {
    _sub = FlutterCompass.events?.listen(listener);
  }

  void stop() {
    _sub?.cancel();
  }

  //
  // Widget buildPermissionSheet() {
  //   return Center(
  //     child: Column(
  //       mainAxisSize: MainAxisSize.min,
  //       children: <Widget>[
  //         Text('Location Permission Required'),
  //         ElevatedButton(
  //           child: Text('Request Permissions'),
  //           onPressed: () {
  //             Permission.locationWhenInUse.request().then((ignored) {
  //               _fetchPermissionStatus();
  //             });
  //           },
  //         ),
  //         SizedBox(height: 16),
  //         ElevatedButton(
  //           child: Text('Open App Settings'),
  //           onPressed: () {
  //             openAppSettings().then((opened) {
  //               //
  //             });
  //           },
  //         )
  //       ],
  //     ),
  //   );
  // }
  //
  // void _fetchPermissionStatus() {
  //   Permission.locationWhenInUse.status.then((status) {
  //     if (mounted) {
  //       setState(() => _hasPermissions = status == PermissionStatus.granted);
  //     }
  //   });
  // }
}
