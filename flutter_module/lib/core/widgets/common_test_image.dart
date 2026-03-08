import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../constants/app_colors.dart';
import '../../features/diagnosis/providers/test_images_provider.dart';

/// A reusable widget for displaying test images with network URL and local fallback
/// 
/// Features:
/// - Loads image from API (GetTestImages) based on screen name
/// - Shows pass/fail icon based on test status
/// - Falls back to local asset if network fails
/// - Falls back to icon if local asset also fails
/// - Uses CachedNetworkImage for caching
/// 
/// Example usage:
/// ```dart
/// CommonTestImage(
///   screenName: TestConfig.testIdTouch,
///   isPassed: true,
///   localFallbackPath: AppStrings.image142Path,
///   fallbackIcon: Icons.touch_app,
///   width: 120,
///   height: 120,
/// )
/// ```
class CommonTestImage extends ConsumerWidget {
  /// Screen name to lookup in testImagesProvider (e.g., "touch", "wifi", "bluetooth")
  final String screenName;
  
  /// Whether the test passed (true = passIcon, false = failIcon)
  final bool isPassed;
  
  /// Local asset path to use as fallback when network fails
  final String localFallbackPath;
  
  /// Icon to show when both network and local asset fail
  final IconData fallbackIcon;
  
  /// Image width (default: 120)
  final double width;
  
  /// Image height (default: 120)
  final double height;
  
  /// BoxFit for the image (default: BoxFit.contain)
  final BoxFit fit;

  const CommonTestImage({
    super.key,
    required this.screenName,
    required this.isPassed,
    required this.localFallbackPath,
    this.fallbackIcon = Icons.image,
    this.width = 120,
    this.height = 120,
    this.fit = BoxFit.contain,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final testImagesNotifier = ref.read(testImagesProvider.notifier);
    final imageUrl = testImagesNotifier.getIconUrl(screenName, isPassed: isPassed);
    
    // Debug logging
    debugPrint('═══════════════════════════════════════════════════════════');
    debugPrint('🖼️ CommonTestImage: Loading image for screen "$screenName"');
    debugPrint('   isPassed: $isPassed');
    debugPrint('   URL: ${imageUrl ?? "null (using local fallback)"}');
    debugPrint('   Local fallback: $localFallbackPath');
    debugPrint('═══════════════════════════════════════════════════════════');
    
    // If we have a valid HTTP/HTTPS URL, use CachedNetworkImage with fallback
    if (imageUrl != null && imageUrl.isNotEmpty &&
        (imageUrl.startsWith('http://') || imageUrl.startsWith('https://'))) {
      return CachedNetworkImage(
        imageUrl: imageUrl,
        width: width,
        height: height,
        fit: fit,
        placeholder: (context, url) {
          debugPrint('🖼️ CommonTestImage: Loading from URL: $url');
          return _buildLocalAsset();
        },
        errorWidget: (context, url, error) {
          debugPrint('❌ CommonTestImage: Failed to load from URL: $url');
          debugPrint('   Error: $error');
          debugPrint('   Using local fallback: $localFallbackPath');
          return _buildLocalAsset();
        },
      );
    }
    
    // Fallback to local asset if no valid URL
    debugPrint('🖼️ CommonTestImage: No valid URL, using local asset: $localFallbackPath');
    return _buildLocalAsset();
  }
  
  /// Build local asset image with fallback to icon
  Widget _buildLocalAsset() {
    return Image.asset(
      localFallbackPath,
      width: width,
      height: height,
      fit: fit,
      errorBuilder: (_, __, ___) => _buildFallbackIcon(),
    );
  }

  /// Build fallback icon when all images fail
  Widget _buildFallbackIcon() {
    return SizedBox(
      width: width,
      height: height,
      child: Icon(
        fallbackIcon,
        size: width * 0.5, // Icon size is 50% of image size
        color: AppColors.textSecondary,
      ),
    );
  }
}
