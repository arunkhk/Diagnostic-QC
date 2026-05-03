import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_strings.dart';
import 'dart:convert';
import '../../core/widgets/common_header.dart';
import '../../core/widgets/common_button.dart';
import '../../core/widgets/common_toast.dart';
import '../../core/services/api_service.dart';
import '../../features/auth/providers/auth_provider.dart';
import '../../features/verification/providers/imei_provider.dart';
import '../../features/verification/imei_verification_screen.dart';
import 'models/diagnosis_parameters_response.dart';
import 'success_screen.dart';
import 'models/diagnosis_summary_request.dart';
import 'models/final_diagnosis_request.dart';
import 'models/test_result.dart';
import 'utils/test_param_mapping.dart';
import 'providers/test_result_provider.dart';
import 'providers/test_parameters_provider.dart';
import 'models/test_parameter_item.dart';

class FinalDiagnosisScreen extends ConsumerStatefulWidget {
  final DiagnosisParametersResponse parameters;

  const FinalDiagnosisScreen({
    super.key,
    required this.parameters,
  });

  @override
  ConsumerState<FinalDiagnosisScreen> createState() => _FinalDiagnosisScreenState();
}

class _FinalDiagnosisScreenState extends ConsumerState<FinalDiagnosisScreen> {
  List<String> _selectedFinalDiagnosisFailRemarks = [];
  List<String> _selectedDevicePhysicalCondition = [];
  List<String> _selectedDisplayCondition = [];
  bool _qcPass = false;
  bool _qcFail = false;
  final TextEditingController _feedbackController = TextEditingController();
  bool _isSubmitting = false;

  @override
  void dispose() {
    _feedbackController.dispose();
    super.dispose();
  }

  void _handleQcPassChanged(bool? value) {
    setState(() {
      _qcPass = value ?? false;
      if (_qcPass) {
        _qcFail = false; // Uncheck QC Fail if QC Pass is checked
        // Clear Final Diagnosis Fail Remarks when QC Pass is selected
        _selectedFinalDiagnosisFailRemarks = [];
      }
    });
  }

  void _handleQcFailChanged(bool? value) {
    setState(() {
      _qcFail = value ?? false;
      if (_qcFail) {
        _qcPass = false; // Uncheck QC Pass if QC Fail is checked
      }
    });
  }

  /// Convert test status to API format (Pass, Fail, or NA for final submit)
  String _getDiagnosedResult(String testId, TestStatus status) {
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

  /// Get tests from testParametersProvider (dynamic based on API configuration)
  /// Returns list of test parameters from the API
  List<TestParameterItem> _getTestsFromProvider() {
    final testParametersAsync = ref.read(testParametersProvider);
    
    return testParametersAsync.when(
      data: (testParameters) {
        // Sort by displayOrder to maintain correct sequence
        final sortedParams = List<TestParameterItem>.from(testParameters)
          ..sort((a, b) => a.displayOrder.compareTo(b.displayOrder));
        return sortedParams;
      },
      loading: () => [], // Return empty list while loading
      error: (_, __) => [], // Return empty list on error
    );
  }

  /// Build diagnosis summary test parameters from test results
  /// Uses test parameters from API (testParametersProvider) to determine which tests to include
  /// Marks unrun tests as "Skipped"
  List<DiagnosisSummaryTestParam> _buildDiagnosisSummaryParams({
    required int diagnosisSummaryID,
    required int createdBy,
  }) {
    final testResults = ref.read(testResultProvider);
    final testParams = <DiagnosisSummaryTestParam>[];
    
    // Create a map of testId to TestResult for quick lookup
    final testResultMap = <String, TestResult>{};
    for (final result in testResults) {
      testResultMap[result.testId] = result;
    }

    // Get all tests from testParametersProvider (dynamic based on API configuration)
    final testParameters = _getTestsFromProvider();

    // Iterate through ALL tests from the API configuration
    for (final testParameter in testParameters) {
      final testId = testParameter.uniqueTestKey;
      
      // Get test result if it exists, otherwise mark as skipped
      final result = testResultMap[testId];
      final status = result?.status ?? TestStatus.skip;
      final diagnosedResult = _getDiagnosedResult(testId, status);

      // Use the test parameter directly from API (diagnoseParamID and paramValue)
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

  Future<void> _handleSubmit() async {
    // Validate that at least one QC option is selected
    if (!_qcPass && !_qcFail) {
      CommonToast.showError(
        context,
        message: 'Please select QC Pass or QC Fail',
      );
      return;
    }

    // Validate that Final Diagnosis Fail Remarks is selected if QC Fail is checked
    if (_qcFail && _selectedFinalDiagnosisFailRemarks.isEmpty) {
      CommonToast.showError(
        context,
        message: 'Please select at least one Final Diagnosis Fail Remark',
      );
      return;
    }

    setState(() {
      _isSubmitting = true;
    });

    Map<String, dynamic>? requestBody;
    String? apiUrl;
    
    try {
      // Get diagnosis summary ID from IMEI verification
      final imeiState = ref.read(imeiVerificationProvider);
      final diagnosisSummaryId = imeiState.response?.diagnosisSummarMasterId;

      if (diagnosisSummaryId == null) {
        if (mounted) {
          CommonToast.showError(
            context,
            message: 'Diagnosis Summary ID not found',
          );
          setState(() {
            _isSubmitting = false;
          });
        }
        return;
      }

      // Get user ID from auth provider
      final authState = ref.read(authProvider);
      final userId = authState.user?.userId;

      if (userId == null) {
        if (mounted) {
          CommonToast.showError(
            context,
            message: 'User ID not found',
          );
          setState(() {
            _isSubmitting = false;
          });
        }
        return;
      }

      // Build diagnosis summary test parameters
      final testParams = _buildDiagnosisSummaryParams(
        diagnosisSummaryID: diagnosisSummaryId,
        createdBy: userId,
      );

      // Prepare final diagnosis request data
      final imeiResponse = imeiState.response!;
      
      // Format Device Physical Condition: comma-separated values or "OK" if not selected
      final devicePhysicalCondition = _selectedDevicePhysicalCondition.isEmpty
          ? 'OK'
          : _selectedDevicePhysicalCondition.join(', ');
      
      // Format Displayfault: "Yes" if Display Condition has values, "No" if not selected
      final displayfault = _selectedDisplayCondition.isEmpty ? 'No' : 'Yes';
      
      // Format DisplayDetails: comma-separated values from Display Condition or "No" if not selected
      final displayDetails = _selectedDisplayCondition.isEmpty
          ? 'No'
          : _selectedDisplayCondition.join(', ');

      // Determine OverallRemarksStatus, FailureRemarks, and FinalStatusRemarks based on QC selection
      String overallRemarksStatus;
      String failureRemarks;
      String finalStatusRemarks;
      
      if (_qcPass) {
        // QC Pass selected
        overallRemarksStatus = 'Ok';
        failureRemarks = 'No';
        finalStatusRemarks = 'OK';
      } else if (_qcFail) {
        // QC Fail selected
        overallRemarksStatus = 'No';
        // FailureRemarks: comma-separated values from Final Diagnosis Fail Remarks
        failureRemarks = _selectedFinalDiagnosisFailRemarks.isEmpty
            ? 'No'
            : _selectedFinalDiagnosisFailRemarks.join(', ');
        finalStatusRemarks = 'NO';
      } else {
        // Default (should not happen as we validate earlier)
        overallRemarksStatus = 'No';
        failureRemarks = 'No';
        finalStatusRemarks = 'OK';
      }
      // Check if all diagnosis parameters are Pass
      final allPass = testParams.every((param) => param.diagnosedResult == 'Pass');
      final diagnoseEngine = allPass ? 'Pass' : 'Fail';

      // Build DiagnosisDetails array from test parameters
      final diagnosisDetails = testParams.map((param) {
        return DiagnosisDetail(
          diagnosisSummaryID: diagnosisSummaryId,
          testParameter: param.testParameter,
          testParameterID: param.testParameterID.toString(), // Convert to string as per API format
          diagnosedResult: param.diagnosedResult,
          diagnosedReason: param.diagnosedReason,
          createdBy: userId,
        );

      }).toList();

      // Create final diagnosis request with DiagnosisDetails array
      final finalDiagnosisRequest = FinalDiagnosisRequest(
        diagnosisSummaryID: diagnosisSummaryId,
        brandID: imeiResponse.brandId,
        modelID: imeiResponse.modelId,
        brandName: imeiResponse.brandName,
        modelName: imeiResponse.modelName,
        overallRemarksStatus: overallRemarksStatus,
        failureRemarks: failureRemarks,
        finalStatusRemarks: finalStatusRemarks,
        devicePhysicalCondition: devicePhysicalCondition,
        displayfault: displayfault,
        displayDetails: displayDetails,
        createdBy: userId,
        diagnosisDetails: diagnosisDetails,
        diagnoseEngine: diagnoseEngine,
        feedback: _feedbackController.text.trim().isEmpty 
            ? null 
            : _feedbackController.text.trim(),
      );

      // Log feedback value for debugging
      final feedbackValue = _feedbackController.text.trim();
      print('📝 Feedback field value: "${feedbackValue.isEmpty ? '(empty)' : feedbackValue}"');
      print('📝 Feedback length: ${feedbackValue.length}');
      print('📝 Feedback is null check: ${feedbackValue.isEmpty}');

      // Convert to JSON for analysis
      final requestJson = finalDiagnosisRequest.toJson();
      
      // Print JSON Summary with key counts
      debugPrint('═══════════════════════════════════════════════════════════');
      debugPrint('📊 JSON SUBMISSION SUMMARY');
      debugPrint('═══════════════════════════════════════════════════════════');
      debugPrint('📋 Top-Level Keys: ${requestJson.keys.length}');
      debugPrint('   Keys: ${requestJson.keys.join(", ")}');
      
      // Count items in arrays
      int totalArrayItems = 0;
      for (var entry in requestJson.entries) {
        if (entry.value is List) {
          final list = entry.value as List;
          totalArrayItems += list.length;
          debugPrint('   ${entry.key}: ${list.length} items (array)');
          if (list.isNotEmpty && list.first is Map) {
            final firstItem = list.first as Map;
            debugPrint('      → First item keys: ${firstItem.keys.join(", ")}');
          }
        } else if (entry.value is Map) {
          final map = entry.value as Map;
          debugPrint('   ${entry.key}: ${map.keys.length} nested keys (object)');
        } else {
          final valueStr = entry.value?.toString() ?? 'null';
          final truncated = valueStr.length > 50 ? '${valueStr.substring(0, 50)}...' : valueStr;
          debugPrint('   ${entry.key}: $truncated');
        }
      }
      
      debugPrint('📦 Total Array Items: $totalArrayItems');
      debugPrint('🔢 Total Top-Level Keys: ${requestJson.keys.length}');
      debugPrint('═══════════════════════════════════════════════════════════');
      
      // Log full JSON body in chunks (to avoid character limit)
      debugPrint('📄 Full JSON Request Body:');
      try {
        final jsonString = const JsonEncoder.withIndent('  ').convert(requestJson);
        // Split into chunks of 800 characters to ensure full output
        const chunkSize = 800;
        for (int i = 0; i < jsonString.length; i += chunkSize) {
          final end = (i + chunkSize < jsonString.length) ? i + chunkSize : jsonString.length;
          debugPrint(jsonString.substring(i, end));
        }
      } catch (e) {
        debugPrint('❌ Error formatting JSON: $e');
        debugPrint('Raw body: $requestJson');
      }
      debugPrint('═══════════════════════════════════════════════════════════');


      // Call API to save final diagnosis (single API call with all data)
      final apiService = ApiService();
      apiUrl = '${ApiService.baseUrl}/PhoneDiagnostics/SaveDiagnoseDetails';
      requestBody = finalDiagnosisRequest.toJson();
      
      final finalDiagnosisResponse = await apiService.post<Map<String, dynamic>>(
        '/PhoneDiagnostics/SaveDiagnoseDetails',
        body: requestBody,
        fromJson: (json) => Map<String, dynamic>.from(json),
      );

      if (mounted) {
        setState(() {
          _isSubmitting = false;
        });

        if (finalDiagnosisResponse.success) {
          // Navigate to success screen
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(
              builder: (_) => const SuccessScreen(
                message: 'Diagnosis submitted successfully!',
                subMessage: 'All test results have been saved.',
              ),
            ),
          );
        } else {
          // Show error dialog with API details
          await _showApiErrorDialog(
            context: context,
            url: apiUrl,
            requestBody: requestBody,
            response: finalDiagnosisResponse.data ?? {'error': finalDiagnosisResponse.errorMessage ?? 'Unknown error'},
            onRetry: () => _handleSubmit(),
            onSkip: () {
              // Navigate to IMEI screen
              Navigator.of(context).pushAndRemoveUntil(
                MaterialPageRoute(builder: (_) => const ImeiVerificationScreen()),
                (route) => false,
              );
            },
          );
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
        });
        
        // Show error dialog for exceptions too
        final errorApiUrl = apiUrl ?? '${ApiService.baseUrl}/PhoneDiagnostics/SaveDiagnoseDetails';
        final errorRequestBody = requestBody ?? {'error': 'Request body not available'};
        
        await _showApiErrorDialog(
          context: context,
          url: errorApiUrl,
          requestBody: errorRequestBody,
          response: {'error': e.toString(), 'type': 'Exception'},
          onRetry: () => _handleSubmit(),
          onSkip: () {
            // Navigate to IMEI screen
            Navigator.of(context).pushAndRemoveUntil(
              MaterialPageRoute(builder: (_) => const ImeiVerificationScreen()),
              (route) => false,
            );
          },
        );
      }
    }
  }

  /// Show API error dialog with details and options
  Future<void> _showApiErrorDialog({
    required BuildContext context,
    required String url,
    required Map<String, dynamic> requestBody,
    required Map<String, dynamic> response,
    required VoidCallback onRetry,
    required VoidCallback onSkip,
  }) async {
    final requestBodyJson = const JsonEncoder.withIndent('  ').convert(requestBody);
    final responseJson = const JsonEncoder.withIndent('  ').convert(response);
    
    final detailsText = '''
URL:
$url

Request Body:
$requestBodyJson

Response:
$responseJson
''';

    await showDialog(
      context: context,
      barrierDismissible: false,
      barrierColor: Colors.black54,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        child: Container(
          constraints: const BoxConstraints(maxWidth: 500, maxHeight: 600),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header with icon
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: AppColors.error.withOpacity(0.1),
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(16),
                    topRight: Radius.circular(16),
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppColors.error,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.error_outline,
                        color: AppColors.white,
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 16),
                    const Expanded(
                      child: Text(
                        'API Request Failed',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: AppColors.error,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              
              // Content
              Flexible(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'The API request failed. Please review the details below:',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          color: AppColors.text,
                        ),
                      ),
                      const SizedBox(height: 16),
                      
                      // URL Section
                      _buildDetailSection(
                        context,
                        title: 'URL',
                        content: url,
                        icon: Icons.link,
                      ),
                      const SizedBox(height: 12),
                      
                      // Request Body Section
                      _buildDetailSection(
                        context,
                        title: 'Request Body',
                        content: requestBodyJson,
                        icon: Icons.code,
                      ),
                      const SizedBox(height: 12),
                      
                      // Response Section
                      _buildDetailSection(
                        context,
                        title: 'Response',
                        content: responseJson,
                        icon: Icons.description,
                      ),
                    ],
                  ),
                ),
              ),
              
              // Divider
              const Divider(height: 1),
              
              // Action Buttons
              Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    // Copy button
                    OutlinedButton.icon(
                      onPressed: () {
                        Clipboard.setData(ClipboardData(text: detailsText));
                        Navigator.of(context).pop();
                        CommonToast.showSuccess(
                          context,
                          message: 'API details copied to clipboard',
                        );
                      },
                      icon: const Icon(Icons.copy, size: 18),
                      label: const Text('Copy'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.primary,
                        side: BorderSide(color: AppColors.primary),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 12,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    // Skip button
                    OutlinedButton(
                      onPressed: () {
                        Navigator.of(context).pop();
                        onSkip();
                      },
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.textSecondary,
                        side: BorderSide(color: AppColors.border),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 12,
                        ),
                      ),
                      child: const Text('Skip'),
                    ),
                    const SizedBox(width: 8),
                    // Retry button
                    ElevatedButton.icon(
                      onPressed: () {
                        Navigator.of(context).pop();
                        onRetry();
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: AppColors.white,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 12,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      icon: const Icon(Icons.refresh, size: 18),
                      label: const Text('Retry'),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Build a detail section with title and content
  Widget _buildDetailSection(
    BuildContext context, {
    required String title,
    required String content,
    required IconData icon,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Section header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: AppColors.primary.withOpacity(0.1),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(12),
                topRight: Radius.circular(12),
              ),
            ),
            child: Row(
              children: [
                Icon(icon, size: 16, color: AppColors.primary),
                const SizedBox(width: 8),
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: AppColors.primary,
                  ),
                ),
              ],
            ),
          ),
          // Content
          Padding(
            padding: const EdgeInsets.all(12),
            child: SelectableText(
              content,
              style: const TextStyle(
                fontSize: 11,
                fontFamily: 'monospace',
                color: AppColors.text,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            /// Header
            CommonHeader(
              title: 'Final Diagnosis',
              version: AppStrings.appVersion,
              onBack: () => Navigator.of(context).pop(),
            ),

            /// Content
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    /// Device Physical Condition Multi-Select
                    _buildMultiSelectDropdown(
                      label: 'Device Physical Condition',
                      selectedValues: _selectedDevicePhysicalCondition,
                      items: widget.parameters.devicePhysicalCondition,
                      onSelectionChanged: (selected) {
                        setState(() {
                          _selectedDevicePhysicalCondition = selected;
                        });
                      },
                    ),

                    const SizedBox(height: 24),

                    /// Display Condition Multi-Select
                    _buildMultiSelectDropdown(
                      label: 'Display Condition',
                      selectedValues: _selectedDisplayCondition,
                      items: widget.parameters.displayCondition,
                      onSelectionChanged: (selected) {
                        setState(() {
                          _selectedDisplayCondition = selected;
                        });
                      },
                    ),

                    const SizedBox(height: 32),

                    /// QC Pass/Fail Checkboxes
                    Text(
                      'QC Status',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: AppColors.text,
                          ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: _buildCheckbox(
                            label: 'QC Pass',
                            value: _qcPass,
                            onChanged: _handleQcPassChanged,
                            color: AppColors.success,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: _buildCheckbox(
                            label: 'QC Fail',
                            value: _qcFail,
                            onChanged: _handleQcFailChanged,
                            color: AppColors.error,
                          ),
                        ),
                      ],
                    ),

                    /// Final Diagnosis Fail Remarks Multi-Select (only visible when QC Fail is selected)
                    if (_qcFail) ...[
                      const SizedBox(height: 24),
                      _buildMultiSelectDropdown(
                        label: 'Final Diagnosis Fail Remarks',
                        selectedValues: _selectedFinalDiagnosisFailRemarks,
                        items: widget.parameters.finalDiagnosisFailRemarks,
                        onSelectionChanged: (selected) {
                          setState(() {
                            _selectedFinalDiagnosisFailRemarks = selected;
                          });
                        },
                      ),
                    ],

                    const SizedBox(height: 32),

                    /// Feedback Field
                    Text(
                      'Feedback',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: AppColors.text,
                          ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _feedbackController,
                      maxLines: 5,
                      decoration: InputDecoration(
                        hintText: 'Enter your feedback...',
                        hintStyle: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: AppColors.textTertiary,
                            ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: AppColors.border),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: AppColors.border),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: AppColors.primary, width: 2),
                        ),
                        filled: true,
                        fillColor: AppColors.white,
                        contentPadding: const EdgeInsets.all(16),
                      ),
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: AppColors.text,
                          ),
                    ),

                    const SizedBox(height: 32),
                  ],
                ),
              ),
            ),

            /// Submit Button
            Padding(
              padding: const EdgeInsets.all(24),
              child: CommonButton(
                text: 'Submit',
                onPressed: _isSubmitting ? null : _handleSubmit,
                isLoading: _isSubmitting,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMultiSelectDropdown({
    required String label,
    required List<String> selectedValues,
    required List<String> items,
    required ValueChanged<List<String>> onSelectionChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: AppColors.text,
              ),
        ),
        const SizedBox(height: 12),
        
        /// Selected Values Display (Chips)
        if (selectedValues.isNotEmpty) ...[
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: selectedValues.map((value) {
              return Chip(
                label: Text(
                  value,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppColors.white,
                        fontSize: 12,
                      ),
                ),
                backgroundColor: AppColors.primary,
                deleteIcon: const Icon(
                  Icons.close,
                  size: 18,
                  color: AppColors.white,
                ),
                onDeleted: () {
                  final updatedList = List<String>.from(selectedValues)..remove(value);
                  onSelectionChanged(updatedList);
                },
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              );
            }).toList(),
          ),
          const SizedBox(height: 12),
        ],
        
        /// Dropdown Button
        Container(
          decoration: BoxDecoration(
            color: AppColors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.border),
          ),
          child: InkWell(
            onTap: () {
              _showMultiSelectDialog(
                label: label,
                items: items,
                selectedValues: selectedValues,
                onSelectionChanged: onSelectionChanged,
              );
            },
            borderRadius: BorderRadius.circular(12),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      selectedValues.isEmpty
                          ? 'Select $label'
                          : '${selectedValues.length} item(s) selected',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: selectedValues.isEmpty
                                ? AppColors.textTertiary
                                : AppColors.text,
                          ),
                    ),
                  ),
                  Icon(
                    Icons.arrow_drop_down,
                    color: AppColors.textSecondary,
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  void _showMultiSelectDialog({
    required String label,
    required List<String> items,
    required List<String> selectedValues,
    required ValueChanged<List<String>> onSelectionChanged,
  }) {
    final tempSelected = List<String>.from(selectedValues);
    
    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(
            'Select $label',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
          ),
          content: SizedBox(
            width: double.maxFinite,
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: items.length,
              itemBuilder: (context, index) {
                final item = items[index];
                final isSelected = tempSelected.contains(item);
                
                return CheckboxListTile(
                  title: Text(
                    item,
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  value: isSelected,
                  onChanged: (bool? value) {
                    setDialogState(() {
                      if (value == true) {
                        tempSelected.add(item);
                      } else {
                        tempSelected.remove(item);
                      }
                    });
                  },
                );
              },
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () {
                onSelectionChanged(tempSelected);
                Navigator.of(context).pop();
              },
              child: const Text('Done'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCheckbox({
    required String label,
    required bool value,
    required ValueChanged<bool?> onChanged,
    required Color color,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: value ? color : AppColors.border,
          width: value ? 2 : 1,
        ),
      ),
      child: CheckboxListTile(
        title: Text(
          label,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: AppColors.text,
                fontWeight: FontWeight.w500,
              ),
        ),
        value: value,
        onChanged: onChanged,
        activeColor: color,
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        dense: true,
      ),
    );
  }
}

