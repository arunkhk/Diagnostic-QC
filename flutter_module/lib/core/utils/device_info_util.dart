import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/permission_status_provider.dart';

/// Utility class to get device information dynamically
class DeviceInfoUtil {
  static final DeviceInfoPlugin _deviceInfo = DeviceInfoPlugin();

  /// Get OS version (e.g., "Android 13" or "iOS 16.0")
  static Future<String> getOsVersion() async {
    try {
      if (Platform.isAndroid) {
        final androidInfo = await _deviceInfo.androidInfo;
        return 'Android ${androidInfo.version.release}';
      } else if (Platform.isIOS) {
        final iosInfo = await _deviceInfo.iosInfo;
        return 'iOS ${iosInfo.systemVersion}';
      }
      return 'Unknown';
    } catch (e) {
      debugPrint('Error getting OS version: $e');
      return 'Unknown';
    }
  }

  /// Get device ID (Android ID or iOS identifier)
  static Future<String> getDeviceId() async {
    try {
      if (Platform.isAndroid) {
        final androidInfo = await _deviceInfo.androidInfo;
        return androidInfo.id; // Android ID
      } else if (Platform.isIOS) {
        final iosInfo = await _deviceInfo.iosInfo;
        return iosInfo.identifierForVendor ?? 'Unknown';
      }
      return 'Unknown';
    } catch (e) {
      debugPrint('Error getting device ID: $e');
      return 'Unknown';
    }
  }

  /// Get device brand (e.g., "Samsung", "Apple", "Xiaomi")
  static Future<String> getDeviceBrand() async {
    try {
      if (Platform.isAndroid) {
        final androidInfo = await _deviceInfo.androidInfo;
        return androidInfo.brand.isNotEmpty ? androidInfo.brand : androidInfo.manufacturer;
      } else if (Platform.isIOS) {
        return 'Apple'; // All iOS devices are Apple
      }
      return 'Unknown';
    } catch (e) {
      debugPrint('Error getting device brand: $e');
      return 'Unknown';
    }
  }

  /// Get device model (e.g., "SM-G991B", "iPhone 14 Pro", "Redmi Note 10")
  static Future<String> getDeviceModel() async {
    try {
      if (Platform.isAndroid) {
        final androidInfo = await _deviceInfo.androidInfo;
        return androidInfo.model.isNotEmpty ? androidInfo.model : androidInfo.product;
      } else if (Platform.isIOS) {
        final iosInfo = await _deviceInfo.iosInfo;
        return iosInfo.model.isNotEmpty ? iosInfo.model : iosInfo.name;
      }
      return 'Unknown';
    } catch (e) {
      debugPrint('Error getting device model: $e');
      return 'Unknown';
    }
  }

  /// Get IP address (local network IP)
  static Future<String> getIpAddress() async {
    try {
      final connectivityResult = await Connectivity().checkConnectivity();
      
      if (connectivityResult.contains(ConnectivityResult.wifi) ||
          connectivityResult.contains(ConnectivityResult.ethernet)) {
        // Try to get IP from network interfaces
        for (var interface in await NetworkInterface.list()) {
          for (var addr in interface.addresses) {
            if (addr.type == InternetAddressType.IPv4 && !addr.isLoopback) {
              return addr.address;
            }
          }
        }
      }
      
      // Fallback: return default or empty
      return '0.0.0.0';
    } catch (e) {
      debugPrint('Error getting IP address: $e');
      return '0.0.0.0';
    }
  }

  /// Get current location (latitude, longitude, and location name)
  /// Uses cached location data from permission screen to avoid delays
  static Future<Map<String, String>> getLocation({WidgetRef? ref}) async {
    try {
      debugPrint('📍 Starting location retrieval...');
      
      // Try to use cached location data first (from permission screen background fetch)
      if (ref != null) {
        final cachedLocationData = ref.read(permissionStatusProvider.notifier).getLocationData();
        if (cachedLocationData != null) {
          debugPrint('✅ Using cached location data (no delay): ${cachedLocationData['location']}');
          return cachedLocationData;
        }
        debugPrint('⚠️ No cached location data available, fetching now...');
      }
      
      // Fallback: If no cached data, fetch location directly (should be rare)
      // Check if location services are enabled
      final isLocationEnabled = await Geolocator.isLocationServiceEnabled();
      debugPrint('📍 Location service enabled: $isLocationEnabled');
      
      if (!isLocationEnabled) {
        debugPrint('⚠️ Location services are disabled');
        return {
          'location': 'Location services disabled',
          'latitude': '0.0',
          'longitude': '0.0',
        };
      }

      // Check location permission
      LocationPermission permission = await Geolocator.checkPermission();
      debugPrint('📍 Current permission status: $permission');
      
      if (permission == LocationPermission.denied) {
        debugPrint('⚠️ Location permission denied');
        return {
          'location': 'Location permission denied',
          'latitude': '0.0',
          'longitude': '0.0',
        };
      }

      if (permission == LocationPermission.deniedForever) {
        debugPrint('⚠️ Location permission denied forever');
        return {
          'location': 'Location permission denied forever',
          'latitude': '0.0',
          'longitude': '0.0',
        };
      }

      // Check if permission is actually granted
      if (permission != LocationPermission.whileInUse && 
          permission != LocationPermission.always) {
        debugPrint('⚠️ Location permission not granted: $permission');
        return {
          'location': 'Location permission not granted',
          'latitude': '0.0',
          'longitude': '0.0',
        };
      }

      debugPrint('📍 Getting current position...');
      // Get current position with longer timeout and better accuracy
      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.medium,
        timeLimit: const Duration(seconds: 15),
      );

      debugPrint('✅ Location retrieved: ${position.latitude}, ${position.longitude}');

      // Get address using reverse geocoding
      String locationName = 'Lat: ${position.latitude.toStringAsFixed(6)}, Lng: ${position.longitude.toStringAsFixed(6)}';
      try {
        debugPrint('📍 Getting address from coordinates...');
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
            debugPrint('✅ Address retrieved: $locationName');
          } else {
            debugPrint('⚠️ Address parts empty, using coordinates');
          }
        } else {
          debugPrint('⚠️ No placemarks found, using coordinates');
        }
      } catch (e) {
        debugPrint('⚠️ Error getting address: $e, using coordinates');
        // Keep coordinates as fallback
      }

      return {
        'location': locationName,
        'latitude': position.latitude.toStringAsFixed(6),
        'longitude': position.longitude.toStringAsFixed(6),
      };
    } catch (e, stackTrace) {
      debugPrint('❌ Error getting location: $e');
      debugPrint('❌ Stack trace: $stackTrace');
      return {
        'location': 'Location unavailable: ${e.toString()}',
        'latitude': '0.0',
        'longitude': '0.0',
      };
    }
  }
}

