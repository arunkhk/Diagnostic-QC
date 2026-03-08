package com.example.qc.handlers;

import android.app.Activity;
import android.content.Context;
import android.content.Intent;
import android.net.wifi.ScanResult;
import android.net.wifi.WifiManager;
import android.provider.Settings;
import android.util.Log;
import io.flutter.plugin.common.MethodCall;
import io.flutter.plugin.common.MethodChannel;
import java.util.List;

public class WifiHandler {
    
    private final Activity activity;
    
    public WifiHandler(Activity activity) {
        this.activity = activity;
    }
    
    public void handleMethodCall(MethodCall call, MethodChannel.Result result) {
        Log.d("WifiHandler", "Method called: " + call.method);
        if ("isWifiEnabled".equals(call.method)) {
            try {
                boolean isEnabled = isWifiEnabled();
                Log.d("WifiHandler", "WiFi enabled: " + isEnabled);
                result.success(isEnabled);
            } catch (Exception e) {
                Log.e("WifiHandler", "Error checking WiFi: " + e.getMessage(), e);
                result.error("WIFI_ERROR", "Failed to check WiFi state: " + e.getMessage(), null);
            }
        } else if ("openWifiSettings".equals(call.method)) {
            try {
                openWifiSettings();
                result.success(null);
            } catch (Exception e) {
                Log.e("WifiHandler", "Error opening WiFi settings: " + e.getMessage(), e);
                result.error("WIFI_SETTINGS_ERROR", "Failed to open WiFi settings: " + e.getMessage(), null);
            }
        } else if ("getWifiNetworksCount".equals(call.method)) {
            try {
                int count = getWifiNetworksCount();
                Log.d("WifiHandler", "WiFi networks found: " + count);
                result.success(count);
            } catch (Exception e) {
                Log.e("WifiHandler", "Error getting WiFi networks count: " + e.getMessage(), e);
                result.error("WIFI_SCAN_ERROR", "Failed to scan WiFi networks: " + e.getMessage(), null);
            }
        } else {
            Log.w("WifiHandler", "Unknown method: " + call.method);
            result.notImplemented();
        }
    }

    private boolean isWifiEnabled() {
        try {
            WifiManager wifiManager = (WifiManager) activity.getApplicationContext().getSystemService(Context.WIFI_SERVICE);
            return wifiManager != null && wifiManager.isWifiEnabled();
        } catch (Exception e) {
            return false;
        }
    }

    private void openWifiSettings() {
        try {
            Intent intent = new Intent(Settings.ACTION_WIFI_SETTINGS);
            intent.setFlags(Intent.FLAG_ACTIVITY_NEW_TASK);
            activity.startActivity(intent);
        } catch (Exception e) {
            // Fallback to general settings
            Intent intent = new Intent(Settings.ACTION_SETTINGS);
            intent.setFlags(Intent.FLAG_ACTIVITY_NEW_TASK);
            activity.startActivity(intent);
        }
    }

    private int getWifiNetworksCount() {
        try {
            WifiManager wifiManager = (WifiManager) activity.getApplicationContext().getSystemService(Context.WIFI_SERVICE);
            if (wifiManager == null || !wifiManager.isWifiEnabled()) {
                return 0;
            }
            
            // Start WiFi scan
            boolean scanStarted = wifiManager.startScan();
            if (!scanStarted) {
                Log.w("WifiHandler", "WiFi scan could not be started");
                // Try to get existing scan results
            }
            
            // Get scan results (may be from previous scan)
            List<ScanResult> scanResults = wifiManager.getScanResults();
            if (scanResults != null) {
                // Filter out duplicate SSIDs (same network may appear multiple times)
                java.util.Set<String> uniqueNetworks = new java.util.HashSet<>();
                for (ScanResult result : scanResults) {
                    if (result.SSID != null && !result.SSID.isEmpty()) {
                        uniqueNetworks.add(result.SSID);
                    }
                }
                return uniqueNetworks.size();
            }
            return 0;
        } catch (Exception e) {
            Log.e("WifiHandler", "Error scanning WiFi networks: " + e.getMessage(), e);
            return 0;
        }
    }
}

