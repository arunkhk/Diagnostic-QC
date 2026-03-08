import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:cached_network_image/cached_network_image.dart';

import '../../core/constants/app_colors.dart';
import '../../core/constants/app_strings.dart';
import '../../core/constants/app_config.dart';
import '../../core/widgets/common_header.dart';
import '../../core/widgets/common_dialog.dart';
import '../../core/widgets/common_toast.dart';
import '../../core/utils/progress_calculator.dart';
import '../permissions/utils/permission_helper.dart';
import 'utils/test_result_helper.dart';
import 'utils/test_config.dart';
import 'providers/test_parameters_provider.dart' show testParametersProvider, getAndResetFallbackToastFlag;
import 'providers/test_images_provider.dart';
import 'utils/test_navigation_service.dart';
import 'models/test_parameter_item.dart';
import 'models/test_result.dart';

class DiagnosisScreen extends ConsumerStatefulWidget {
  const DiagnosisScreen({super.key});


  @override
  ConsumerState<DiagnosisScreen> createState() => _DiagnosisScreenState();
}
class _DiagnosisScreenState extends ConsumerState<DiagnosisScreen> {
  final Connectivity _connectivity = Connectivity();
  bool _wifiEnabled = false;
  bool _wifiTesting = false; // Start as false, will be true when testing starts
  bool _showWifiCard = false; // Control WiFi card visibility
  bool _bluetoothConnected = false;
  bool _bluetoothTesting = false; // Start as false, will be true when testing starts
  bool _showBluetoothCard = false; // Control Bluetooth card visibility
  bool _gpsDiagnosing = false; // Start as false, will be true when testing starts
  bool _showGpsCard = false; // Control GPS card visibility
  bool _gpsEnabled = false; // Track GPS/location enabled state
  int _wifiNetworksFound = 0;
  double _progress = ProgressCalculator.getProgressForScreen('diagnosis'); // Dynamic progress for screen 31 (100%)
  bool _isLoadingTestParameters = false; // Track loading state for test parameters API

  @override
  void initState() {
    super.initState();
    _requestPermissionsIfNeeded();
    // Initialize test parameters first, then tests after build completes (to avoid modifying provider during build)
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      // Initialize test parameters provider first (like API call)
      // This happens when user clicks Continue on IMEI dialog
      final success = await _initializeTestParameters();
      
      // Only proceed if API call was successful
      if (success && mounted) {
        // Then initialize tests after parameters are loaded
        _initializeTests();
        // Show diagnosis dialog only if parameters loaded successfully
        _showDiagnosisDialog();
      } else if (mounted) {
        // Show error dialog if API call failed
        _showErrorDialog();
      }
    });
  }
  /// Initialize test parameters provider (treats it like API call)
  /// This is called once when DiagnosisScreen is created (after IMEI Continue click)
  /// Provider automatically fetches when subscriptionId is available (watches auth provider)
  /// Waits for the provider to have a value before returning
  /// Returns true if successful, false if error
  Future<bool> _initializeTestParameters() async {
    if (!mounted) return false;
    
    // Set loading state to show progress indicator
    setState(() {
      _isLoadingTestParameters = true;
    });
    
    // Provider automatically fetches when subscriptionId changes (no need to invalidate)
    // Just wait for the provider to have a value (API call to complete)
    try {
      debugPrint('═══════════════════════════════════════════════════════════');
      debugPrint('🔄 DiagnosisScreen: Waiting for test parameters from API...');
      debugPrint('═══════════════════════════════════════════════════════════');
      
      final testParameters = await ref.read(testParametersProvider.future);
      
      debugPrint('═══════════════════════════════════════════════════════════');
      debugPrint('📥 DiagnosisScreen: Received ${testParameters.length} test parameters');
      debugPrint('═══════════════════════════════════════════════════════════');
      
      // Check if fallback to local JSON was used and show toast
      if (getAndResetFallbackToastFlag() && mounted) {
        CommonToast.showWarning(
          context,
          message: 'API failed. Using local test parameters.',
          duration: const Duration(seconds: 4),
        );
      }
      
      // Check if we got valid test parameters
      if (testParameters.isEmpty) {
        debugPrint('❌ DiagnosisScreen: API returned empty test parameters list');
        debugPrint('   This means the API call succeeded but returned no test parameters');
        debugPrint('   Check the API response logs above for details');
        if (mounted) {
          setState(() {
            _isLoadingTestParameters = false;
          });
        }
        return false;
      }
      
      debugPrint('✅ DiagnosisScreen: Test parameters loaded (${testParameters.length} items)');
      if (mounted) {
        setState(() {
          _isLoadingTestParameters = false;
        });
      }
      return true;
    } catch (e) {
      debugPrint('❌ DiagnosisScreen: Error loading test parameters: $e');
      if (mounted) {
        setState(() {
          _isLoadingTestParameters = false;
        });
      }
      return false;
    }
  }
  
  /// Show error dialog when API call fails
  Future<void> _showErrorDialog() async {
    if (!mounted) return;
    
    await CommonDialog.showDeviceDiagnosisDialog(
      context,
      title: 'Error',
      message: 'Failed to load test parameters. Please check your internet connection and try again.',
      isDismissible: true,
      cancelText: AppStrings.cancelButton,
      proceedText: 'Retry',
      onProceed: () async {
        // Invalidate provider to force fresh API call on retry
        ref.invalidate(testParametersProvider);
        debugPrint('🔄 Retrying: Invalidated testParametersProvider for fresh API call');
        
        // Retry loading test parameters
        final success = await _initializeTestParameters();
        if (success && mounted) {
          _initializeTests();
          _showDiagnosisDialog();
        } else if (mounted) {
          _showErrorDialog();
        }
      },
      onCancel: () {
        // Go back if user cancels
        Navigator.of(context).pop();
      },
    );
  }

  /// Initialize WiFi, Bluetooth, and Location tests as pending
  /// Should be called AFTER test parameters are loaded
  void _initializeTests() {
    if (!mounted) return;
    
    // Get test parameters to find the actual uniqueTestKeys from API
    final testParametersAsync = ref.read(testParametersProvider);
    if (!testParametersAsync.hasValue) {
      debugPrint('⚠️ Cannot initialize tests: test parameters not loaded yet');
      return;
    }
    
    final parameters = testParametersAsync.value!;
    
    // Find WiFi, Bluetooth, and Location tests from API response
    // Use case-insensitive search to handle API variations
    TestParameterItem? wifiParam;
    TestParameterItem? bluetoothParam;
    TestParameterItem? locationParam;
    
    // Try to find WiFi test
    try {
      wifiParam = parameters.firstWhere(
        (p) => p.uniqueTestKey.toLowerCase() == TestConfig.testIdWifi.toLowerCase(),
      );
    } catch (e) {
      try {
        wifiParam = parameters.firstWhere(
          (p) => p.paramValue.toLowerCase().contains('wifi') || p.paramValue.toLowerCase().contains('wi-fi'),
        );
      } catch (e2) {
        debugPrint('⚠️ WiFi test not found in API response');
      }
    }
    
    // Try to find Bluetooth test
    try {
      bluetoothParam = parameters.firstWhere(
        (p) => p.uniqueTestKey.toLowerCase() == TestConfig.testIdBluetooth.toLowerCase(),
      );
    } catch (e) {
      try {
        bluetoothParam = parameters.firstWhere(
          (p) => p.paramValue.toLowerCase().contains('bluetooth'),
        );
      } catch (e2) {
        debugPrint('⚠️ Bluetooth test not found in API response');
      }
    }
    
    // Try to find Location/GPS test
    try {
      locationParam = parameters.firstWhere(
        (p) => p.uniqueTestKey.toLowerCase() == TestConfig.testIdLocation.toLowerCase() ||
               p.uniqueTestKey.toLowerCase() == 'gps' ||
               p.uniqueTestKey.toLowerCase() == 'location',
      );
    } catch (e) {
      try {
        locationParam = parameters.firstWhere(
          (p) => p.paramValue.toLowerCase().contains('gps') || p.paramValue.toLowerCase().contains('location'),
        );
      } catch (e2) {
        debugPrint('⚠️ Location/GPS test not found in API response');
      }
    }
    
    // Initialize tests using the actual uniqueTestKeys from API (only if found)
    if (wifiParam != null) {
      TestResultHelper.saveTestResultFromParameter(ref, wifiParam, TestStatus.pending);
      debugPrint('✅ Initialized WiFi test: ${wifiParam.uniqueTestKey}');
    }
    if (bluetoothParam != null) {
      TestResultHelper.saveTestResultFromParameter(ref, bluetoothParam, TestStatus.pending);
      debugPrint('✅ Initialized Bluetooth test: ${bluetoothParam.uniqueTestKey}');
    }
    if (locationParam != null) {
      TestResultHelper.saveTestResultFromParameter(ref, locationParam, TestStatus.pending);
      debugPrint('✅ Initialized Location test: ${locationParam.uniqueTestKey}');
    }
    
    // Log available tests for debugging if any are missing
    if (wifiParam == null || bluetoothParam == null || locationParam == null) {
      debugPrint('📋 Available tests in API: ${parameters.map((p) => '${p.paramValue}(${p.uniqueTestKey})').join(", ")}');
    }
  }

  Future<void> _showDiagnosisDialog() async {
    // Show dialog when screen loads
    await Future.delayed(const Duration(milliseconds: 500));
    if (mounted) {
      await CommonDialog.showDeviceDiagnosisDialog(
        context,
        title: AppStrings.deviceDiagnosisTitle,
        message: AppStrings.deviceDiagnosisMessage,
        isDismissible: true,
        cancelText: AppStrings.cancelButton,
        proceedText: AppStrings.proceedButton,
        onProceed: () {
          // Start diagnosis sequence only when proceed button is clicked
          _startDiagnosisSequence();
        },
      );
    }
  }

  Future<void> _requestPermissionsIfNeeded() async {
    // Request location permission for GPS
    final locationGranted = await PermissionHelper.isPermissionGranted('Location');
    if (!locationGranted) {
      await PermissionHelper.requestPermission('Location');
    }
  }

  /// Helper method to get test parameters, waiting for data if needed
  Future<List<TestParameterItem>?> _getTestParameters() async {
    final testParametersAsyncValue = ref.read(testParametersProvider);
    
    if (testParametersAsyncValue.hasValue) {
      final params = testParametersAsyncValue.value!;
      debugPrint('✅ DiagnosisScreen: Got ${params.length} test parameters');
      debugPrint('🔍 Parameter order: ${params.map((p) => '${p.paramValue}(${p.displayOrder})').join(' → ')}');
      return params;
    } else {
      debugPrint('⏳ DiagnosisScreen: Test parameters still loading, waiting...');
      // If still loading, wait a bit and try again
      await Future.delayed(const Duration(milliseconds: 200));
      final updatedValue = ref.read(testParametersProvider);
      if (updatedValue.hasValue) {
        final params = updatedValue.value!;
        debugPrint('✅ DiagnosisScreen: Got ${params.length} test parameters after wait');
        debugPrint('🔍 Parameter order: ${params.map((p) => '${p.paramValue}(${p.displayOrder})').join(' → ')}');
        return params;
      }
    }
    debugPrint('❌ DiagnosisScreen: Failed to get test parameters');
    return null;
  }

  Future<void> _startDiagnosisSequence() async {
    // Always execute in fixed order: WiFi → Bluetooth → GPS
    await _testWifi();
    await Future.delayed(const Duration(seconds: 0));
    await _testBluetooth();
    await Future.delayed(const Duration(seconds: 0));
    await _testGps(shouldNavigate: false);
    
    // After all three tests are complete, navigate to next test after GPS
    await Future.delayed(const Duration(milliseconds: 500));
    if (mounted) {
      final testParameters = await _getTestParameters();
      if (testParameters != null) {
        // Navigate to next test after GPS (location)
        TestNavigationService.navigateToNextTest(
          context,
          testParameters,
          TestConfig.testIdLocation,
        );
      }
    }
  }

  Future<void> _testWifi() async {
    setState(() {
      _showWifiCard = true; // Show WiFi card
      _wifiTesting = true;
    });

    // Simulate 3 second test
    await Future.delayed(
      Duration(seconds: AppConstants.diagnosisTestDurationSeconds),
    );

    // Check actual Wi-Fi connectivity
    final connectivityResult = await _connectivity.checkConnectivity();
    
    // Get actual WiFi networks count
    int wifiNetworksCount = 0;
    if (connectivityResult.contains(ConnectivityResult.wifi)) {
      try {
        const platform = MethodChannel(AppConfig.wifiChannel);
        wifiNetworksCount = await platform.invokeMethod('getWifiNetworksCount') ?? 0;
      } catch (e) {
        print('⚠️ Error getting WiFi networks count: $e');
        // Fallback to default if scan fails
        wifiNetworksCount = AppConstants.defaultWifiNetworksCount;
      }
    }
    
    if (mounted) {
      setState(() {
        _wifiEnabled = connectivityResult.contains(ConnectivityResult.wifi);
        _wifiTesting = false;
        _wifiNetworksFound = wifiNetworksCount;
        // Update progress dynamically
        _progress = ProgressCalculator.getProgressForScreen('diagnosis');
      });
      
      // Save WiFi test result
      if (_wifiEnabled) {
        TestResultHelper.savePass(ref, TestConfig.testIdWifi);
      } else {
        TestResultHelper.saveFail(ref, TestConfig.testIdWifi);
      }
    }
  }

  Future<void> _testBluetooth() async {
    setState(() {
      _showBluetoothCard = true; // Show Bluetooth card
      _bluetoothTesting = true;
    });

    // Simulate 3 second test
    await Future.delayed(
      Duration(seconds: AppConstants.diagnosisTestDurationSeconds),
    );

    // Check if Bluetooth is enabled
    final isBluetoothEnabled = await _isBluetoothEnabled();
    
    if (mounted) {
      setState(() {
        _bluetoothConnected = isBluetoothEnabled; // Set based on actual Bluetooth state
        _bluetoothTesting = false;
        // Update progress dynamically
        _progress = ProgressCalculator.getProgressForScreen('diagnosis');
      });
      
      // Save Bluetooth test result
      if (_bluetoothConnected) {
        TestResultHelper.savePass(ref, TestConfig.testIdBluetooth);
      } else {
        TestResultHelper.saveFail(ref, TestConfig.testIdBluetooth);
      }
    }
  }

  Future<bool> _isBluetoothEnabled() async {
    try {
      const platform = MethodChannel(AppConfig.bluetoothChannel);
      final dynamic result = await platform.invokeMethod('isBluetoothEnabled');
      // Handle both bool and int (0/1) from platform channels
      if (result is bool) {
        return result;
      } else if (result is int) {
        return result == 1;
      } else {
        return result ?? false;
      }
    } catch (e) {
      print('⚠️ Error checking Bluetooth state: $e');
      return false;
    }
  }

  Future<void> _testGps({bool shouldNavigate = true}) async {
    setState(() {
      _showGpsCard = true; // Show GPS card
      _gpsDiagnosing = true;
    });

    // Simulate 3 second test
    await Future.delayed(
      Duration(seconds: AppConstants.diagnosisTestDurationSeconds),
    );

    // Check if location services are enabled
    bool isLocationEnabled = false;
    try {
      isLocationEnabled = await Geolocator.isLocationServiceEnabled();
    } catch (e) {
      print('⚠️ Error checking location service: $e');
      isLocationEnabled = false;
    }

    if (mounted) {
      setState(() {
        _gpsEnabled = isLocationEnabled;
        _gpsDiagnosing = false;
        // Update progress dynamically
        _progress = ProgressCalculator.getProgressForScreen('diagnosis');
      });
      
      // Save Location/GPS test result
      if (isLocationEnabled) {
        TestResultHelper.savePass(ref, TestConfig.testIdLocation);
      } else {
        TestResultHelper.saveFail(ref, TestConfig.testIdLocation);
      }

      // If location is disabled, show dialog
      if (!isLocationEnabled) {
        _showLocationDisabledDialog();
      } else if (shouldNavigate) {
        // Only navigate if shouldNavigate is true (for cases where GPS is called directly)
        await Future.delayed(const Duration(milliseconds: 500));
        if (mounted) {
          final testParameters = await _getTestParameters();
          if (testParameters != null) {
            TestNavigationService.navigateToNextTest(
              context,
              testParameters,
              TestConfig.testIdLocation,
            );
          }
        }
      }
    }
  }

  Future<void> _showLocationDisabledDialog() async {
    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('Location Services Disabled'),
        content: const Text(
          'Location services are currently disabled. Please enable location services to continue.',
        ),
        actions: [
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              // Mark location as fail
              TestResultHelper.saveFail(ref, TestConfig.testIdLocation);
              
              // Navigate to next test after GPS (location)
              final testParameters = await _getTestParameters();
              if (testParameters != null) {
                TestNavigationService.navigateToNextTest(
                  context,
                  testParameters,
                  TestConfig.testIdLocation,
                );
              }
            },
            child: const Text('No'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              // Open location settings
              try {
                await Geolocator.openLocationSettings();
                // Re-check location after user returns
                Future.delayed(const Duration(milliseconds: 500), () {
                  if (mounted) {
                    _recheckLocationAndNavigate();
                  }
                });
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

  Future<void> _recheckLocationAndNavigate() async {
    try {
      final isLocationEnabled = await Geolocator.isLocationServiceEnabled();
      if (mounted) {
        setState(() {
          _gpsEnabled = isLocationEnabled;
        });
        
        // Update location test result
        if (isLocationEnabled) {
          TestResultHelper.savePass(ref, TestConfig.testIdLocation);
        } else {
          TestResultHelper.saveFail(ref, TestConfig.testIdLocation);
        }
        
        // Navigate to next test after GPS (location)
        final testParameters = await _getTestParameters();
        if (testParameters != null) {
          TestNavigationService.navigateToNextTest(
            context,
            testParameters,
            TestConfig.testIdLocation,
          );
        }
      }
    } catch (e) {
      print('⚠️ Error rechecking location: $e');
      if (mounted) {
        final testParameters = await _getTestParameters();
        if (testParameters != null) {
          TestNavigationService.navigateToNextTest(
            context,
            testParameters,
            TestConfig.testIdLocation,
          );
        }
      }
    }
  }


  Future<void> _handleSkip() async {
    // Mark all tests as skipped when skip button is pressed
    TestResultHelper.saveSkip(ref, TestConfig.testIdWifi);
    TestResultHelper.saveSkip(ref, TestConfig.testIdBluetooth);
    TestResultHelper.saveSkip(ref, TestConfig.testIdLocation);

    // Navigate to next test after GPS (location)
    final testParameters = await _getTestParameters();
    if (testParameters != null) {
      TestNavigationService.navigateToNextTest(
        context,
        testParameters,
        TestConfig.testIdLocation,
      );
    }
  }

  /// Build scanning illustration widget
  /// Uses image from API (otherimages for wifi screen) with fallback to local asset
  /// Uses CachedNetworkImage for better caching
  Widget _buildScanningIllustration() {
    final testImagesNotifier = ref.read(testImagesProvider.notifier);
    final otherImages = testImagesNotifier.getOtherImages(TestConfig.testIdWifi);
    
    // Check if we have a valid URL from the API
    if (otherImages.isNotEmpty) {
      final imageUrl = otherImages.first;
      if (imageUrl.startsWith('http://') || imageUrl.startsWith('https://')) {
        return CachedNetworkImage(
          imageUrl: imageUrl,
          fit: BoxFit.contain,
          placeholder: (context, url) => Image.asset(
            AppStrings.scanningWifiPath,
            fit: BoxFit.contain,
            errorBuilder: (_, __, ___) => _buildFallbackIllustration(),
          ),
          errorWidget: (context, url, error) {
            debugPrint('⚠️ Failed to load scanning image from URL: $imageUrl');
            return Image.asset(
              AppStrings.scanningWifiPath,
              fit: BoxFit.contain,
              errorBuilder: (_, __, ___) => _buildFallbackIllustration(),
            );
          },
        );
      }
    }
    
    // Fallback to local asset if no valid URL
    return Image.asset(
      AppStrings.scanningWifiPath,
      fit: BoxFit.contain,
      errorBuilder: (_, __, ___) => _buildFallbackIllustration(),
    );
  }
  
  /// Fallback illustration when all images fail to load
  Widget _buildFallbackIllustration() {
    return Container(
      height: 200,
      color: AppColors.surface,
      child: const Icon(
        Icons.phone_android,
        size: 64,
        color: AppColors.textTertiary,
      ),
    );
  }
  
  /// Get icon URL for a test screen based on its status
  /// Returns null if no URL available from API
  String? _getIconUrlForTest(String testId, bool isPassed) {
    final testImagesNotifier = ref.read(testImagesProvider.notifier);
    return testImagesNotifier.getIconUrl(testId, isPassed: isPassed);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
          /// Common Header with Skip button
          CommonHeader(
            title: AppStrings.welcomeTitle,
            version: AppStrings.appVersion,
            onBack: () => Navigator.of(context).pop(),
            onSkip: _handleSkip,
            skipText: AppStrings.skipButton,
          ),

          /// Progress Bar
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      _isLoadingTestParameters
                          ? 'Loading test parameters...'
                          : '${(_progress * 100).toInt()}% complete',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            fontSize: 12,
                            color: AppColors.textSecondary,
                          ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: _isLoadingTestParameters
                      ? LinearProgressIndicator(
                          // Indeterminate progress indicator while loading
                          backgroundColor: AppColors.surface,
                          valueColor: const AlwaysStoppedAnimation<Color>(
                            AppColors.primary,
                          ),
                          minHeight: 6,
                        )
                      : LinearProgressIndicator(
                          value: _progress,
                          backgroundColor: AppColors.surface,
                          valueColor: const AlwaysStoppedAnimation<Color>(
                            AppColors.primary,
                          ),
                          minHeight: 6,
                        ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          /// Scanning Device Illustration
          /// Uses image from API (otherimages for wifi screen) with fallback to local asset
          Expanded(
            flex: 3,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: _buildScanningIllustration(),
            ),
          ),

         

          const SizedBox(height: 24),

          /// Connectivity Features Section
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  AppStrings.connectivityFeatures,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: AppColors.text,
                      ),
                ),
                const SizedBox(height: 16),

                /// Wi-Fi Card - Show only when WiFi test starts
                if (_showWifiCard) ...[
                  _ConnectivityCard(
                    fallbackIcon: Icons.wifi,
                    iconUrl: _getIconUrlForTest(TestConfig.testIdWifi, _wifiEnabled),
                    title: AppStrings.wifi,
                    status: _wifiTesting
                        ? AppStrings.diagnosing
                        : (_wifiEnabled
                            ? AppStrings.wifiWorkingFlawlessly
                            : AppStrings.notConnected),
                    statusColor: _wifiTesting
                        ? AppColors.textSecondary
                        : (_wifiEnabled
                            ? AppColors.success
                            : AppColors.textSecondary),
                    iconStatus: _wifiTesting
                        ? _IconStatus.diagnosing
                        : (_wifiEnabled
                            ? _IconStatus.success
                            : _IconStatus.warning),
                  ),
                  const SizedBox(height: 12),
                ],

                /// Bluetooth Card - Show only after WiFi test completes
                if (_showBluetoothCard) ...[
                  _ConnectivityCard(
                    fallbackIcon: Icons.bluetooth,
                    iconUrl: _getIconUrlForTest(TestConfig.testIdBluetooth, _bluetoothConnected),
                    title: AppStrings.bluetooth,
                    status: _bluetoothTesting
                        ? AppStrings.diagnosing
                        : (_bluetoothConnected
                            ? AppStrings.wifiWorkingFlawlessly
                            : AppStrings.notConnected),
                    statusColor: _bluetoothTesting
                        ? AppColors.textSecondary
                        : (_bluetoothConnected
                            ? AppColors.success
                            : AppColors.textSecondary),
                    iconStatus: _bluetoothTesting
                        ? _IconStatus.diagnosing
                        : (_bluetoothConnected
                            ? _IconStatus.success
                            : _IconStatus.warning),
                  ),
                  const SizedBox(height: 12),
                ],

                /// GPS Card - Show only after Bluetooth test completes
                if (_showGpsCard)
                  _ConnectivityCard(
                    fallbackIcon: Icons.location_on,
                    iconUrl: _getIconUrlForTest(TestConfig.testIdLocation, _gpsEnabled),
                    title: AppStrings.gps,
                    status: _gpsDiagnosing
                        ? AppStrings.diagnosing
                        : (_gpsEnabled
                            ? AppStrings.wifiWorkingFlawlessly
                            : AppStrings.notConnected),
                    statusColor: _gpsDiagnosing
                        ? AppColors.textSecondary
                        : (_gpsEnabled
                            ? AppColors.success
                            : AppColors.textSecondary),
                    iconStatus: _gpsDiagnosing
                        ? _IconStatus.diagnosing
                        : (_gpsEnabled
                            ? _IconStatus.success
                            : _IconStatus.warning),
                  ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          /// Found Wi-Fi Networks Text
          if (_wifiEnabled && _wifiNetworksFound > 0)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Text(
                AppStrings.foundWifiNetworks.replaceAll(
                  '{count}',
                  _wifiNetworksFound.toString(),
                ),
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      fontSize: 12,
                      color: AppColors.textTertiary,
                    ),
              ),
            ),

          const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}

enum _IconStatus {
  success,
  warning,
  diagnosing,
}

class _ConnectivityCard extends StatelessWidget {
  const _ConnectivityCard({
    required this.fallbackIcon,
    required this.title,
    required this.status,
    required this.statusColor,
    required this.iconStatus,
    this.iconUrl,
  });

  final IconData fallbackIcon; // Fallback icon from Flutter Icons
  final String? iconUrl; // Icon URL from GetTestImages API
  final String title;
  final String status;
  final Color statusColor;
  final _IconStatus iconStatus;

  /// Build the icon widget - tries API URL first, falls back to IconData
  /// Uses CachedNetworkImage for better caching
  Widget _buildIconWidget() {
    // If we have a valid HTTP/HTTPS URL, try to load it
    if (iconUrl != null && iconUrl!.isNotEmpty && 
        (iconUrl!.startsWith('http://') || iconUrl!.startsWith('https://'))) {
      return CachedNetworkImage(
        imageUrl: iconUrl!,
        width: 24,
        height: 24,
        fit: BoxFit.contain,
        placeholder: (context, url) => Icon(
          fallbackIcon,
          color: AppColors.primary,
          size: 24,
        ),
        errorWidget: (context, url, error) => Icon(
          fallbackIcon,
          color: AppColors.primary,
          size: 24,
        ),
      );
    }
    
    // If no valid URL, use fallback icon
    return Icon(
      fallbackIcon,
      color: AppColors.primary,
      size: 24,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: AppColors.border,
          width: 1,
        ),
      ),
      child: Row(
        children: [
          /// Icon - uses API URL with fallback to IconData
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Center(
              child: _buildIconWidget(),
            ),
          ),
          const SizedBox(width: 12),

          /// Title and Status
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: AppColors.text,
                      ),
                ),
                const SizedBox(height: 4),
                Text(
                  status,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        fontSize: 12,
                        color: statusColor,
                      ),
                ),
              ],
            ),
          ),

          /// Status Icon
          if (iconStatus != _IconStatus.diagnosing)
            Container(
              width: 24,
              height: 24,
              decoration: BoxDecoration(
                color: iconStatus == _IconStatus.success
                    ? AppColors.primary
                    : AppColors.warning,
                shape: BoxShape.circle,
              ),
              child: Icon(
                iconStatus == _IconStatus.success
                    ? Icons.check
                    : Icons.error_outline,
                size: 16,
                color: Colors.white,
              ),
            )
          else
            const SizedBox(
              width: 24,
              height: 24,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation<Color>(AppColors.primary),
              ),
            ),
        ],
      ),
    );
  }
}
