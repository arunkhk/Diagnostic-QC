package com.example.qc.handlers;

import android.app.Activity;
import android.content.ContentResolver;
import android.content.Intent;
import android.os.Build;
import android.provider.Settings;
import android.util.Log;
import android.view.Window;
import io.flutter.plugin.common.MethodCall;
import io.flutter.plugin.common.MethodChannel;

public class BrightnessHandler {
    
    private final Activity activity;
    
    public BrightnessHandler(Activity activity) {
        this.activity = activity;
    }
    
    public void handleMethodCall(MethodCall call, MethodChannel.Result result) {
        Log.d("BrightnessHandler", "Method called: " + call.method);
        if ("setScreenBrightness".equals(call.method)) {
            try {
                Double brightness = call.argument("brightness");
                double brightnessValue = brightness != null ? brightness : 1.0;
                boolean success = setScreenBrightness(brightnessValue);
                result.success(success);
            } catch (Exception e) {
                Log.e("BrightnessHandler", "Error setting screen brightness: " + e.getMessage(), e);
                result.error("BRIGHTNESS_ERROR", "Failed to set screen brightness: " + e.getMessage(), null);
            }
        } else if ("getScreenBrightness".equals(call.method)) {
            try {
                double brightness = getScreenBrightness();
                result.success(brightness);
            } catch (Exception e) {
                Log.e("BrightnessHandler", "Error getting screen brightness: " + e.getMessage(), e);
                result.error("BRIGHTNESS_ERROR", "Failed to get screen brightness: " + e.getMessage(), null);
            }
        } else if ("canWriteSettings".equals(call.method)) {
            try {
                boolean canWrite = canWriteSettings();
                result.success(canWrite);
            } catch (Exception e) {
                Log.e("BrightnessHandler", "Error checking WRITE_SETTINGS permission: " + e.getMessage(), e);
                result.error("PERMISSION_ERROR", "Failed to check permission: " + e.getMessage(), null);
            }
        } else if ("openWriteSettings".equals(call.method)) {
            try {
                openWriteSettings();
                result.success(true);
            } catch (Exception e) {
                Log.e("BrightnessHandler", "Error opening WRITE_SETTINGS screen: " + e.getMessage(), e);
                result.error("PERMISSION_ERROR", "Failed to open settings: " + e.getMessage(), null);
            }
        } else {
            Log.w("BrightnessHandler", "Unknown method: " + call.method);
            result.notImplemented();
        }
    }

    private boolean setScreenBrightness(double brightness) {
        try {
            activity.runOnUiThread(new Runnable() {
                @Override
                public void run() {
                    float brightnessValue = (float) Math.max(0.0, Math.min(1.0, brightness));
                    int brightnessInt = Math.max(0, Math.min(255, (int)(brightnessValue * 255)));
                    
                    // Get content resolver and current window
                    ContentResolver cResolver = activity.getContentResolver();
                    Window window = activity.getWindow();
                    
                    try {
                        // Set brightness mode to manual (disable auto-brightness)
                        Settings.System.putInt(
                            cResolver,
                            Settings.System.SCREEN_BRIGHTNESS_MODE,
                            Settings.System.SCREEN_BRIGHTNESS_MODE_MANUAL
                        );
                        
                        // Set the system brightness
                        Settings.System.putInt(
                            cResolver,
                            Settings.System.SCREEN_BRIGHTNESS,
                            brightnessInt
                        );
                        
                        // Also set window brightness for immediate effect
                        android.view.WindowManager.LayoutParams layoutParams = window.getAttributes();
                        layoutParams.screenBrightness = brightnessValue;
                        window.setAttributes(layoutParams);
                        
                        Log.d("BrightnessHandler", "Screen brightness set to: " + brightnessValue + " (" + brightnessInt + "/255 = " + (int)(brightnessValue * 100) + "%)");
                    } catch (SecurityException e) {
                        // WRITE_SETTINGS permission not granted - fallback to window brightness only
                        Log.w("BrightnessHandler", "WRITE_SETTINGS permission not granted, using window brightness only");
                        android.view.WindowManager.LayoutParams layoutParams = window.getAttributes();
                        layoutParams.screenBrightness = brightnessValue;
                        window.setAttributes(layoutParams);
                    }
                }
            });
            return true;
        } catch (Exception e) {
            Log.e("BrightnessHandler", "Error setting screen brightness: " + e.getMessage(), e);
            e.printStackTrace();
            return false;
        }
    }
    
    private double getScreenBrightness() {
        try {
            ContentResolver cResolver = activity.getContentResolver();
            int brightness = Settings.System.getInt(
                cResolver,
                Settings.System.SCREEN_BRIGHTNESS
            );
            // Convert from 0-255 range to 0.0-1.0 range
            return Math.max(0.0, Math.min(1.0, brightness / 255.0));
        } catch (Settings.SettingNotFoundException e) {
            Log.e("BrightnessHandler", "Cannot access system brightness: " + e.getMessage(), e);
            return 1.0;
        } catch (Exception e) {
            Log.e("BrightnessHandler", "Error getting screen brightness: " + e.getMessage(), e);
            return 1.0;
        }
    }
    
    private boolean canWriteSettings() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            return Settings.System.canWrite(activity);
        } else {
            // For older Android versions, permission is granted at install time
            return true;
        }
    }
    
    private void openWriteSettings() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            String packageName = activity.getPackageName();
            Log.d("BrightnessHandler", "Opening WRITE_SETTINGS for package: " + packageName);
            
            Intent intent = new Intent(Settings.ACTION_MANAGE_WRITE_SETTINGS);
            intent.setData(android.net.Uri.parse("package:" + packageName));
            intent.setFlags(Intent.FLAG_ACTIVITY_NEW_TASK);
            
            try {
                // Check if the intent can be resolved
                if (intent.resolveActivity(activity.getPackageManager()) != null) {
                    activity.startActivity(intent);
                    Log.d("BrightnessHandler", "Opened WRITE_SETTINGS screen successfully");
                } else {
                    // If specific intent can't be resolved, try opening app info page
                    Log.w("BrightnessHandler", "WRITE_SETTINGS intent not resolvable, opening app info");
                    Intent appInfoIntent = new Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS);
                    appInfoIntent.setData(android.net.Uri.parse("package:" + packageName));
                    appInfoIntent.setFlags(Intent.FLAG_ACTIVITY_NEW_TASK);
                    activity.startActivity(appInfoIntent);
                }
            } catch (android.content.ActivityNotFoundException e) {
                Log.e("BrightnessHandler", "Activity not found, trying app info: " + e.getMessage(), e);
                // Fallback to app info page where user can manually enable the permission
                try {
                    Intent appInfoIntent = new Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS);
                    appInfoIntent.setData(android.net.Uri.parse("package:" + packageName));
                    appInfoIntent.setFlags(Intent.FLAG_ACTIVITY_NEW_TASK);
                    activity.startActivity(appInfoIntent);
                } catch (Exception e2) {
                    Log.e("BrightnessHandler", "Error opening app info: " + e2.getMessage(), e2);
                    // Last resort: open general settings
                    Intent fallbackIntent = new Intent(Settings.ACTION_SETTINGS);
                    fallbackIntent.setFlags(Intent.FLAG_ACTIVITY_NEW_TASK);
                    activity.startActivity(fallbackIntent);
                }
            } catch (Exception e) {
                Log.e("BrightnessHandler", "Error opening WRITE_SETTINGS screen: " + e.getMessage(), e);
                // Fallback to app info page
                try {
                    Intent appInfoIntent = new Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS);
                    appInfoIntent.setData(android.net.Uri.parse("package:" + packageName));
                    appInfoIntent.setFlags(Intent.FLAG_ACTIVITY_NEW_TASK);
                    activity.startActivity(appInfoIntent);
                } catch (Exception e2) {
                    Log.e("BrightnessHandler", "Error opening app info: " + e2.getMessage(), e2);
                }
            }
        }
    }
}

