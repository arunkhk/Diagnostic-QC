import 'package:permission_handler/permission_handler.dart';

/// Maps permission names to Permission enum values
class PermissionMapper {
  static Permission? getPermission(String permissionName) {
    switch (permissionName) {
      case 'Camera':
        return Permission.camera;
      case 'Microphone':
        return Permission.microphone;
      case 'Storage & Files':
        return Permission.storage;
      case 'Photos & Media':
        return Permission.photos;
      case 'Location':
        return Permission.locationWhenInUse;
      case 'Location (Always)':
        return Permission.locationAlways;
      case 'Contacts':
        return Permission.contacts;
      case 'Phone':
        return Permission.phone;
      case 'SMS':
        return Permission.sms;
      case 'Calendar':
        return Permission.calendar;
      case 'Reminders':
        return Permission.reminders;
      case 'Bluetooth':
        return Permission.bluetooth;
      case 'Bluetooth Scan':
        return Permission.bluetoothScan;
      case 'Bluetooth Connect':
        return Permission.bluetoothConnect;
      case 'Wi-Fi':
        // Wi-Fi doesn't have direct permission, use location as proxy
        return Permission.locationWhenInUse;
      case 'Notifications':
        return Permission.notification;
      case 'Body Sensors':
        return Permission.sensors;
      case 'Activity Recognition':
        return Permission.activityRecognition;
      case 'Manage Storage':
        return Permission.manageExternalStorage;
      default:
        return null;
    }
  }

  static List<Permission> getAllPermissions() {
    return [
      Permission.camera,
      Permission.bluetooth,
      Permission.microphone,
      Permission.locationWhenInUse,
      Permission.phone,
      Permission.sms,
    ];
  }

  /// Get all permission names in order (only necessary permissions)
  static List<String> getAllPermissionNames() {
    return [
      'Camera',
      'Bluetooth',
      'Microphone',
      'Location',
      'Phone',
      'SMS',
    ];
  }

  /// Get mandatory permission names (required for core functionality)
  static List<String> getMandatoryPermissionNames() {
    return [
      'Camera',
      'Bluetooth',
      'Microphone',
      'Location',
      'Phone',
      'SMS',
    ];
  }

  /// Get optional permission names (not used - all permissions are mandatory)
  static List<String> getOptionalPermissionNames() {
    return [];
  }

  /// Get all mandatory permissions
  static List<Permission> getMandatoryPermissions() {
    return getMandatoryPermissionNames()
        .map((name) => getPermission(name))
        .whereType<Permission>()
        .toList();
  }

  /// Get all optional permissions
  static List<Permission> getOptionalPermissions() {
    return getOptionalPermissionNames()
        .map((name) => getPermission(name))
        .whereType<Permission>()
        .toList();
  }
}
