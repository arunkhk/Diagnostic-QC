import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import '../providers/permission_provider.dart';

/// Helper class for requesting permissions contextually when needed
class PermissionHelper {
  /// Request a specific permission by name
  /// Returns true if granted, false if denied
  static Future<bool> requestPermission(String permissionName) async {
    final permission = PermissionMapper.getPermission(permissionName);
    if (permission == null) {
      print('⚠️ Permission mapper returned null for: $permissionName');
      return false;
    }

    final status = await permission.request();
    return status.isGranted || status.isLimited;
  }

  /// Request multiple permissions by name
  /// Returns a map of permission names to their granted status
  static Future<Map<String, bool>> requestPermissions(
    List<String> permissionNames,
  ) async {
    final results = <String, bool>{};

    for (final permissionName in permissionNames) {
      final granted = await requestPermission(permissionName);
      results[permissionName] = granted;
    }

    return results;
  }

  /// Check if a permission is currently granted
  static Future<bool> isPermissionGranted(String permissionName) async {
    final permission = PermissionMapper.getPermission(permissionName);
    if (permission == null) return false;

    final status = await permission.status;
    return status.isGranted || status.isLimited;
  }

  /// Check if a permission is permanently denied
  static Future<bool> isPermissionPermanentlyDenied(
    String permissionName,
  ) async {
    final permission = PermissionMapper.getPermission(permissionName);
    if (permission == null) return false;

    final status = await permission.status;
    return status.isPermanentlyDenied;
  }

  /// Request permission with user-friendly messaging
  /// Shows dialog if permanently denied
  static Future<bool> requestPermissionWithDialog(
    String permissionName,
    BuildContext context, {
    String? deniedMessage,
    String? permanentlyDeniedMessage,
  }) async {
    final permission = PermissionMapper.getPermission(permissionName);
    if (permission == null) return false;

    final status = await permission.request();

    if (status.isPermanentlyDenied) {
      // Show dialog to open settings
      final shouldOpenSettings = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text('$permissionName Permission Required'),
          content: Text(
            permanentlyDeniedMessage ??
                '$permissionName permission is required for this feature. Please enable it in settings.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Open Settings'),
            ),
          ],
        ),
      );

      if (shouldOpenSettings == true) {
        await openAppSettings();
      }
    } else if (status.isDenied && deniedMessage != null) {
      // Show info message if denied (but not permanently)
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(deniedMessage),
          duration: const Duration(seconds: 2),
        ),
      );
    }

    return status.isGranted || status.isLimited;
  }
}

