package com.example.qc.handlers;

import android.app.Activity;
import android.bluetooth.BluetoothAdapter;
import android.content.Intent;
import android.os.Build;
import android.provider.Settings;
import android.util.Log;
import io.flutter.plugin.common.MethodCall;
import io.flutter.plugin.common.MethodChannel;

public class BluetoothHandler {
    
    private final Activity activity;
    
    public BluetoothHandler(Activity activity) {
        this.activity = activity;
    }
    
    public void handleMethodCall(MethodCall call, MethodChannel.Result result) {
        Log.d("BluetoothHandler", "Method called: " + call.method);
        if ("isBluetoothEnabled".equals(call.method)) {
            try {
                boolean isEnabled = isBluetoothEnabled();
                Log.d("BluetoothHandler", "Bluetooth enabled: " + isEnabled);
                result.success(isEnabled);
            } catch (Exception e) {
                Log.e("BluetoothHandler", "Error checking Bluetooth: " + e.getMessage(), e);
                result.error("BLUETOOTH_ERROR", "Failed to check Bluetooth state: " + e.getMessage(), null);
            }
        } else if ("openBluetoothSettings".equals(call.method)) {
            try {
                openBluetoothSettings();
                result.success(null);
            } catch (Exception e) {
                Log.e("BluetoothHandler", "Error opening Bluetooth settings: " + e.getMessage(), e);
                result.error("BLUETOOTH_SETTINGS_ERROR", "Failed to open Bluetooth settings: " + e.getMessage(), null);
            }
        } else {
            Log.w("BluetoothHandler", "Unknown method: " + call.method);
            result.notImplemented();
        }
    }

    private boolean isBluetoothEnabled() {
        try {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
                // Android 12+ uses BluetoothManager
                android.bluetooth.BluetoothManager bluetoothManager = activity.getSystemService(android.bluetooth.BluetoothManager.class);
                return bluetoothManager != null && bluetoothManager.getAdapter() != null && bluetoothManager.getAdapter().isEnabled();
            } else {
                // Older Android versions
                BluetoothAdapter bluetoothAdapter = BluetoothAdapter.getDefaultAdapter();
                return bluetoothAdapter != null && bluetoothAdapter.isEnabled();
            }
        } catch (Exception e) {
            return false;
        }
    }

    private void openBluetoothSettings() {
        try {
            Intent intent = new Intent(Settings.ACTION_BLUETOOTH_SETTINGS);
            intent.setFlags(Intent.FLAG_ACTIVITY_NEW_TASK);
            activity.startActivity(intent);
        } catch (Exception e) {
            // Fallback to general settings
            Intent intent = new Intent(Settings.ACTION_SETTINGS);
            intent.setFlags(Intent.FLAG_ACTIVITY_NEW_TASK);
            activity.startActivity(intent);
        }
    }
}

