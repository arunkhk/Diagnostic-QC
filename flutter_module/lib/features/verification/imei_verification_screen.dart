import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/constants/app_colors.dart';
import '../../core/constants/app_strings.dart';
import '../../core/widgets/common_header.dart';
import '../../core/widgets/common_toast.dart';
import '../../core/widgets/common_loading_bar.dart';
import '../../core/services/api_service.dart';
import '../../core/models/api_response.dart';
import '../../core/utils/device_info_util.dart';
import '../auth/providers/auth_provider.dart';
import '../auth/login_screen.dart';
import 'models/imei_verification_response.dart';
import 'providers/imei_provider.dart';
import '../diagnosis/diagnosis_screen.dart';
import '../diagnosis/providers/test_images_provider.dart';

class ImeiVerificationScreen extends ConsumerStatefulWidget {
  const ImeiVerificationScreen({super.key});

  @override
  ConsumerState<ImeiVerificationScreen> createState() => _ImeiVerificationScreenState();
}

class _ImeiVerificationScreenState extends ConsumerState<ImeiVerificationScreen> {
  final TextEditingController _imeiController = TextEditingController();
  final FocusNode _imeiFocusNode = FocusNode();
  bool _isValidating = false;
  bool _isLoadingTestImages = false; // Track test images loading state
  String _deviceBrand = '';
  String _deviceModel = '';
  String _selectedDeviceType = 'Entry level'; // Default selected value
  
  // Hardcoded values for API request
  static const String hardcodedImeI2 = '';
  static const String hardcodedProcessType = 'AUTO';
  static const String hardcodedBusinessUnit = 'TRC';
  
  @override
  void initState() {
    super.initState();
    _loadDeviceInfo();
    // Fetch test images after widget tree is built (to avoid modifying provider during build)
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadTestImages();
    });
  }
  
  /// Fetch test images from API on page load
  /// This preloads images so they're ready when diagnosis screens need them
  Future<void> _loadTestImages() async {
    if (!mounted) return;
    
    setState(() {
      _isLoadingTestImages = true;
    });
    
    await ref.read(testImagesProvider.notifier).fetchTestImages();
    
    if (mounted) {
      setState(() {
        _isLoadingTestImages = false;
      });
    }
  }
  @override
  void dispose() {
    _imeiController.dispose();
    _imeiFocusNode.dispose();
    super.dispose();
  }


  /// Load device brand and model information
  Future<void> _loadDeviceInfo() async {
    final brand = await DeviceInfoUtil.getDeviceBrand();
    final model = await DeviceInfoUtil.getDeviceModel();
    if (mounted) {
      setState(() {
        _deviceBrand = brand;
        _deviceModel = model;
      });
    }
  }

  /// Show dialog with device information after API response
  void _showDeviceInfoDialog(ImeiVerificationResponse apiResponse, String enteredImeiOrUniqueId) async {
    // Get Flutter-detected device info for comparison
    final flutterBrand = await DeviceInfoUtil.getDeviceBrand();
    final flutterModel = await DeviceInfoUtil.getDeviceModel();
    
    if (!mounted) return;


    // Use API's dynamic message and type
    final apiMessage = apiResponse.infoMessage ?? '';
    final apiType = apiResponse.type?.toLowerCase();
    
    // Determine status color and icon based on API type
    Color statusColor;
    IconData statusIcon;
    String statusMessage = apiMessage;
    
    // Determine color and icon based on API type
    switch (apiType) {
      case 'warning':
        statusColor = AppColors.warning;
        statusIcon = Icons.warning;
        break;
      case 'error':
        statusColor = AppColors.error;
        statusIcon = Icons.error_outline;
        break;
      case 'success':
        statusColor = AppColors.success;
        statusIcon = Icons.check_circle;
        break;
      default:
        // Default to warning if type is not recognized
        statusColor = AppColors.warning;
        statusIcon = Icons.info_outline;
    }
    
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        title: Row(
          children: [
            Icon(
              statusIcon,
              color: statusColor,
              size: 24,
            ),
            const SizedBox(width: 8),
            const Expanded(
              child: Text(
                'Device Information',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [

              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: statusColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: statusColor.withOpacity(0.3),
                    width: 1,
                  ),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      statusIcon,
                      size: 20,
                      color: statusColor,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            statusMessage,
                            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                  fontSize: 14,
                                  color: AppColors.text,
                                  height: 1.5,
                                ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              
              // Smart Diagnosis Detected Section
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: AppColors.border,
                    width: 1,
                  ),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.phone_android,
                          size: 16,
                          color: AppColors.primary,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          '${AppStrings.smartDiagnosisTitle} Detected:',
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                fontSize: 12,
                                color: AppColors.textSecondary,
                                fontWeight: FontWeight.w600,
                              ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    if (flutterBrand.isNotEmpty) ...[
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Brand: ',
                            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                  fontSize: 12,
                                  color: AppColors.textSecondary,
                                  fontWeight: FontWeight.w500,
                                ),
                          ),
                          Expanded(
                            child: Text(
                              flutterBrand,
                              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                    fontSize: 12,
                                    color: AppColors.text,
                                    fontWeight: FontWeight.w600,
                                  ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                    ],
                    if (flutterModel.isNotEmpty)
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Model: ',
                            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                  fontSize: 12,
                                  color: AppColors.textSecondary,
                                  fontWeight: FontWeight.w500,
                                ),
                          ),
                          Expanded(
                            child: Text(
                              flutterModel,
                              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                    fontSize: 12,
                                    color: AppColors.text,
                                    fontWeight: FontWeight.w600,
                                  ),
                            ),
                          ),
                        ],
                      ),
                  ],
                ),
              ),
              
              const SizedBox(height: 12),
              
              // System Response Section
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: AppColors.border,
                    width: 1,
                  ),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.cloud_done,
                          size: 16,
                          color: AppColors.primary,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          'System Response:',
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                fontSize: 12,
                                color: AppColors.textSecondary,
                                fontWeight: FontWeight.w600,
                              ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    if (apiResponse.brandName.isNotEmpty) ...[
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Brand: ',
                            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                  fontSize: 12,
                                  color: AppColors.textSecondary,
                                  fontWeight: FontWeight.w500,
                                ),
                          ),
                          Expanded(
                            child: Text(
                              apiResponse.brandName,
                              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                    fontSize: 12,
                                    color: AppColors.text,
                                    fontWeight: FontWeight.w600,
                                  ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                    ],
                    if (apiResponse.modelName.isNotEmpty)
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Model: ',
                            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                  fontSize: 12,
                                  color: AppColors.textSecondary,
                                  fontWeight: FontWeight.w500,
                                ),
                          ),
                          Expanded(
                            child: Text(
                              apiResponse.modelName,
                              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                    fontSize: 12,
                                    color: AppColors.text,
                                    fontWeight: FontWeight.w600,
                                  ),
                            ),
                          ),
                        ],
                      ),
                  ],
                ),
              ),
              
              const SizedBox(height: 12),
              // IMEI or UniqueID
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: AppColors.border,
                    width: 1,
                  ),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      enteredImeiOrUniqueId.length == 15 ? 'IMEI Number:' : 'UniqueID:',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            fontSize: 12,
                            color: AppColors.textSecondary,
                            fontWeight: FontWeight.w500,
                          ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      enteredImeiOrUniqueId,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            fontSize: 14,
                            color: AppColors.text,
                            fontWeight: FontWeight.w600,
                            fontFamily: 'monospace',
                          ),
                    ),
                  ],
                ),
              ),


            ],
          ),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 0, vertical: 0),
            child: Row(
              children: [
                // LEFT: Cancel
                TextButton(
                  onPressed: () {
                    Navigator.of(context).pop(); // close dialog only
                  },
                  child: const Text(
                    'Cancel',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: AppColors.primary,
                    ),
                  ),
                ),

                const Spacer(), // pushes Continue to right

                // RIGHT: Continue
                TextButton(
                  onPressed: () {
                    Navigator.of(context).pop(); // close dialog
                    Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => const DiagnosisScreen(),
                      ),
                    );
                  },
                  child: const Text(
                    'Continue',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: AppColors.primary,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],

      ),
    );
  }

  Widget _buildRadioButton({
    required String value,
    required String label,
    required String? groupValue,
    required ValueChanged<String?> onChanged,
    bool showBorder = true,
    bool isFirst = false,
    bool isLast = false,
    bool isInRow = false,
    bool isLeft = false,
    bool isRight = false,
  }) {
    final isSelected = groupValue == value;
    
    // Determine border radius based on position
    BorderRadius? borderRadius;
    if (isInRow) {
      if (isFirst && isLeft) {
        borderRadius = const BorderRadius.only(
          topLeft: Radius.circular(8),
        );
      } else if (isFirst && isRight) {
        borderRadius = const BorderRadius.only(
          topRight: Radius.circular(8),
        );
      }
    } else {
      if (isFirst) {
        borderRadius = const BorderRadius.only(
          topLeft: Radius.circular(8),
          topRight: Radius.circular(8),
        );
      } else if (isLast) {
        borderRadius = const BorderRadius.only(
          bottomLeft: Radius.circular(8),
          bottomRight: Radius.circular(8),
        );
      }
    }
    
    return InkWell(
      onTap: () => onChanged(value),
      borderRadius: borderRadius ?? BorderRadius.zero,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primary.withOpacity(0.1) : Colors.transparent,
          borderRadius: borderRadius,
          border: showBorder
              ? Border.all(
                  color: isSelected ? AppColors.primary : AppColors.border,
                  width: isSelected ? 2 : 1,
                )
              : null,
        ),
        child: Row(
          children: [
            Radio<String>(
              value: value,
              groupValue: groupValue,
              onChanged: onChanged,
              activeColor: AppColors.primary,
            ),
            Expanded(
              child: Text(
                label,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      fontSize: 14,
                      color: isSelected ? AppColors.primary : AppColors.text,
                      fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                    ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  bool _isValidInput(String input) {
    // Remove any spaces or dashes
    final cleaned = input.replaceAll(RegExp(r'[\s-]'), '');
    
    // Check if it's a valid IMEI (exactly 15 digits)
    if (cleaned.length == 15 &&
        RegExp(r'^\d{15}$').hasMatch(cleaned)) {
      return true;
    }

    
    // Check if it's a valid UniqueID (less than 15 characters, max length check only)
    if (cleaned.length < 15 && cleaned.isNotEmpty) {
      return true;
    }
    
    return false;
  }

  /// Call API to save diagnose summary headers
  /// Uses dynamic values from login API response and device information
  Future<ApiResponse<ImeiVerificationResponse>> _saveDiagnoseSummaryHeaders(String imei) async {
    try {
      // Get user data from auth provider (from login API response)
      final authState = ref.read(authProvider);
      final user = authState.user;
      // Validate that user data is available
      if (user == null) {
        return ApiResponse.error('User not authenticated. Please login first.');
      }
      // Get device information dynamically
      final osVersion = await DeviceInfoUtil.getOsVersion();
      final deviceId = await DeviceInfoUtil.getDeviceId();
      final ipAddress = await DeviceInfoUtil.getIpAddress();
      // Use cached permission status from permission screen (no delay)
      final locationData = await DeviceInfoUtil.getLocation(ref: ref);
      final flutterBrand = await DeviceInfoUtil.getDeviceBrand();
      final flutterModel = await DeviceInfoUtil.getDeviceModel();


      final apiService = ApiService();
      final response = await apiService.post<ImeiVerificationResponse>(
        '/PhoneDiagnostics/SaveDiagnoseSummaryHeaders',
        body: {
          'UniqueId': '',
          'imei': imei, // Dynamic IMEI from input
          'imeI2': hardcodedImeI2,
          'diagnoseType': _selectedDeviceType,
          'processType': hardcodedProcessType,
          'officeName': user.officeName, // Dynamic from login response
          'officeId': user.officeId, // Dynamic from login response
          'businessUnit': hardcodedBusinessUnit,
          'osVersion': osVersion, // Dynamic from device
          'userId': user.userId, // Dynamic from login response
          'deviceID': deviceId, // Dynamic from device
          'ipAddress': ipAddress, // Dynamic from network
          'location': locationData['location'] ?? 'Unknown', // Dynamic from GPS
          'latitude': locationData['latitude'] ?? '0.0', // Dynamic from GPS
          'longitude': locationData['longitude'] ?? '0.0', // Dynamic from GPS
          'organizationId': user.orgId.toString(), // Dynamic from login response (convert int to string)
          'createdBy': user.userId, // Dynamic from login response
          'deviceType': _selectedDeviceType, // Selected device type from radio buttons
          "BrandID": 0,
          "ModelID": 0,
          "BrandName": flutterBrand,
          "ModelName": flutterModel
        },

        fromJson: (json) => ImeiVerificationResponse.fromJson(json),
      );

      return response;
    } catch (e) {
      return ApiResponse.error('API error: $e');
    }
  }

  Future<void> _handleProceed() async {
    final input = _imeiController.text.trim();
    
    if (input.isEmpty) {
      CommonToast.showError(
        context,
        message: 'Please enter IMEI number or UniqueID',
      );
      return;
    }
    if (!_isValidInput(input)) {
      CommonToast.showError(
        context,
        message: 'Please enter a valid IMEI (15 digits) or UniqueID (less than 15 characters)',
      );
      return;
    }

    setState(() {
      _isValidating = true;
    });

    // Call API to save diagnose summary headers
    final response = await _saveDiagnoseSummaryHeaders(input);

    if (!mounted) return;
    setState(() {
      _isValidating = false;
    });

    if (response.success && response.data != null) {
      // Save the response data
      ref.read(imeiVerificationProvider.notifier).saveResponse(
        response.data!,
        input,
      );
      
      // Note: Test images are already being loaded on page load (_loadTestImages in initState)
      
      // Show dialog with device information (no toast when dialog appears)
      _showDeviceInfoDialog(
        response.data!,
        input,
      );
    } else {
      // Error - show error toast (dialog will not appear)
      final errorMessage = response.errorMessage ?? 'Failed to verify IMEI';
      CommonToast.showError(
        context,
        message: errorMessage,
      );
    }
  }
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(

          children: [
          /// Common Header with logout button if user is logged in
          CommonHeader(
            title: AppStrings.verifyDeviceTitle,
            version: AppStrings.appVersion,
            onBack: Navigator.of(context).canPop() ? () => Navigator.of(context).pop() : null,
            showLogout: ref.watch(authProvider).isAuthenticated,
            onLogout: () async {
              // Show confirmation dialog
              final shouldLogout = await showDialog<bool>(
                context: context,
                builder: (context) => AlertDialog(
                  title: const Text('Logout'),
                  content: const Text('Are you sure you want to logout?'),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.of(context).pop(false),
                      child: const Text('Cancel'),
                    ),
                    TextButton(
                      onPressed: () => Navigator.of(context).pop(true),
                      style: TextButton.styleFrom(
                        foregroundColor: AppColors.error,
                      ),
                      child: const Text('Logout'),
                    ),
                  ],
                ),
              );

              if (shouldLogout == true && mounted) {
                // Logout user
                await ref.read(authProvider.notifier).logout();
                
                // Navigate to login screen and clear navigation stack
                Navigator.of(context).pushAndRemoveUntil(
                  MaterialPageRoute(builder: (_) => const LoginScreen()),
                  (route) => false,
                );
                
                CommonToast.showSuccess(
                  context,
                  message: 'Logged out successfully',
                );
              }
            },
          ),

          /// Test Images Loading Progress Bar
          if (_isLoadingTestImages)
            const CommonLoadingBar(message: 'Loading...'),

          /// Top Illustration
          Expanded(
            flex: 1,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              child: Image.asset(
                AppStrings.imageGroupPath,
                fit: BoxFit.contain,
                errorBuilder: (_, __, ___) => Container(
                  height: 200,
                  color: AppColors.surface,
                  child: const Icon(
                    Icons.image_not_supported,
                    size: 48,
                    color: AppColors.textTertiary,
                  ),
                ),
              ),
            ),
          ),
          Expanded(
            flex: 2,
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  /// Title
                  ///
                  ///
                  Text(
                    AppStrings.verifyDeviceTitle,
                    style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                          color: AppColors.text,
                          height: 1.2,
                        ),
                  ),

                  const SizedBox(height: 12),

                  /// Description
                  Text(
                    AppStrings.verifyDeviceDescription,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          fontSize: 14,
                          color: AppColors.textSecondary,
                          height: 1.5,
                        ),
                  ),

                  /// Device Brand and Model Info
                  if (_deviceBrand.isNotEmpty || _deviceModel.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      decoration: BoxDecoration(
                        color: AppColors.surface,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: AppColors.border,
                          width: 1,
                        ),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          // Icon centered vertically
                          Icon(
                            Icons.phone_android,
                            size: 16,
                            color: AppColors.primary,
                          ),
                          const SizedBox(width: 8),
                          // Vertical divider
                          Container(
                            width: 1,
                            height: 24,
                            color: AppColors.border,
                          ),
                          const SizedBox(width: 8),
                          // Brand and Model in a column
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                if (_deviceBrand.isNotEmpty)
                                  Row(
                                    children: [
                                      Text(
                                        'Brand: ',
                                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                              fontSize: 12,
                                              color: AppColors.textSecondary,
                                              fontWeight: FontWeight.w500,
                                            ),
                                      ),
                                      Expanded(
                                        child: Text(
                                          _deviceBrand,
                                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                                fontSize: 12,
                                                color: AppColors.text,
                                                fontWeight: FontWeight.w600,
                                              ),
                                        ),
                                      ),
                                    ],
                                  ),
                                if (_deviceBrand.isNotEmpty && _deviceModel.isNotEmpty)
                                  const SizedBox(height: 2),
                                if (_deviceModel.isNotEmpty)
                                  Row(
                                    children: [
                                      Text(
                                        'Model: ',
                                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                              fontSize: 12,
                                              color: AppColors.textSecondary,
                                              fontWeight: FontWeight.w500,
                                            ),
                                      ),
                                      Expanded(
                                        child: Text(
                                          _deviceModel,
                                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                                fontSize: 12,
                                                color: AppColors.text,
                                                fontWeight: FontWeight.w600,
                                              ),
                                        ),
                                      ),
                                    ],
                                  ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],

                  /// Device Type Radio Buttons
                  const SizedBox(height: 12),
                  Text(
                    'Device Type',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          fontSize: 14,
                          color: AppColors.text,
                          fontWeight: FontWeight.w600,
                        ),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: AppColors.border,
                        width: 1,
                      ),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // First row: Two radio buttons side by side
                        Row(
                          children: [
                            Expanded(
                              child: SizedBox(
                                height: 44, // ⭐ fixed compact height
                                child: _buildRadioButton(
                                  value: 'Entry level',
                                  label: 'Entry level',
                                  groupValue: _selectedDeviceType,
                                  onChanged: (value) {
                                    setState(() {
                                      _selectedDeviceType = value!;
                                    });
                                  },
                                 // isFirst: true,
                                 // isInRow: true,
                                //  isLeft: true,
                                  showBorder: false,
                                ),
                              ),
                            ),

                            Container(width: 1, height: 44, color: AppColors.border),

                            Expanded(
                              child: SizedBox(
                                height: 44,
                                child: _buildRadioButton(
                                  value: 'Internal Test',
                                  label: 'Internal Test',
                                  groupValue: _selectedDeviceType,
                                  onChanged: (value) {
                                    setState(() {
                                      _selectedDeviceType = value!;
                                    });
                                  },
                                 // isFirst: true,
                                 // isInRow: true,
                                 // isRight: true,
                                  showBorder: false,
                                ),
                              ),
                            ),
                          ],
                        ),

                        // Divider between rows - only visible when Post Repair is selected
                        // Hidden when Entry level (default) or Internal Test (from row) is selected

              DecoratedBox(
                decoration: const BoxDecoration(
                  border: Border(
                    top: BorderSide(color: AppColors.border),
                  ),
                ),
                child:SizedBox(
                  height: 44,
                  child: _buildRadioButton(
                    value: 'Post Repair',
                    label: 'Post Repair',
                    groupValue: _selectedDeviceType,
                    onChanged: (value) {
                      setState(() {
                        _selectedDeviceType = value!;
                      });
                    },
                     showBorder: false,
                    isInRow: true,
                  ),
                ) ,
              ),


                      ],
                    ),
                  ),

                  const SizedBox(height: 24),

                  /// IMEI Input Field
                  Focus(
                    onFocusChange: (hasFocus) {
                      setState(() {});
                    },
                    child: Container(
                      decoration: BoxDecoration(
                        border: Border.all(
                          color: _imeiFocusNode.hasFocus
                              ? AppColors.primary
                              : AppColors.border,
                          width: 1.5,
                        ),
                        borderRadius: BorderRadius.circular(12),
                        color: AppColors.white,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Padding(
                            padding: const EdgeInsets.only(
                              left: 16,
                              top: 12,
                              right: 16,
                            ),
                            child: Text(
                              'IMEI Number or UniqueID',
                              style: Theme.of(context)
                                  .textTheme
                                  .bodySmall
                                  ?.copyWith(
                                    fontSize: 12,
                                    color: AppColors.textSecondary,
                                    fontWeight: FontWeight.w500,
                                  ),
                            ),
                          ),
                          TextField(
                            controller: _imeiController,
                            focusNode: _imeiFocusNode,
                            keyboardType: TextInputType.text,
                            inputFormatters: [
                              LengthLimitingTextInputFormatter(15),
                            ],
                            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                                  fontSize: 16,
                                  color: AppColors.text,
                                ),
                            decoration: InputDecoration(
                              hintText: 'Enter IMEI (15 digits) or UniqueID (max 14 chars)',
                              hintStyle: Theme.of(context)
                                  .textTheme
                                  .bodyMedium
                                  ?.copyWith(
                                    fontSize: 16,
                                    color: AppColors.textTertiary,
                                  ),
                              border: InputBorder.none,
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 8,
                              ),
                            ),
                            onSubmitted: (_) => _handleProceed(),
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 24),
                ],
              ),
            ),
          ),

          /// Proceed Button
          Padding(
            padding: const EdgeInsets.all(16),
            child: SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton(
                onPressed: _isValidating ? null : _handleProceed,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  disabledBackgroundColor: AppColors.disabled,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  elevation: 0,
                ),
                child: _isValidating
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                        ),
                      )
                    : const Text(
                        AppStrings.proceedButton,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                      ),
              ),
            ),
          ),
          ],
        ),
      ),
    );
  }
}

