package com.example.qc.handlers;

import android.app.Activity;
import android.content.Intent;
import android.provider.Settings;
import android.util.Log;
import io.flutter.plugin.common.MethodCall;
import io.flutter.plugin.common.MethodChannel;

public class SettingsHandler {
    
    private final Activity activity;
    
    public SettingsHandler(Activity activity) {
        this.activity = activity;
    }
    
    public void handleMethodCall(MethodCall call, MethodChannel.Result result) {
        Log.d("SettingsHandler", "Method called: " + call.method);
        if ("openFingerprintSettings".equals(call.method)) {
            try {
                openFingerprintSettings();
                result.success(true);
            } catch (Exception e) {
                Log.e("SettingsHandler", "Error opening fingerprint settings: " + e.getMessage(), e);
                result.error("SETTINGS_ERROR", "Failed to open fingerprint settings: " + e.getMessage(), null);
            }
        } else if ("openSecuritySettings".equals(call.method)) {
            try {
                openSecuritySettings();
                result.success(true);
            } catch (Exception e) {
                Log.e("SettingsHandler", "Error opening security settings: " + e.getMessage(), e);
                result.error("SETTINGS_ERROR", "Failed to open security settings: " + e.getMessage(), null);
            }
        } else {
            Log.w("SettingsHandler", "Unknown method: " + call.method);
            result.notImplemented();
        }
    }

    private void openFingerprintSettings() {
        try {
            // Try to open fingerprint settings directly
            Intent intent = new Intent(Settings.ACTION_SECURITY_SETTINGS);
            intent.setFlags(Intent.FLAG_ACTIVITY_NEW_TASK);
            activity.startActivity(intent);
        } catch (Exception e) {
            // Fallback to general settings
            Log.e("SettingsHandler", "Error opening fingerprint settings: " + e.getMessage(), e);
            openSecuritySettings();
        }
    }

    private void openSecuritySettings() {
        try {
            Intent intent = new Intent(Settings.ACTION_SECURITY_SETTINGS);
            intent.setFlags(Intent.FLAG_ACTIVITY_NEW_TASK);
            activity.startActivity(intent);
        } catch (Exception e) {
            // Final fallback to general settings
            Log.e("SettingsHandler", "Error opening security settings: " + e.getMessage(), e);
            Intent intent = new Intent(Settings.ACTION_SETTINGS);
            intent.setFlags(Intent.FLAG_ACTIVITY_NEW_TASK);
            activity.startActivity(intent);
        }
    }
}

