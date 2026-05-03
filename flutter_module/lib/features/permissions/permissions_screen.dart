import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:geolocator/geolocator.dart';

import '../../core/constants/app_colors.dart';
import '../../core/constants/app_strings.dart';
import '../../core/constants/app_config.dart';
import '../../core/widgets/common_header.dart';
import '../../core/providers/permission_status_provider.dart';
import '../diagnosis/diagnosis_screen.dart';
import '../verification/imei_verification_screen.dart';
import 'providers/permission_provider.dart';

class PermissionsScreen extends ConsumerStatefulWidget {
  const PermissionsScreen({super.key});

  @override
  ConsumerState<PermissionsScreen> createState() => _PermissionsScreenState();
}

class _PermissionsScreenState extends ConsumerState<PermissionsScreen> with WidgetsBindingObserver {
  late final Map<String, PermissionStatus> _permissionStatuses;
  bool _isRequesting = false;
  bool? _isBluetoothEnabled;
  bool? _isLocationEnabled;
  bool _locationChecked = false;
  bool _isRequestingLocationPermission = false;
  DateTime? _lastLocationCheckTime;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // Initialize all permissions
    _permissionStatuses = {
      for (final name in PermissionMapper.getAllPermissionNames())
        name: PermissionStatus.denied
    };
    
    // Check permissions in background without blocking UI
    // Use unawaited to run in background
    _checkAllPermissions();
    _checkBluetoothState();
    _checkLocationState();
    
    // Initialize permission status provider in background (for IMEI screen)
    // This runs in background and doesn't block UI
    Future.microtask(() {
      ref.read(permissionStatusProvider.notifier).updateLocationPermission();
    });
    
    // Refresh Bluetooth state periodically
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) {
        _checkBluetoothState();
      }
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      // Re-check location when user comes back to screen
      // Add debounce to prevent excessive checks
      final now = DateTime.now();
      if (_lastLocationCheckTime == null || 
          now.difference(_lastLocationCheckTime!).inSeconds > 2) {
        _lastLocationCheckTime = now;
        _checkLocationState(showDialogIfDisabled: true);

      }
    }
  }
  Future<void> _checkBluetoothState() async {
    try {
      print('🔵 Checking Bluetooth state...');
      const platform = MethodChannel(AppConfig.bluetoothChannel);
      final dynamic result = await platform.invokeMethod('isBluetoothEnabled');
      print('🔵 Bluetooth state result: $result (type: ${result.runtimeType})');
      
      final bool isEnabled = result is bool ? result : (result ?? false);
      print('🔵 Bluetooth isEnabled: $isEnabled');
      
      if (mounted) {
        setState(() {
          _isBluetoothEnabled = isEnabled;
        });
        print('🔵 State updated: _isBluetoothEnabled = $_isBluetoothEnabled');
      }
    } catch (e, stackTrace) {
      print('⚠️ Error checking Bluetooth state: $e');
      print('⚠️ Stack trace: $stackTrace');
      // If platform channel fails, assume unknown state
      if (mounted) {
        setState(() {
          _isBluetoothEnabled = null;
        });
      }
    }
  }

  Future<void> _checkLocationState({bool showDialogIfDisabled = false}) async {
    // Prevent concurrent checks
    if (_isRequestingLocationPermission) {
      print('📍 Location permission request already in progress, skipping check');
      return;
    }

    try {
      print('📍 Checking Location service and permission...');
      
      // Check if location services are enabled
      final bool isServiceEnabled = await Geolocator.isLocationServiceEnabled();
      print('📍 Location service enabled: $isServiceEnabled');
      
      // Check location permission status
      final locationPermission = Permission.locationWhenInUse;
      final permissionStatus = await locationPermission.status;
      final bool isPermissionGranted = permissionStatus.isGranted || permissionStatus.isLimited;
      print('📍 Location permission granted: $isPermissionGranted (status: $permissionStatus)');
      
      // Location is considered enabled only if both service is enabled AND permission is granted
      final bool isLocationFullyEnabled = isServiceEnabled && isPermissionGranted;
      
      if (mounted) {
        setState(() {
          _isLocationEnabled = isLocationFullyEnabled;
          _locationChecked = true;
          // Update permission status in the map
          _permissionStatuses['Location'] = permissionStatus;
        });
        
        // Show dialog if location service is disabled
        if (showDialogIfDisabled && !isServiceEnabled) {
          _showLocationDisabledDialog();
        }
        // Request permission if service is enabled but permission not granted
        // Only request if not already requesting and permission is not permanently denied
        else if (isServiceEnabled && 
                 !isPermissionGranted && 
                 !_isRequestingLocationPermission &&
                 !permissionStatus.isPermanentlyDenied) {
          print('📍 Location service enabled but permission not granted - requesting permission');
          await _requestLocationPermission();
        }
        
        print('📍 State updated: _isLocationEnabled = $_isLocationEnabled');
      }
    } catch (e, stackTrace) {
      print('⚠️ Error checking Location state: $e');
      print('⚠️ Stack trace: $stackTrace');
      // If check fails, assume enabled (don't block user)
      if (mounted) {
        setState(() {
          _isLocationEnabled = true; // Assume enabled to not block
          _locationChecked = true;
        });
      }
    }
  }

  Future<void> _requestLocationPermission() async {
    // Prevent multiple simultaneous requests
    if (_isRequestingLocationPermission) {
      print('📍 Location permission request already in progress');
      return;
    }

    try {
      _isRequestingLocationPermission = true;
      print('📍 Requesting location permission...');
      
      final locationPermission = Permission.locationWhenInUse;
      final status = await locationPermission.request();
      
      print('📍 Location permission request result: $status');
      
      if (mounted) {
        // Update permission status in the map
        setState(() {
          _permissionStatuses['Location'] = status;
          // Update location enabled state based on permission status
          if (status.isGranted || status.isLimited) {
            _isLocationEnabled = true;
          } else {
            _isLocationEnabled = false;
          }
        });
        
        // Update permission status provider in background (for IMEI screen to use)
        ref.read(permissionStatusProvider.notifier).updateLocationPermission();
        
        // Refresh all permissions to ensure accuracy
        await _checkAllPermissions();
        
        // Don't recursively call _checkLocationState() to avoid infinite loop
        // The state is already updated above
      }
    } catch (e) {
      print('⚠️ Error requesting location permission: $e');
    } finally {
      _isRequestingLocationPermission = false;
    }
  }

  void _showLocationDisabledDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('Location Services Disabled'),
        content: const Text(
          'Location services are currently disabled. Please enable location services to continue.',
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              // Mark as fail and navigate forward
              _navigateToDiagnosis();
            },
            child: const Text('No'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              // Open location settings using geolocator
              try {
                await Geolocator.openLocationSettings();
              } catch (e) {
                print('⚠️ Error opening location settings: $e');
                // Fallback to app settings
                await openAppSettings();
              }
            },
            child: const Text('Open'),
          ),
        ],
      ),
    );
  }

  Future<void> _checkAllPermissions() async {
    final statuses = <String, PermissionStatus>{};
    
    for (final permissionName in PermissionMapper.getAllPermissionNames()) {
      final permission = PermissionMapper.getPermission(permissionName);
      if (permission != null) {
        final status = await permission.status;
        statuses[permissionName] = status;
      }
    }
    
    if (mounted) {
      setState(() {
        _permissionStatuses.addAll(statuses);
      });
    }
  }

  bool get _allMandatoryPermissionsGranted {
    final mandatoryNames = PermissionMapper.getMandatoryPermissionNames();
    return mandatoryNames.every(
      (name) {
        final status = _permissionStatuses[name] ?? PermissionStatus.denied;
        return status.isGranted || status.isLimited;
      },
    );
  }

  bool get _allPermissionsGranted {
    return _permissionStatuses.values.every(
      (status) => status.isGranted || status.isLimited,
    );
  }

  Future<void> _requestPermission(String permissionName) async {
    final permission = PermissionMapper.getPermission(permissionName);
    if (permission == null) return;

    final status = await permission.request();
    
    // Refresh all permissions to ensure accurate status (especially for location)
    await _checkAllPermissions();
    
    if (mounted) {
      setState(() {
        _permissionStatuses[permissionName] = status;
      });
    }

    // If denied permanently, show dialog to open settings
    if (status.isPermanentlyDenied) {
      _showPermissionDeniedDialog(permissionName);
    }
  }

  Future<void> _requestAllPermissions() async {
    print('🔵 _requestAllPermissions called');
    
    if (_isRequesting) {
      print('⚠️ Already requesting, returning early');
      return;
    }

    print('✅ Setting _isRequesting to true');
    setState(() {
      _isRequesting = true;
    });

    try {
      final updatedStatuses = <String, PermissionStatus>{};
      
      // Check all permissions status first (parallel)
      final mandatoryNames = PermissionMapper.getMandatoryPermissionNames();
      print('📋 Found ${mandatoryNames.length} mandatory permissions to request');
      
      // Check status of all permissions in parallel
      final statusChecks = await Future.wait(
        mandatoryNames.map((permissionName) async {
          final permission = PermissionMapper.getPermission(permissionName);
          if (permission != null) {
            try {
              final status = await permission.status;
              return MapEntry(permissionName, status);
            } catch (e) {
              print('❌ Error checking status for $permissionName: $e');
              return MapEntry(permissionName, PermissionStatus.denied);
            }
          }
          return MapEntry(permissionName, PermissionStatus.denied);
        }),
      );
      
      // Process status checks
      final statusMap = Map<String, PermissionStatus>.fromEntries(statusChecks);
      final permissionsToRequest = <String>[];
      
      for (final entry in statusMap.entries) {
        final permissionName = entry.key;
        final status = entry.value;
        
        if (status.isGranted || status.isLimited) {
          print('✅ $permissionName already granted, skipping');
          updatedStatuses[permissionName] = status;
        } else if (status.isPermanentlyDenied) {
          print('⚠️ $permissionName is permanently denied - user needs to enable in settings');
          updatedStatuses[permissionName] = status;
        } else {
          permissionsToRequest.add(permissionName);
        }
      }
      
      // Request only permissions that need dialogs (sequential, but faster)
      for (final permissionName in permissionsToRequest) {
        print('🔐 Requesting mandatory permission: $permissionName');
        final permission = PermissionMapper.getPermission(permissionName);
        if (permission != null) {
          try {
            // Special handling for Location permission
            if (permissionName == 'Location') {
              print('📍 Special handling for Location permission');
              // Ensure location service is enabled first
              final isServiceEnabled = await Geolocator.isLocationServiceEnabled();
              if (!isServiceEnabled) {
                print('⚠️ Location service is disabled, cannot request permission');
                updatedStatuses[permissionName] = PermissionStatus.denied;
                continue;
              }
            }
            
            print('🔔 Calling request() for $permissionName - dialog should appear');
            final status = await permission.request();
            print('✅ $permissionName status after request: $status');
            updatedStatuses[permissionName] = status;
            
            // For Location, also verify with Geolocator
            if (permissionName == 'Location') {
              final geolocatorPermission = await Geolocator.checkPermission();
              print('📍 Geolocator permission status: $geolocatorPermission');
            }
            
            // Minimal delay only if dialog was shown (not needed if already granted)
            if (!status.isGranted && !status.isLimited) {
              await Future.delayed(const Duration(milliseconds: 200));
            }
          } catch (e) {
            print('❌ Error requesting $permissionName: $e');
            updatedStatuses[permissionName] = PermissionStatus.denied;
          }
        }
      }

      // Optional permissions are not requested (empty list)

      print('📊 Updated ${updatedStatuses.length} permission statuses');

      // Refresh all permission statuses to ensure accuracy (especially for location)
      await _checkAllPermissions();

      if (mounted) {
        setState(() {
          _permissionStatuses.addAll(updatedStatuses);
          _isRequesting = false;
        });
        print('✅ State updated, _isRequesting set to false');
      } else {
        print('⚠️ Widget not mounted, skipping setState');
      }

      // Check if any mandatory are permanently denied
      final mandatoryDenied = mandatoryNames.any((name) {
        final status = updatedStatuses[name] ?? PermissionStatus.denied;
        return status.isPermanentlyDenied;
      });
      
      final deniedCount = updatedStatuses.values.where((s) => s.isDenied || s.isPermanentlyDenied).length;
      
      if (mounted && deniedCount > 0) {
        print('⚠️ $deniedCount permission(s) denied - user can continue');
        // Show info message but don't block - permissions can be requested later
        if (mandatoryDenied) {
          // Only show dialog for permanently denied mandatory permissions
          _showPermissionInfoDialog(deniedCount);
        }
      }
    } catch (e, stackTrace) {
      print('❌ Exception in _requestAllPermissions: $e');
      print('Stack trace: $stackTrace');
      if (mounted) {
        setState(() {
          _isRequesting = false;
        });
      }
    }
  }

  void _showPermissionDeniedDialog(String permissionName) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text(AppStrings.permissionRequired),
        content: Text(
          AppStrings.permissionDeniedIndividualMessage.replaceAll(
            '{permission}',
            permissionName,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text(AppStrings.cancelButton),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              openAppSettings();
            },
            child: const Text(AppStrings.openSettingsButton),
          ),
        ],
      ),
    );
  }

  void _showSettingsDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text(AppStrings.permissionsRequired),
        content: const Text(AppStrings.permissionDeniedMessage),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text(AppStrings.cancelButton),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              openAppSettings();
            },
            child: const Text(AppStrings.openSettingsButton),
          ),
        ],
      ),
    );
  }

  void _showPermissionInfoDialog(int deniedCount) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text(AppStrings.somePermissionsDenied),
        content: Text(
          AppStrings.permissionDeniedInfoMessage.replaceAll(
            '{count}',
            deniedCount.toString(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text(AppStrings.continueButton),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              openAppSettings();
            },
            child: const Text(AppStrings.openSettingsButton),
          ),
        ],
      ),
    );
  }

  void _navigateToDiagnosis() {
    // Always allow navigation - permissions can be requested later when needed
    // Navigate to IMEI verification screen first (add to stack)
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => const ImeiVerificationScreen(),
      ),
    );
  }

  IconData _getPermissionIcon(String permissionName) {
    switch (permissionName) {
      case 'Camera':
        return Icons.camera_alt;
      case 'Microphone':
        return Icons.mic;
      case 'Storage & Files':
        return Icons.storage;
      case 'Location':
        return Icons.location_on;
      case 'Phone':
        return Icons.phone;
      case 'SMS':
        return Icons.sms;
      case 'Bluetooth':
        return Icons.bluetooth;
      default:
        return Icons.settings;
    }
  }

  void _handleSkip() {
    // Always navigate to IMEI screen when skip is pressed
    Navigator.of(context).pushReplacement(
      MaterialPageRoute<void>(
        builder: (_) => const ImeiVerificationScreen(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (bool didPop, dynamic result) {
        // Prevent back navigation - use skip button instead
        if (!didPop) {
          // Optionally navigate to IMEI screen on system back button
          _handleSkip();
        }
      },
      child: Scaffold(
        backgroundColor: AppColors.background,
        body: SafeArea(
          child: Column(
            children: [
            /// Common Header (no back button, skip button always visible)
            CommonHeader(
              title: AppStrings.welcomeTitle,
              version: AppStrings.appVersion,
              onBack: null, // Disable back button
              onSkip: _handleSkip, // Always show skip button
              skipText: 'Skip >>',
            ),
          const SizedBox(height: 16),

          /// Top Image
          Image.asset(
            AppStrings.image26Path,
            height: 160,
            fit: BoxFit.contain,
            errorBuilder: (_, __, ___) => const SizedBox(height: 160),
          ),

          const SizedBox(height: 20),

          /// Title
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Text(
              AppStrings.permissionsMainTitle,
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: AppColors.text,
                  ),
              textAlign: TextAlign.center,
            ),
          ),

          const SizedBox(height: 8),

          /// Subtitle
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Column(
              children: [
                Text(
                  AppStrings.permissionsSubtitle,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        fontSize: 14,
                        color: AppColors.textSecondary,
                        height: 1.4,
                      ),
                  textAlign: TextAlign.center,
                ),

              ],
            ),
          ),

          const SizedBox(height: 24),

          /// Permission List
          Expanded(
            child: _PermissionList(
              permissionStatuses: _permissionStatuses,
              getIcon: _getPermissionIcon,
              isBluetoothEnabled: _isBluetoothEnabled,
            ),
          ),

          /// Bottom Button
          Padding(
            padding: const EdgeInsets.all(16),
            child: SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton(
                onPressed: _isRequesting
                    ? null
                    : () async {
                        print('🔘 Button pressed!');
                        print('_isRequesting: $_isRequesting');
                        print('_allPermissionsGranted: $_allPermissionsGranted');
                        
                        if (_isRequesting) {
                          print('⚠️ Button disabled - already requesting');
                          return;
                        }
                        
                        // Check location first (service + permission)
                        await _checkLocationState(showDialogIfDisabled: true);
                        
                        // If location service is disabled, dialog already shown - wait for user action
                        if (_isLocationEnabled == false) {
                          final bool isServiceEnabled = await Geolocator.isLocationServiceEnabled();
                          if (!isServiceEnabled) {
                            // Dialog already shown by _checkLocationState, just return
                            return;
                          }
                          // If service enabled but permission denied, permission request already handled
                          // Continue with normal flow
                        }
                        
                        // First try to request permissions, then navigate
                        // Check if mandatory permissions are granted
                        if (!_allMandatoryPermissionsGranted) {
                          print('🔐 Requesting all permissions (mandatory first)');
                          // Request permissions and navigate after completion
                          _requestAllPermissions().then((_) {
                            if (mounted) {
                              print('✅ Navigating to diagnosis after permission requests');
                              _navigateToDiagnosis();
                            }
                          });
                        } else {
                          print('✅ All mandatory permissions granted, navigating to diagnosis');
                          _navigateToDiagnosis();
                        }
                      },
                style: ElevatedButton.styleFrom(
                  backgroundColor: _isRequesting
                      ? AppColors.disabled
                      : (_allMandatoryPermissionsGranted
                          ? AppColors.primaryDark
                          : AppColors.primary),
                  disabledBackgroundColor: AppColors.disabled,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                child: Text(
                  _isRequesting
                      ? AppStrings.requestingPermissions
                      : (_allMandatoryPermissionsGranted
                          ? AppStrings.continueButton
                          : AppStrings.grantPermissionButton),
                  style: const TextStyle(
                    fontSize: 16,
                    color: Colors.white,
                  ),
                ),
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

class _PermissionList extends StatelessWidget {
  const _PermissionList({
    required this.permissionStatuses,
    required this.getIcon,
    this.isBluetoothEnabled,
  });

  final Map<String, PermissionStatus> permissionStatuses;
  final IconData Function(String) getIcon;
  final bool? isBluetoothEnabled;

  @override
  Widget build(BuildContext context) {
    final mandatoryNames = PermissionMapper.getMandatoryPermissionNames();
    
    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      children: [
        // Mandatory Permissions Section (only necessary permissions)
        if (mandatoryNames.isNotEmpty) ...[
          Padding(
            padding: const EdgeInsets.only(top: 8, bottom: 12),
            child: Text(
              AppStrings.requiredPermissions,
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppColors.text,
                  ),
            ),
          ),
          ...mandatoryNames.map((permissionName) => _PermissionTile(
                icon: getIcon(permissionName),
                title: permissionName,
                status: permissionStatuses[permissionName] ?? PermissionStatus.denied,
                isMandatory: true,
                isBluetoothPermission: permissionName.toLowerCase().contains('bluetooth'),
                isBluetoothEnabled: permissionName.toLowerCase().contains('bluetooth') 
                    ? isBluetoothEnabled
                    : null,
              )),
          const SizedBox(height: 16),
        ],
      ],
    );
  }
}

class _PermissionTile extends StatelessWidget {
  const _PermissionTile({
    required this.icon,
    required this.title,
    required this.status,
    this.isMandatory = false,
    this.isBluetoothPermission = false,
    this.isBluetoothEnabled,
  });

  final IconData icon;
  final String title;
  final PermissionStatus status;
  final bool isMandatory;
  final bool isBluetoothPermission;
  final bool? isBluetoothEnabled;

  bool get isGranted => status.isGranted || status.isLimited;
  
  bool get showBluetoothWarning {
    final shouldShow = isBluetoothPermission && isBluetoothEnabled == false;
    if (isBluetoothPermission) {
      print('🔵 Bluetooth permission: $title, enabled: $isBluetoothEnabled, showWarning: $shouldShow');
    }
    return shouldShow;
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        ListTile(
          contentPadding: EdgeInsets.zero,
          enabled: false,
          leading: Icon(
            icon,
            color: isGranted ? AppColors.success : AppColors.text,
          ),
          title: Row(
            children: [
              Expanded(
                child: Text(
                  title,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        fontSize: 14,
                        color: AppColors.text,
                        fontWeight: isMandatory ? FontWeight.w500 : FontWeight.normal,
                      ),
                ),
              ),
              if (isMandatory)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    AppStrings.requiredBadge,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          fontSize: 10,
                          color: AppColors.primary,
                          fontWeight: FontWeight.w600,
                        ),
                  ),
                ),
            ],
          ),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (showBluetoothWarning)
                Tooltip(
                  message: 'Bluetooth is turned off on your device',
                  child: Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: Icon(
                      Icons.bluetooth_disabled,
                      color: Colors.orange,
                      size: 24,
                    ),
                  ),
                ),
              if (isGranted && !showBluetoothWarning)
                Icon(
                  Icons.check_circle,
                  color: AppColors.success,
                  size: 20,
                ),
            ],
          ),
        ),
        Divider(
          height: 1,
          color: AppColors.divider,
        ),
      ],
    );
  }
}
