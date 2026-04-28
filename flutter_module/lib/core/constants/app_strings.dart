/// Centralized copy strings to keep UI text consistent.
class AppStrings {
  AppStrings._();

  static const String appName = 'Device Diagnosis';
  static const String appVersion = '1.0.0';
  static const String welcomeTitle = 'Diagnosis';

  static const String getStarted = 'Get Started';
  static const String runningButton = 'Running…';
  static const String getStartedSnack = 'Get Started Clicked';
  static const String readyStatus = 'Ready to diagnose your device';
  static const String runningStatus = 'Running quick sensor sweep…';
  static const String successStatus = 'All sensors responded normally';

  // Login Screen
  static const String smartDiagnosisTitle = 'Smart Diagnosis';
  static const String signInToAccount = 'Sign in to your account';
  static const String employeeId = 'Employee ID';
  static const String enterEmployeeId = 'Enter your Employee ID';
  static const String password = 'Password';
  static const String enterPassword = 'Enter your password';
  static const String forgotPassword = 'Forgot password?';
  static const String userAgreement = 'User Agreement';
  static const String privacyPolicy = 'Privacy Policy';
  static const String signIn = 'Sign In';
  static const String forgotPasswordDescription = 'Enter your email or phone number and we\'ll send you instructions to reset your password.';
  static const String emailOrPhone = 'Email or Phone Number';
  static const String enterEmailOrPhone = 'Enter your email or phone number';
  static const String resetPassword = 'Reset Password';
  static const String passwordResetSent = 'Password reset instructions have been sent to your registered email or phone.';

  // Permissions Screen (using welcomeTitle for consistency)
  static const String permissionsMainTitle = 'Unlock Full Device Insights';
  static const String permissionsSubtitle =
      'Allow access to essential device features to complete and accurate health diagnosis.';
  static const String grantPermissionButton = 'Grant Permission & Proceed';
  // All Android Permissions
  static const String permissionCamera = 'Camera';
  static const String permissionMicrophone = 'Microphone';
  static const String permissionStorage = 'Storage & Files';
  static const String permissionPhotos = 'Photos & Media';
  static const String permissionLocation = 'Location';
  static const String permissionLocationAlways = 'Location (Always)';
  static const String permissionContacts = 'Contacts';
  static const String permissionPhone = 'Phone';
  static const String permissionSms = 'SMS';
  static const String permissionCalendar = 'Calendar';
  static const String permissionReminders = 'Reminders';
  static const String permissionBluetooth = 'Bluetooth';
  static const String permissionBluetoothScan = 'Bluetooth Scan';
  static const String permissionBluetoothConnect = 'Bluetooth Connect';
  static const String permissionWifi = 'Wi-Fi';
  static const String permissionNotification = 'Notifications';
  static const String permissionBodySensors = 'Body Sensors';
  static const String permissionActivityRecognition = 'Activity Recognition';
  static const String permissionManageExternalStorage = 'Manage Storage';
  static const String requestAllPermissions = 'Request All Permissions';
  static const String continueButton = 'Continue';

  // Diagnosis Screen
  static const String skipButton = 'Skip >>';
  static const String scanningDevice = 'Scanning Device...';
  static const String connectivityFeatures = 'Connectivity Features';
  static const String wifi = 'Wi-Fi';
  static const String wifiWorkingFlawlessly = 'Working flawlessly';
  static const String notConnected = 'Not Connected';
  static const String bluetooth = 'Bluetooth';
  static const String gps = 'Gps';
  static const String diagnosing = 'Diagnosing';
  static const String foundWifiNetworks = 'Found {count} Wi-Fi Networks';
  
  // Diagnosis Screen Dialogs
  static const String deviceDiagnosisTitle = 'Device Diagnosis';
  static const String deviceDiagnosisMessage = 'For better health check of device, please enable Wi-Fi, Bluetooth, and Location.';
  static const String proceedButton = 'Proceed';
  static const String wifiDisabledTitle = 'Wi-Fi is Disabled';
  static const String wifiDisabledMessage = 'Wi-Fi is currently turned off on your device. Please enable Wi-Fi to continue with the diagnosis.';
  static const String bluetoothDisabledTitle = 'Bluetooth is Disabled';
  static const String bluetoothDisabledMessage = 'Bluetooth is currently turned off on your device. Please enable Bluetooth to continue with the diagnosis.';
  static const String enableButton = 'Enable';
  static const String proceedWithoutEnableButton = 'Proceed without Enable';

  // IMEI Verification Screen
  static const String verifyDeviceTitle = 'Verify Device';
  static const String verifyDeviceDescription = 'Enter IMEI number if Unique ID is not applicable. Unique ID validates from linked DB whereas IMEI is generic.';
  static const String imeiNumber = 'IMEI Number';
  static const String imeiPlaceholder = 'Enter 15-digit IMEI number';
  static const String enterImeiError = 'Please enter an IMEI number';
  static const String invalidImeiError = 'Please enter a valid 15-digit IMEI number';

  // Permissions Screen Dialogs
  static const String permissionRequired = 'Permission Required';
  static const String permissionsRequired = 'Permissions Required';
  static const String somePermissionsDenied = 'Some Permissions Denied';
  static const String permissionDeniedMessage =
      'Some permissions were denied. Please enable them in settings to continue.';
  static const String permissionDeniedInfoMessage =
      '{count} permission(s) were denied. You can continue using the app, and we\'ll ask for these permissions again when they\'re needed.';
  static const String permissionDeniedIndividualMessage =
      '{permission} permission is required. Please enable it in settings.';
  static const String cancelButton = 'Cancel';
  static const String openSettingsButton = 'Open Settings';
  static const String requestingPermissions = 'Requesting...';
  static const String permissionsHelperText =
      'You can continue even if some permissions are denied. We\'ll ask again when needed.';
  static const String requiredPermissions = 'Required Permissions';
  static const String optionalPermissions = 'Optional Permissions';
  static const String requiredBadge = 'Required';
  // SD Card Detection Screen

  static const String scanningSdCard = 'Scanning SD Card...';
  static const String checkingCardHealth =
      'Checking card health and integrity. Please wait.';
  static const String sdCardNotDetected = 'SD Card Not Detected';
  static const String sdCardDetected = 'SD Card Detected';
  static const String noSdCardFound =
      'No SD card was found in your device. Please insert one to proceed.';
  static const String sdCardFound =
      'SD card was found in your device and is working correctly.';
  static const String sdCardWorking = 'SD Card: Working';
  static const String sdCardWorkingCorrectly =
      'Your SD card is working correctly. No issues detected.';
  static const String proceedAnywayButton = 'Proceed Anyway';

  // Charger Test Screen
  static const String connectCharger = 'Connect your charger';
  static const String plugInChargerInstruction =
      'Please plug in device\'s charger to begin the power test.';
  static const String chargerConnected = 'Charger connected';
  static const String chargerNotConnected = 'Charger not connected';
  static const String chargerWorkingCorrectly =
      'Your charger and charging port are working correctly. No issues detected.';
  static const String chargerIssueDetected =
      'Charger or charging port issue detected. Please check your charger.';

  // Battery Health Screen
  static const String checkingBatteryHealth = 'Checking Battery Health ...';
  static const String analyzingBatteryPerformance =
      'Analyzing charge capacity health, cycle count, and overall battery performance. Please wait.';
  static const String batteryHealthGood = 'Battery Health: Good';
  static const String batteryHealthPoor = 'Battery Health: Poor';
  static const String batteryHealthOptimal = 'Health Status: Optimal';
  static const String batteryCurrentLevel = 'Current Level: 92%';
  static const String batteryTemperature = 'Temperature: 30.5 C';
  static const String batteryVoltage = 'Voltage: 4.2V';
  static const String batteryTechnology = 'Technology: Li-ion';
  static const String batteryHealthIssue =
      'Battery health issue detected. Please check your device battery.';

  // Touch Screen Test Screen
  static const String touchScreenTest = 'Touch Screen Test...';
  static const String touchScreenInstruction =
      'To test your screen\'s touch capability, place fingers on the screen and fill the blocks simultaneously.';
  static const String beginTestButton = 'Start Test';
  static const String touchScreenWorking = 'Touch Screen Working';
  static const String touchScreenNotWorking = 'Touch Screen Not Working';
  static const String touchScreenWorkingCorrectly =
      'Your touch screen is working correctly. No issues detected.';
  static const String touchScreenIssueDetected =
      'Touch screen issue detected. Please check your device screen.';
  // Proximity Sensor Screen
  static const String testingProximitySensor = 'Testing Proximity Sensor...';
  static const String proximitySensorInstruction =
      'Place your hand or the object near the top of your screen to activate sensor.';
  static const String sensorDetected = 'Sensor Detected!';
  static const String sensorNotDetected = 'Sensor Not Detected';
  static const String proximitySensorWorkingCorrectly =
      'Your proximity sensor is working correctly. No issues detected.';
  static const String proximitySensorIssueDetected =
      'Proximity sensor issue detected. Please check your device sensor.';

  // Light Sensor Screen
  static const String testingLightSensor = 'Testing Light Sensor...';
  static const String lightSensorInstruction =
      'Cover the light sensor with finger or expose to light to test its functionality.';
  static const String lightSensorDetected = 'Light Sensor: Detected';
  static const String lightSensorNotDetected = 'Light Sensor: Not Detected';
  static const String lightQuantity = 'Light Quantity: 58.76 lux';
  static const String lightSensorStatus = 'Status: Responding';
  static const String lightSensorIssueDetected =
      'Light sensor issue detected. Please check your device sensor.';

  // Volume Button Screen
  static const String checkingVolumeButton = 'Checking Volume Button...';
  static const String volumeButtonInstruction =
      'Press the "Volume Up" and "Volume Down" buttons. We\'ll register each press.';
  static const String volumeUpPressed = 'Volume Up Pressed!';
  static const String volumeDownPressed = 'Volume Down Pressed!';
  static const String volumeButtonsWorking = 'Volume Buttons: Working';
  static const String volumeButtonsWorkingCorrectly =
      'Your volume buttons are working correctly. No issues detected.';

  // Back Button Screen
  static const String testingBackButton = 'Testing Back Button...';
  static const String backButtonInstruction =
      'Press the Back button on your device to confirm it\'s working correctly.';
  static const String backButtonPressed = 'Back Button Pressed!';
  static const String backButtonWorking = 'Back Button: Working';
  static const String backButtonWorkingCorrectly =
      'Your back button is working correctly. No issues detected.';

  // Power Button Screen
  static const String testingPowerButton = 'Testing Power Button...';
  static const String powerButtonInstruction =
      'Press the Power button once. We\'ll detect the button press automatically.';
  static const String powerButtonPressed = 'Power Button Pressed!';
  static const String powerButtonWorking = 'Power Button: Working';
  static const String powerButtonWorkingCorrectly =
      'Your power button is working correctly. No issues detected.';

  // Home Button Screen
  static const String testingHomeButton = 'Testing Home Button...';
  static const String homeButtonInstruction =
      'Press the Home button on your device to verify it\'s functioning.';
  static const String homeButtonPressed = 'Home Button Pressed!';
  static const String homeButtonWorking = 'Home Button: Working';
  static const String homeButtonWorkingCorrectly =
      'Your home button is working correctly. No issues detected.';

  // Menu Button Screen
  static const String testingMenuButton = 'Testing Menu Button...';
  static const String menuButtonInstruction =
      'Press the Menu button on your device. We\'ll confirm the response.';
  static const String menuButtonPressed = 'Menu Button Pressed!';
  static const String menuButtonWorking = 'Menu Button: Working';
  static const String menuButtonWorkingCorrectly =
      'Your menu button is working correctly. No issues detected.';

  // Screen Rotation Screen
  static const String testingScreenRotation = 'Testing Screen rotation...';
  static const String screenRotationInstruction =
      'Rotate your device to check screen orientation.';
  static const String screenRotatedHorizontally = 'Screen Rotated Horizontally!';
  static const String screenRotationWorking = 'Screen Rotation: Working';
  static const String screenRotationWorkingCorrectly =
      'Your screen rotation is working correctly. No issues detected.';

  // Screen Brightness Screen
  static const String testingScreenBrightness = 'Testing Screen Brightness...';
  static const String screenBrightnessInstruction =
      'Observe the screen as its brightness adjusts. Pay attention to any noticeable changes.';
  static const String brightnessQuestion =
      'Did you observe as the screen brightness changing?';
  static const String yesButton = 'Yes';
  static const String screenBrightnessWorking = 'Screen Brightness: Working';
  static const String screenBrightnessWorkingCorrectly =
      'Your screen brightness is working correctly. No issues detected.';
  static const String screenBrightnessIssueDetected =
      'Screen brightness issue detected. Please check your device settings.';

  // OTG Connectivity Screen
  static const String otgConnectivityTest = 'OTG Connectivity Test...';
  static const String otgConnectivityInstruction =
      'Please plug an OTG device into your phone\'s charging/data port. This could be a USB drive, a keyboard, or a mouse connected via an OTG adapter.';
  static const String otgDeviceDetected = 'OTG Device Detected!';
  static const String otgConnectivityWorking = 'OTG Connectivity: Working';
  static const String otgConnectivityWorkingCorrectly =
      'Your OTG connectivity is working correctly. No issues detected.';

  // Network Connectivity Screen
  static const String checkingNetworkConnectivity = 'Checking Network Connectivity...';
  static const String networkConnectivityInstruction =
      'Enter the test number and initiate call to verify network connectivity..';
  static const String callingNumber = 'Calling Number';
  static const String enterMobileNumber = 'Enter 10-digit mobile number';
  static const String callButton = 'Call';
  static const String passButton = 'Pass';
  static const String failButton = 'Fail';
  static const String naButton = 'NA';
  static const String networkConnectivitySuccess = 'Your call was successfully connected. Network connectivity is working properly.';
  static const String networkConnectivityFailed = 'The call could not be connected. Please check your SIM card or network signal and try again.';
  static const String callConnectedToast = 'Call has been connected!';

  // Speaker Test Screen
  static const String testingSpeaker = 'Testing Speaker...';
  static const String speakerTestInstruction =
      'Kindly set your device volume maximum level and tap \'Play Audio\' below to evaluate speaker functionality.';
  static const String playAudioButton = 'Play Audio';
  static const String playAudioAgainButton = 'Play Audio Again';
  static const String enterThreeDigitNumber = 'Enter 3-Digit Number You Hear';
  static const String valueRangeHint = 'Enter 3 unique digits (0-9)';
  static const String speakerPassToast = 'Speaker is pass';
  static const String speakerFailToast = 'Speaker fail';

  // Flashlight Test Screen
  static const String testingFlashlight = 'Testing Flashlight...';
  static const String flashlightTestInstruction = 'Verify your device\'s flashlight functionality below.';
  static const String flashlightTestInstructionWithInput = 'Enter the test number and verify your device\'s flashlight functionality below.';
  static const String flashlightNumberLabel = 'Flashlight Number From 1-5';
  static const String flashlightNumberPlaceholder = 'enter the number of time flashlight turned on';
  static const String submitButton = 'Submit';
  static const String flashlightWorkingToast = 'Flashlight Working';
  static const String flashlightNotWorkingToast = 'Flashlight Not Working';
  static const String flashlightWorkingProperly = 'Flashlight Working Properly!';

  // Vibration Test Screen
  static const String testingVibration = 'Testing vibration...';
  static const String vibrationTestInstruction = 'Tap below to start mobile vibration and feel your device vibrate.';
  static const String vibrationTestInstructionWithInput = 'Enter the test number and inform mobile vibration and your device vibrate duration.';
  static const String vibrationNumberLabel = 'Vibration Number From 1-5';
  static const String vibrationNumberPlaceholder = 'no. of vibration';
  static const String startVibrationButton = 'Start Vibration';
  static const String vibrationWorkingToast = 'Vibration Working';
  static const String vibrationNotWorkingToast = 'Vibration Not Working';

  // Camera Test Screen
  static const String testingCamera = 'Testing Camera...';
  static const String cameraTestInstruction = 'We\'ll open both camera to check functionality. Ensure adequate lighting and point at a stable object.';
  static const String testingFrontCamera = 'Testing Front Camera...';
  static const String testingBackCamera = 'Testing back Camera...';
  static const String openCameraButton = 'Open Camera';

  // Microphone Test Screen
  static const String testingMicrophone = 'Testing Microphone...';
  static const String microphoneTestInstruction = 'Tap and hold you button below to start recording your voice for 5 seconds';
  static const String startRecordingButton = 'Start Recording';
  static const String timeLabel = 'Time:';
  static const String amplitudeLabel = 'Amplitude:';
  static const String timeSeconds = '5 Seconds';
  static const String timeFinish = 'Finish';
  static const String amplitudeZero = '0.0';

  // Headphones Test Screen
  static const String checkingHeadphones = 'Checking Headphones...';
  static const String headphonesTestInstruction = 'Please plug in your headphones to begin the audio and microphone test';
  static const String headphonesTestInstructionActive = 'Tap to test. Listen for music playback and speak into the microphone';
  static const String playMusicButton = 'Play Music';
  static const String recordMicButton = 'Record Mic';
  static const String headphonesNotConnectedTitle = 'Headphones Not Detected';
  static const String headphonesNotConnectedMessage = 'No headphones were detected. To test your headphones, please connect them first.\n\nWould you like to connect headphones now?';
  static const String noButton = 'No';

  // Fingerprint Test Screen
  static const String testingFingerprintScan = 'Testing Fingerprint Scan...';
  static const String fingerprintTestInstruction = 'Place your finger on the sensor above to test functionality.';
  static const String fingerprintNotDetected = 'Fingerprint Not Detected';
  static const String fingerprintNotDetectedMessage = 'Finger sensor not detected or fingerprint not added. Please go to settings and register/enroll your fingerprint to enable fingerprint detection.';
  static const String goToSettingsButton = 'Go To Settings';
  static const String goToSettingsTitle = 'Go To Settings';
  static const String goToSettingsMessage = 'Please go to Settings > Security > Fingerprint to enable and register your fingerprint.';
  static const String fingerprintDetectedSuccessfully = 'Fingerprint Detected Successfully!';

  // Facelock Test Screen
  static const String testingFacelock = 'Testing Facelock...';
  static const String facelockTestInstruction = 'Position your face in front of the camera. The front camera will be used to test face detection functionality.';
  static const String goToSettingButton = 'Go To Setting';
  static const String noFacelockButton = 'No Facelock';
  static const String faceLockDetected = 'Face Lock Detected!';
  static const String faceLockNotDetected = 'Face Lock Not Detected';
  static const String faceLockNotDetectedMessage = 'Front camera is not working or face detection failed. Please check your device camera settings.';

  // Magnet Sensor Test Screen
  static const String testingMagnetSensor = 'Testing Magnet Sensor...';
  static const String magnetSensorTestInstruction = 'Rotate your device slowly to calibrate the compass.';
  static const String magnetSensorNotDetected = 'Magnet Sensor Not Detected';
  static const String magnetSensorNotDetectedMessage = 'Magnet sensor not detected or not available. This device may not have a magnetometer sensor.';
  static const String magnetSensorWorking = 'Magnet Sensor Working';
  static const String magnetSensorWorkingMessage = 'Magnet sensor is working properly. Values are fluctuating correctly.';
  static const String magnetSensorNotWorking = 'Magnet Sensor Not Working';
  static const String magnetSensorNotWorkingMessage = 'Magnet sensor values are not fluctuating. The sensor may not be working correctly.';

  // Accelerometer Test Screen
  static const String testingAccelerometer = 'Testing Accelerometer';
  static const String accelerometerTestInstruction = 'Move your device in different directions to test the accelerometer sensor.';
  static const String accelerometerNotDetected = 'Accelerometer Not Detected';
  static const String accelerometerNotDetectedMessage = 'Accelerometer sensor not detected or not available. This device may not have an accelerometer sensor. Please check your device specifications.';
  static const String accelerometerWorking = 'Accelerometer Working';
  static const String accelerometerWorkingMessage = 'Accelerometer sensor is working properly. Values are fluctuating correctly.';
  static const String accelerometerNotWorking = 'Accelerometer Not Working';
  static const String accelerometerNotWorkingMessage = 'Accelerometer sensor values are not fluctuating as engine is diagnose expecting . The sensor may not be working correctly.';

  // Gyroscope Test Screen
  static const String testingGyroscopeSensor = 'Testing Gyroscope Sensor....';
  static const String gyroscopeTestInstruction = 'Rotate your device slowly in different directions to test the gyroscope sensor. The gyroscope measures rotation and angular velocity.';
  static const String gyroscopeNotDetected = 'Gyroscope Not Detected';
  static const String gyroscopeNotDetectedMessage = 'Gyroscope sensor not detected or not available. This device may not have a gyroscope sensor. Gyroscope is required for rotation detection and orientation features.';
  static const String gyroscopeWorking = 'Gyroscope Working';
  static const String gyroscopeWorkingMessage = 'Gyroscope sensor is functioning correctly. Rotation detection is working properly.';
  static const String gyroscopeNotWorking = 'Gyroscope Not Working';
  static const String gyroscopeNotWorkingMessage = 'Gyroscope sensor is not responding to rotation. The sensor may be malfunctioning or not calibrated correctly.';

  // Display Test Screen
  static const String testingDisplay = 'Testing Display...';
  static const String displayTestInstruction = 'The screen will display different colors. Check for discoloration, dead pixels, or any color issues on your display.';
  static const String displayTestComplete = 'Display Test Complete';
  static const String displayTestCompleteMessage = 'You have viewed all test colors. Please mark pass if the display looks good, or fail if you noticed any issues.';

  // Multi-Touch Test Screen
  static const String multiTouchScreenTest = 'Multi-Touch Screen Test...';
  static const String multiTouchTestInstruction = 'To test your screen\'s multi-touch capability, place two or more fingers on the screen simultaneously.';
  static const String multiTouchTestComplete = 'Multi-Touch Test Complete';
  static const String multiTouchTestCompleteMessage = 'You have tested multi-touch functionality. Please mark pass if the screen responded correctly to multiple touches, or fail if you noticed any issues.';

  // SAR Level Test Screen
  static const String checkingSarLevel = 'Checking SAR Level...';
  static const String sarLevelInstruction = 'Enter the USSD code to display your device\'s SAR information.';
  static const String ussdCode = 'USSD Code';
  static const String enterUssdCode = 'Enter above USSD code';
  static const String checkSarLevelButton = 'Check SAR Level';
  static const String sarLevelCheckedSuccess = 'SAR Level Checked';
  static const String sarLevelCheckedFailed = 'SAR Level Check Failed';
  static const String sarLevelCheckedToast = 'SAR level information displayed';

  // Asset paths
  static const String imageGroupPath = 'assets/images/Group.png';
  static const String image26Path = 'assets/images/image26.png';
  static const String scanningWifiPath = 'assets/images/scanning-wifi.png';
  static const String ellipse229Path = 'assets/images/Ellipse-229.png';
  static const String ellipse230Path = 'assets/images/Ellipse-230.png';
  static const String image20Path = 'assets/images/image-20.png';
  static const String image21Path = 'assets/images/image21.png';
  static const String image25Path = 'assets/images/image25.png';
  static const String image41Path = 'assets/images/image41.png';
  static const String image142Path = 'assets/images/image-142.png';
  static const String image44Path = 'assets/images/image44.png';
  static const String image48Path = 'assets/images/image48.png';
  static const String image51Path = 'assets/images/image51.png';
  static const String image53Path = 'assets/images/image53.png';
  static const String image54Path = 'assets/images/image54.png';
  static const String image78Path = 'assets/images/image78.png';
  static const String image79Path = 'assets/images/image79.png';
  static const String image84Path = 'assets/images/image84.png';
  static const String image86Path = 'assets/images/image86.png';
  static const String image94Path = 'assets/images/image94.png';
  static const String image118Path = 'assets/images/image118.png';
  static const String imageDisplayTestPath = 'assets/images/image143.png';
  static const String image134Path = 'assets/images/image134.png';
  static const String image80Path = 'assets/images/image80.png';
  static const String image144Path = 'assets/images/image144.png';
  static const String image136Path = 'assets/images/image136.png';
  static const String image87Path = 'assets/images/image87.png';
  static const String image104Path = 'assets/images/image104.png';
  static const String image97Path = 'assets/images/image97.png';
  static const String image103Path = 'assets/images/image103.png';
  static const String image128Path = 'assets/images/image128.png';
  static const String image129Path = 'assets/images/image129.png';
  static const String image113Path = 'assets/images/image113.png';
  static const String imageGyroscopePath = 'assets/images/image116.png';
  static const String image122Path = 'assets/images/image122.png';
  static const String nfcIconPath = 'assets/images/nfc-icon.png';
}

/// Centralized constants for numeric and configuration values
class AppConstants {
  AppConstants._();

  // Progress - Based on 30 total screens
  static const int totalScreens = 30;
  static const double diagnosisScreenProgress = 0.05; // 5% (Diagnosis screen)
  static const double sdCardScreenProgress = 0.07; // 7% (SD Card screen)
  static const double chargerTestScreenProgress = 0.20; // 20% (Charger Test screen)
  static const double batteryHealthScreenProgress = 0.20; // 20% (Battery Health screen)
  static const double touchScreenTestScreenProgress = 0.20; // 20% (Touch Screen Test screen)
  static const double proximitySensorScreenProgress = 0.20; // 20% (Proximity Sensor screen)
  static const double lightSensorScreenProgress = 0.20; // 20% (Light Sensor screen)
  static const double volumeButtonScreenProgress = 0.20; // 20% (Volume Button screen)
  static const double backButtonScreenProgress = 0.20; // 20% (Back Button screen)
  static const double powerButtonScreenProgress = 0.20; // 20% (Power Button screen)
  static const double homeButtonScreenProgress = 0.20; // 20% (Home Button screen)
  static const double menuButtonScreenProgress = 0.20; // 20% (Menu Button screen)
  static const double screenRotationScreenProgress = 0.20; // 20% (Screen Rotation screen)
  static const double screenBrightnessScreenProgress = 0.20; // 20% (Screen Brightness screen)
  static const double otgConnectivityScreenProgress = 0.20; // 20% (OTG Connectivity screen)
  static const double progressPerScreen = 1.0 / totalScreens; // ~3.33% per screen
  // Default values
  static const int defaultWifiNetworksCount = 12;
  static const int imeiLength = 15;
  static const int validationDelaySeconds = 1;
  // Diagnosis testing

  static const int diagnosisTestDurationSeconds = 3;
  static const double progressIncrementPerTest = 0.0167; // ~1.67% per test (5% / 3 tests)
}

