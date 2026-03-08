# Permission Usage Examples

## Overview

The permissions screen now allows users to proceed even if some permissions are denied. Permissions can be requested again contextually when needed on specific screens.

## Changes Made

1. **Permissions Screen**: Users can now continue even if permissions are denied
2. **Permission Helper**: Utility class for requesting permissions on specific screens
3. **Non-blocking**: No blocking dialogs - users can always proceed

## Using Permissions on Specific Screens

### Example 1: Request Camera Permission When User Taps Camera Button

```dart
import 'package:flutter/material.dart';
import '../permissions/utils/permission_helper.dart';

class CameraScreen extends StatefulWidget {
  @override
  _CameraScreenState createState() => _CameraScreenState();
}

class _CameraScreenState extends State<CameraScreen> {
  bool _hasPermission = false;

  Future<void> _checkAndRequestCamera() async {
    // Check if permission is already granted
    final isGranted = await PermissionHelper.isPermissionGranted('Camera');
    
    if (isGranted) {
      setState(() {
        _hasPermission = true;
      });
      // Proceed with camera functionality
      _openCamera();
    } else {
      // Request permission
      final granted = await PermissionHelper.requestPermissionWithDialog(
        'Camera',
        context,
        deniedMessage: 'Camera permission is needed to take photos',
        permanentlyDeniedMessage: 'Camera permission is required. Please enable it in settings.',
      );
      
      if (granted) {
        setState(() {
          _hasPermission = true;
        });
        _openCamera();
      } else {
        // Show message that feature is unavailable without permission
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Camera feature requires permission'),
          ),
        );
      }
    }
  }

  void _openCamera() {
    // Your camera functionality here
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Camera')),
      body: Center(
        child: ElevatedButton(
          onPressed: _checkAndRequestCamera,
          child: const Text('Take Photo'),
        ),
      ),
    );
  }
}
```

### Example 2: Request Location Permission When User Opens Map

```dart
import 'package:flutter/material.dart';
import '../permissions/utils/permission_helper.dart';

class MapScreen extends StatefulWidget {
  @override
  _MapScreenState createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  bool _locationGranted = false;

  @override
  void initState() {
    super.initState();
    _checkLocationPermission();
  }

  Future<void> _checkLocationPermission() async {
    final granted = await PermissionHelper.isPermissionGranted('Location');
    setState(() {
      _locationGranted = granted;
    });

    if (!granted) {
      // Request permission when screen opens
      final result = await PermissionHelper.requestPermissionWithDialog(
        'Location',
        context,
        deniedMessage: 'Location permission helps show your position on the map',
      );
      
      setState(() {
        _locationGranted = result;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Map')),
      body: _locationGranted
          ? const Text('Map with location')
          : const Center(
              child: Text('Location permission needed for map features'),
            ),
    );
  }
}
```

### Example 3: Request Multiple Permissions for a Feature

```dart
Future<void> _startDiagnosis() async {
  // Request multiple permissions needed for diagnosis
  final permissions = ['Camera', 'Microphone', 'Location'];
  final results = await PermissionHelper.requestPermissions(permissions);

  // Check which permissions were granted
  final cameraGranted = results['Camera'] ?? false;
  final micGranted = results['Microphone'] ?? false;
  final locationGranted = results['Location'] ?? false;

  // Proceed with available features
  if (cameraGranted) {
    // Use camera
  }
  if (micGranted) {
    // Use microphone
  }
  if (locationGranted) {
    // Use location
  }

  // Show message about unavailable features
  final unavailable = <String>[];
  if (!cameraGranted) unavailable.add('Camera');
  if (!micGranted) unavailable.add('Microphone');
  if (!locationGranted) unavailable.add('Location');

  if (unavailable.isNotEmpty) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Some features unavailable: ${unavailable.join(", ")}',
        ),
      ),
    );
  }
}
```

## Permission Helper Methods

### `requestPermission(String permissionName)`
Request a single permission. Returns `true` if granted.

### `requestPermissions(List<String> permissionNames)`
Request multiple permissions. Returns a map of permission names to granted status.

### `isPermissionGranted(String permissionName)`
Check if a permission is currently granted.

### `isPermissionPermanentlyDenied(String permissionName)`
Check if a permission is permanently denied (requires settings).

### `requestPermissionWithDialog(String permissionName, BuildContext context, {...})`
Request permission with user-friendly dialogs. Automatically handles permanently denied permissions.

## Best Practices

1. **Request when needed**: Don't request permissions upfront - request them when the user tries to use a feature
2. **Explain why**: Always explain why the permission is needed
3. **Graceful degradation**: Allow the app to work with limited permissions
4. **Don't block**: Never block the user from using the app if permissions are denied
5. **Re-request**: You can ask for permissions again later if the user initially denied them

## Permission Names

Use the exact names from `PermissionMapper.getAllPermissionNames()`:
- 'Camera'
- 'Microphone'
- 'Storage & Files'
- 'Photos & Media'
- 'Location'
- 'Location (Always)'
- 'Contacts'
- 'Phone'
- 'SMS'
- 'Calendar'
- 'Reminders'
- 'Bluetooth'
- 'Bluetooth Scan'
- 'Bluetooth Connect'
- 'Wi-Fi'
- 'Notifications'
- 'Body Sensors'
- 'Activity Recognition'
- 'Manage Storage'

