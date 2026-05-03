import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'package:permission_handler/permission_handler.dart';

/// Stores permission statuses and location data to avoid repeated checks
class PermissionStatusNotifier extends StateNotifier<Map<String, dynamic>> {
  PermissionStatusNotifier() : super({}) {
    // Initialize in background
    _initializePermissions();
  }

  Future<void> _initializePermissions() async {
    // Check permissions and get location in background without blocking
    await _checkLocationPermission();
  }

  Future<void> _checkLocationPermission() async {
    try {
      // Check location service and permission status
      final isServiceEnabled = await Geolocator.isLocationServiceEnabled();
      final locationPermission = Permission.locationWhenInUse;
      final permissionStatus = await locationPermission.status;
      final geolocatorPermission = await Geolocator.checkPermission();
      
      final isGranted = permissionStatus.isGranted || permissionStatus.isLimited;
      final hasGeolocatorPermission = geolocatorPermission == LocationPermission.whileInUse || 
                                      geolocatorPermission == LocationPermission.always;
      
      // If permission is granted, get location coordinates and address in background
      Map<String, String>? locationData;
      if (isGranted && hasGeolocatorPermission && isServiceEnabled) {
        try {
          final position = await Geolocator.getCurrentPosition(
            desiredAccuracy: LocationAccuracy.medium,
            timeLimit: const Duration(seconds: 10),
          );
          
          // Get address using reverse geocoding
          String locationName = 'Lat: ${position.latitude.toStringAsFixed(6)}, Lng: ${position.longitude.toStringAsFixed(6)}';
          try {
            final placemarks = await placemarkFromCoordinates(
              position.latitude,
              position.longitude,
            );
            
            if (placemarks.isNotEmpty) {
              final place = placemarks.first;
              // Build address string
              final addressParts = <String>[];
              if (place.street != null && place.street!.isNotEmpty) {
                addressParts.add(place.street!);
              }
              if (place.subLocality != null && place.subLocality!.isNotEmpty) {
                addressParts.add(place.subLocality!);
              }
              if (place.locality != null && place.locality!.isNotEmpty) {
                addressParts.add(place.locality!);
              }
              if (place.administrativeArea != null && place.administrativeArea!.isNotEmpty) {
                addressParts.add(place.administrativeArea!);
              }
              if (place.country != null && place.country!.isNotEmpty) {
                addressParts.add(place.country!);
              }
              
              if (addressParts.isNotEmpty) {
                locationName = addressParts.join(', ');
              }
            }
          } catch (e) {
            // If geocoding fails, use coordinates as fallback
          }
          
          locationData = {
            'location': locationName,
            'latitude': position.latitude.toStringAsFixed(6),
            'longitude': position.longitude.toStringAsFixed(6),
          };
        } catch (e) {
          // If getting location fails, set default values
          locationData = {
            'location': 'Location unavailable',
            'latitude': '0.0',
            'longitude': '0.0',
          };
        }
      } else {
        // Permission not granted, set default values
        locationData = {
          'location': isServiceEnabled ? 'Location permission denied' : 'Location services disabled',
          'latitude': '0.0',
          'longitude': '0.0',
        };
      }
      
      state = {
        ...state,
        'location': {
          'serviceEnabled': isServiceEnabled,
          'permissionStatus': permissionStatus.toString(),
          'geolocatorPermission': geolocatorPermission.toString(),
          'isGranted': isGranted,
          'isServiceEnabled': isServiceEnabled,
          'locationData': locationData, // Store actual location coordinates
        },
      };
    } catch (e) {
      // If check fails, assume not granted
      state = {
        ...state,
        'location': {
          'serviceEnabled': false,
          'permissionStatus': 'denied',
          'geolocatorPermission': 'denied',
          'isGranted': false,
          'isServiceEnabled': false,
          'locationData': {
            'location': 'Location unavailable',
            'latitude': '0.0',
            'longitude': '0.0',
          },
        },
      };
    }
  }

  /// Update location permission and get location coordinates (called from permission screen)
  Future<void> updateLocationPermission() async {
    await _checkLocationPermission();
  }
  
  /// Get cached location data
  Map<String, String>? getLocationData() {
    final location = state['location'];
    if (location == null) return null;
    return location['locationData'] as Map<String, String>?;
  }


  /// Get cached location permission status
  bool? get isLocationGranted {
    final location = state['location'];
    if (location == null) return null;
    return location['isGranted'] as bool?;
  }

  /// Get cached location service enabled status
  bool? get isLocationServiceEnabled {
    final location = state['location'];
    if (location == null) return null;
    return location['isServiceEnabled'] as bool?;
  }

  /// Get cached Geolocator permission
  LocationPermission? getGeolocatorPermission() {
    final location = state['location'];
    if (location == null) return null;
    final permStr = location['geolocatorPermission'] as String?;
    if (permStr == null) return null;
    
    // Convert string to LocationPermission enum
    if (permStr.contains('whileInUse')) {
      return LocationPermission.whileInUse;
    } else if (permStr.contains('always')) {
      return LocationPermission.always;
    } else if (permStr.contains('deniedForever')) {
      return LocationPermission.deniedForever;
    } else {
      return LocationPermission.denied;
    }
  }
}

final permissionStatusProvider = StateNotifierProvider<PermissionStatusNotifier, Map<String, dynamic>>(
  (ref) => PermissionStatusNotifier(),
);

