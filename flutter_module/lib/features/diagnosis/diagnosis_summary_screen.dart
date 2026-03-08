import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_strings.dart';
import '../../core/widgets/common_header.dart';
import '../../core/widgets/common_toast.dart';
import '../../core/services/api_service.dart';
import '../../features/auth/providers/auth_provider.dart';
import '../../features/verification/providers/imei_provider.dart';
import 'models/test_result.dart';
import 'models/battery_details_request.dart';
import 'models/diagnosis_parameters_response.dart';
import 'models/diagnosis_summary_request.dart';
import 'models/final_diagnosis_request.dart';
import 'providers/test_result_provider.dart';
import 'providers/test_parameters_provider.dart';
import 'models/test_parameter_item.dart';
import 'providers/battery_provider.dart';
import 'utils/test_config.dart';
import 'final_diagnosis_screen.dart';

class DiagnosisSummaryScreen extends ConsumerStatefulWidget {
  const DiagnosisSummaryScreen({super.key});

  @override
  ConsumerState<DiagnosisSummaryScreen> createState() => _DiagnosisSummaryScreenState();
}
class _DiagnosisSummaryScreenState extends ConsumerState<DiagnosisSummaryScreen> {
  bool _hasCalledBatteryApi = false;
  bool _isLoadingParameters = false;
  bool _isSubmittingReport = false;


  @override
  void initState() {
    super.initState();
    // Call battery API when screen is initialized
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _saveBatteryDetails();
    });

  }

  /// Get hardcoded diagnosis parameters (fallback)
  DiagnosisParametersResponse _getHardcodedDiagnosisParameters() {
    return DiagnosisParametersResponse.fromJson({
      'finalDiagnosisFailRemarks': [
        'Wifi faulty',
        'Vibration Faulty',
        'Usb/Otg Faulty',
        'True Tone Not Activate',
        'Touch Issue',
        'Software Issue',
        'Siri Not Work',
        'SIM tray Missing / Mismatch',
        'Proximity Sensor Faulty',
        'OG Display',
        'Not Switching ON',
        'Network 2 Faulty',
        'GPS Faulty',
        'Front Flash Faulty',
        'Flashlight Faulty',
        'FingerPrint Faulty',
        'FaceLock Faulty',
        'Ear Speaker Faulty',
        'Display Faulty',
        'Charging Issue',
        'Camera Error',
        'Body Key Faulty',
        'Body Fixing Issue',
        'Body Broken',
        'Bluetooth Faulty',
        'Battery Health Issue',
        'Battery Faulty',
        'Battery errror',
      ],
      'devicePhysicalCondition': [
        'A1 Category Phone',
        'Average (Minor scratches on Touch)',
        'Heavy Scratches on touch',
        'Heavy Scratches on Back cover',
        'Chrome dented / Minor scratches',
      ],
      'displayCondition': [
        'Display dot / dots',
        'Display discoloration',
        'Display patches',
        'Display Line (V-H)',
        'Touch broken',
        'T&D broken',
        'Liquid Seepage',
      ],
    });
  }

  /// Convert test status to API format (Pass, Fail, NA, or Skipped)
  String _getDiagnosedResult(TestStatus status) {
    switch (status) {
      case TestStatus.pass:
        return 'Pass';
      case TestStatus.fail:
        return 'Fail';
      case TestStatus.na:
        return 'NA';
      case TestStatus.skip:
      case TestStatus.pending:
        return 'Skipped';
    }
  }

  /// Build diagnosis summary test params from test results (same as final diagnosis screen)
  List<DiagnosisSummaryTestParam> _buildDiagnosisSummaryParams({
    required int diagnosisSummaryID,
    required int createdBy,
  }) {
    final testResults = ref.read(testResultProvider);
    final testResultMap = <String, TestResult>{};
    for (final result in testResults) {
      testResultMap[result.testId] = result;
    }

    final testParametersAsync = ref.read(testParametersProvider);
    final testParameters = testParametersAsync.when(
      data: (list) {
        final sorted = List<TestParameterItem>.from(list)
          ..sort((a, b) => a.displayOrder.compareTo(b.displayOrder));
        return sorted;
      },
      loading: () => <TestParameterItem>[],
      error: (_, __) => <TestParameterItem>[],
    );

    final testParams = <DiagnosisSummaryTestParam>[];
    for (final testParameter in testParameters) {
      final testId = testParameter.uniqueTestKey;
      final result = testResultMap[testId];
      final status = result?.status ?? TestStatus.skip;
      final diagnosedResult = _getDiagnosedResult(status);
      testParams.add(
        DiagnosisSummaryTestParam(
          testParameterID: testParameter.diagnoseParamID,
          testParameter: testParameter.paramValue,
          diagnosisSummaryID: diagnosisSummaryID,
          diagnosedResult: diagnosedResult,
          diagnosedReason: '',
          createdBy: createdBy,
        ),
      );
    }
    return testParams;
  }

  /// Submit report: GetDiagnosisRemarks, then SaveDiagnoseDetails, then navigate to Final Diagnosis (as before)
  Future<void> _handleSubmitReport() async {
    setState(() {
      _isSubmittingReport = true;
    });

    try {
      final apiService = ApiService();

      // 1. Existing API: GetDiagnosisRemarks (get parameters for Final Diagnosis screen)
      final remarksResponse = await apiService.get<DiagnosisParametersResponse>(
        '/PhoneDiagnostics/GetDiagnosisRemarks',
        fromJson: (json) => DiagnosisParametersResponse.fromJson(json),
      );
      DiagnosisParametersResponse parameters = remarksResponse.success && remarksResponse.data != null
          ? remarksResponse.data!
          : _getHardcodedDiagnosisParameters();

      // 2. Additional API: SaveDiagnoseDetails (final submission with available data, blank for rest)
      final imeiState = ref.read(imeiVerificationProvider);
      final diagnosisSummaryId = imeiState.response?.diagnosisSummarMasterId;
      if (diagnosisSummaryId == null) {
        if (mounted) {
          setState(() => _isSubmittingReport = false);
          CommonToast.showError(context, message: 'Diagnosis Summary ID not found');
        }
        return;
      }

      final authState = ref.read(authProvider);
      final userId = authState.user?.userId;
      if (userId == null) {
        if (mounted) {
          setState(() => _isSubmittingReport = false);
          CommonToast.showError(context, message: 'User ID not found');
        }
        return;
      }

      final testParams = _buildDiagnosisSummaryParams(
        diagnosisSummaryID: diagnosisSummaryId,
        createdBy: userId,
      );
      final imeiResponse = imeiState.response!;

      final allPass = testParams.every((param) => param.diagnosedResult == 'Pass');
      final diagnoseEngine = allPass ? 'Pass' : 'Fail';

      final diagnosisDetails = testParams.map((param) {
        return DiagnosisDetail(
          diagnosisSummaryID: diagnosisSummaryId,
          testParameter: param.testParameter,
          testParameterID: param.testParameterID.toString(),
          diagnosedResult: param.diagnosedResult,
          diagnosedReason: param.diagnosedReason,
          createdBy: userId,
        );
      }).toList();

      final request = FinalDiagnosisRequest(
        diagnosisSummaryID: diagnosisSummaryId,
        brandID: imeiResponse.brandId,
        modelID: imeiResponse.modelId,
        brandName: imeiResponse.brandName,
        modelName: imeiResponse.modelName,
        overallRemarksStatus: '',
        failureRemarks: '',
        finalStatusRemarks: '',
        devicePhysicalCondition: '',
        displayfault: '',
        displayDetails: '',
        createdBy: userId,
        diagnosisDetails: diagnosisDetails,
        diagnoseEngine: diagnoseEngine,
        feedback: null,
      );

      await apiService.post<Map<String, dynamic>>(
        '/PhoneDiagnostics/SaveDiagnoseDetails',
        body: request.toJson(),
        fromJson: (json) => Map<String, dynamic>.from(json),
      );

      if (!mounted) return;
      setState(() => _isSubmittingReport = false);

      // 3. Navigate to Final Diagnosis screen (as earlier) with parameters from GetDiagnosisRemarks
      Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => FinalDiagnosisScreen(parameters: parameters),
        ),
      );
    } catch (e) {
      debugPrint('❌ Submit report error: $e');
      if (mounted) {
        setState(() => _isSubmittingReport = false);
        CommonToast.showError(
          context,
          message: 'Failed to submit: ${e.toString()}',
        );
      }
    }
  }

  /// Call API to save battery details
  Future<void> _saveBatteryDetails() async {
    if (_hasCalledBatteryApi) return; // Prevent multiple calls
    
    try {
      // Get diagnosis summary ID from IMEI verification
      final imeiState = ref.read(imeiVerificationProvider);
      final diagnosisSummaryId = imeiState.response?.diagnosisSummarMasterId;
      
      if (diagnosisSummaryId == null) {
        debugPrint('⚠️ Diagnosis Summary ID not found');
        return;
      }

      // Get battery info from provider
      final batteryState = ref.read(batteryProvider);
      final batteryInfo = batteryState.batteryInfo;
      
      if (batteryInfo == null) {
        debugPrint('⚠️ Battery info not found');
        return;
      }

      // Get user ID from auth provider
      final authState = ref.read(authProvider);
      final userId = authState.user?.userId;
      
      if (userId == null) {
        debugPrint('⚠️ User ID not found');
        return;
      }

      // Get battery test result
      final testResult = ref.read(testResultProvider.notifier).getResult('battery');
      final testResultString = testResult?.status == TestStatus.pass
          ? 'Pass'
          : testResult?.status == TestStatus.na
              ? 'NA'
              : 'Fail';

      // Map battery data to API request format
      final request = BatteryDetailsRequest(
        diagnosisSummaryID: diagnosisSummaryId,
        batteryType: batteryInfo.technology.isNotEmpty && batteryInfo.technology != 'Unknown'
            ? batteryInfo.technology
            : 'Lithium', // Default to Lithium if unknown
        testResult: testResultString,
        batteryHealth: batteryInfo.health.isNotEmpty && batteryInfo.health != 'Unknown'
            ? batteryInfo.health
            : 'Good', // Default to Good if unknown
        voltage: batteryInfo.voltage.toString(),
        chargingLevel: '${batteryInfo.level}%',
        temperature: '${batteryInfo.temperature.toStringAsFixed(0)}C',
        scale: batteryInfo.scale == 100 ? 'Normal' : 'Abnormal',
        remarks: batteryInfo.health == 'Good' ? 'Good' : 'Check Battery',
        createdBy: userId.toString(),
      );

      // Call API
      final apiService = ApiService();
      final response = await apiService.post<Map<String, dynamic>>(
        '/PhoneDiagnostics/SaveBatteryDetails',
        body: request.toJson(),
        fromJson: (json) => Map<String, dynamic>.from(json),
      );


      if (response.success) {
        _hasCalledBatteryApi = true;
        debugPrint('✅ Battery details saved successfully');
      } else {
        debugPrint('❌ Failed to save battery details: ${response.errorMessage}');
      }
    } catch (e) {
      debugPrint('❌ Error saving battery details: $e');
    }
  }


  /// Get tests from testParametersProvider (dynamic based on API configuration)
  List<Map<String, dynamic>> _getTestsFromProvider() {
    final testParametersAsync = ref.read(testParametersProvider);
    
    return testParametersAsync.when(
      data: (testParameters) {
        // Sort by displayOrder to maintain correct sequence
        final sortedParams = List<TestParameterItem>.from(testParameters)
          ..sort((a, b) => a.displayOrder.compareTo(b.displayOrder));
        
        // Convert TestParameterItem to map format for grid
        return sortedParams.map((param) {
          return {
            'id': param.uniqueTestKey,
            'label': param.paramValue, // Use paramValue from API
            'catIcon': param.catIcon, // Icon path from API (e.g., "Wifi.png")
            'fallbackIcon': TestConfig.getIconForTestKey(param.uniqueTestKey), // Fallback icon from TestConfig
          };
        }).toList();
      },
      loading: () => [], // Return empty list while loading
      error: (_, __) => [], // Return empty list on error
    );
  }

  @override
  Widget build(BuildContext context) {
    final notifier = ref.read(testResultProvider.notifier);
    
    // Get tests dynamically from testParametersProvider (based on API configuration)
    final allTests = _getTestsFromProvider();
    
    // Get total number of tests from API (dynamic)
    final testParametersAsync = ref.read(testParametersProvider);
    final totalTests = testParametersAsync.when(
      data: (testParameters) => testParameters.length,
      loading: () => 0,
      error: (_, __) => 0,
    );
    
    // Calculate health score with dynamic total from API
    final healthScore = notifier.calculateHealthScore(totalTests);
    final pendingCount = notifier.getPendingCount();
    final failedCount = notifier.getFailedCount();
    final naCount = notifier.getNaCount();


    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            /// Header
            CommonHeader(
              title: AppStrings.welcomeTitle,
              version: AppStrings.appVersion,
              onBack: () => Navigator.of(context).pop(),
            ),
            
            const SizedBox(height: 8), // Reduced from 16
            
            /// Progress Bar (100% completion) - Above cards
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        '100% complete',
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
                    child: LinearProgressIndicator(
                      value: 1.0, // 100% complete
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
            
            const SizedBox(height: 12), // Reduced from 16
            
            /// Summary Cards - two rows of two (2x2 pair layout)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Column(
                children: [
                  /// Row 1: Health Score | Test Skipped
                  Row(
                    children: [
                      Expanded(
                        child: _SummaryCard(
                          value: healthScore,
                          label: 'Health Score',
                          color: AppColors.success,
                          isLarge: false,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _SummaryCard(
                          value: pendingCount.toString(),
                          label: 'Test Skipped',
                          color: Colors.orange,
                          isLarge: false,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  /// Row 2: Test Failed | Test NA
                  Row(
                    children: [
                      Expanded(
                        child: _SummaryCard(
                          value: failedCount.toString(),
                          label: 'Test Failed',
                          color: Colors.red,
                          isLarge: false,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _SummaryCard(
                          value: naCount.toString(),
                          label: 'Test NA',
                          color: Colors.grey,
                          isLarge: false,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            
            const SizedBox(height: 24),
            
            /// Test Grid
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: allTests.isEmpty
                    ? const Center(
                        child: CircularProgressIndicator(),
                      )
                    : GridView.builder(
                        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 4,
                          crossAxisSpacing: 12,
                          mainAxisSpacing: 12,
                          childAspectRatio: 0.85,
                        ),
                        itemCount: allTests.length,
                        itemBuilder: (context, index) {
                          final test = allTests[index];
                          final result = notifier.getResult(test['id'] as String);
                          return _TestGridItem(
                            catIcon: test['catIcon'] as String?,
                            fallbackIcon: test['fallbackIcon'] as IconData,
                            label: test['label'] as String,
                            status: result?.status ?? TestStatus.pending,
                          );
                        },
                      ),
              ),
            ),
            
            const SizedBox(height: 24),
            
            /// Submit Report Button with Progress Indicator
            Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                children: [
                  /// Progress Bar (shown while submitting)
                  if (_isSubmittingReport) ...[
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        backgroundColor: AppColors.surface,
                        valueColor: const AlwaysStoppedAnimation<Color>(
                          AppColors.primary,
                        ),
                        minHeight: 4,
                      ),
                    ),
                    const SizedBox(height: 12),
                  ],
                  
                  /// Submit Button
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: ElevatedButton(
                      onPressed: _isSubmittingReport ? null : _handleSubmitReport,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        disabledBackgroundColor: AppColors.disabled,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      child: _isSubmittingReport
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                              ),
                            )
                          : const Text(
                              'Submit Report',
                              style: TextStyle(
                                fontSize: 16,
                                color: Colors.white,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SummaryCard extends StatelessWidget {
  final String value;
  final String label;
  final Color color;
  final bool isLarge;

  const _SummaryCard({
    required this.value,
    required this.label,
    required this.color,
    this.isLarge = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(isLarge ? 10 : 8), // Reduced padding more
      constraints: BoxConstraints(
        maxHeight: isLarge ? 70 : 40, // Reduced max height more
      ),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border, width: 1),
      ),
      child: isLarge
          ? Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.center, // Center aligned
              children: [
                Text(
                  value,
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                        fontSize: 24, // Reduced from 32
                        fontWeight: FontWeight.bold,
                        color: color,
                      ),
                ),
                const SizedBox(height: 4),
                Text(
                  label,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        fontSize: 11, // Reduced from 12
                        color: color,
                      ),
                ),
              ],
            )
          : Row(
              mainAxisAlignment: MainAxisAlignment.start, // Left aligned
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Text(
                  value,
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                        fontSize: 18, // Reduced from 24
                        fontWeight: FontWeight.bold,
                        color: color,
                      ),
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(width: 8),

                Flexible(
                  child: Text(
                    label,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          fontSize: 11, // Reduced from 12
                          color: color,
                        ),
                    textAlign: TextAlign.left, // Left aligned
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
    );
  }
}

class _TestGridItem extends StatelessWidget {
  final String? catIcon; // Icon path from API (e.g., "Wifi.png")
  final IconData fallbackIcon; // Fallback icon from TestConfig
  final String label;
  final TestStatus status;


  const _TestGridItem({
    this.catIcon,
    required this.fallbackIcon,
    required this.label,
    required this.status,
  });

  Color _getStatusColor() {
    switch (status) {
      case TestStatus.pass:
        return AppColors.white;
      case TestStatus.fail:
        return Colors.red.shade100;
      case TestStatus.na:
        return Colors.grey.shade300;
      case TestStatus.skip:
      case TestStatus.pending:
        return Colors.yellow.shade100;
    }
  }

  /// Build icon widget - tries API icon first, falls back to TestConfig icon on error
  /// Supports both HTTP URLs (future) and local asset paths (current)
  Widget _buildIcon() {
    // If catIcon is provided, try to load it
    if (catIcon != null && catIcon!.isNotEmpty) {
      // Check if catIcon is an HTTP/HTTPS URL
      final isHttpUrl = catIcon!.startsWith('http://') || catIcon!.startsWith('https://');
      
      if (isHttpUrl) {
        // Load from HTTP URL (future API response)
        return Image.network(
          catIcon!,
          width: 32,
          height: 32,
          fit: BoxFit.contain,
          errorBuilder: (context, error, stackTrace) {
            // If network image fails to load, use fallback icon from TestConfig
            return Icon(
              fallbackIcon,
              size: 32,
              color: AppColors.primary,
            );
          },
          loadingBuilder: (context, child, loadingProgress) {
            // Show fallback icon while loading
            if (loadingProgress == null) {
              return child;
            }
            return Icon(
              fallbackIcon,
              size: 32,
              color: AppColors.primary,
            );
          },
        );
      } else {
        Icon(
          fallbackIcon,
          size: 32,
          color: AppColors.primary,
        );
      }
    }
    
    // If no catIcon provided, use fallback icon
    return Icon(
      fallbackIcon,
      size: 32,
      color: AppColors.primary,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: _getStatusColor(),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: AppColors.border,
          width: 1,
        ),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _buildIcon(),
          const SizedBox(height: 8),
          Text(
            label,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  fontSize: 10,
                  color: AppColors.text,
                  fontWeight: FontWeight.w500,
                ),
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );

  }
}

