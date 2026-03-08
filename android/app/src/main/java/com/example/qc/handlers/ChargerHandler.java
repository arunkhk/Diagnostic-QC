package com.example.qc.handlers;

import android.app.Activity;
import android.content.BroadcastReceiver;
import android.content.Context;
import android.content.Intent;
import android.content.IntentFilter;
import android.os.BatteryManager;
import android.util.Log;
import io.flutter.plugin.common.EventChannel;
import io.flutter.plugin.common.MethodCall;
import io.flutter.plugin.common.MethodChannel;

public class ChargerHandler {
    
    private final Activity activity;
    private EventChannel.EventSink chargerEventSink;
    private BroadcastReceiver batteryReceiver;
    
    public ChargerHandler(Activity activity) {
        this.activity = activity;
    }
    
    public void handleMethodCall(MethodCall call, MethodChannel.Result result) {
        Log.d("ChargerHandler", "Method called: " + call.method);
        if ("isChargerConnected".equals(call.method)) {
            try {
                boolean isConnected = isChargerConnected();
                Log.d("ChargerHandler", "Charger connected: " + isConnected);
                result.success(isConnected);
            } catch (Exception e) {
                Log.e("ChargerHandler", "Error checking charger: " + e.getMessage(), e);
                result.error("CHARGER_ERROR", "Failed to check charger state: " + e.getMessage(), null);
            }
        } else {
            Log.w("ChargerHandler", "Unknown method: " + call.method);
            result.notImplemented();
        }
    }
    
    public void setEventSink(EventChannel.EventSink sink) {
        chargerEventSink = sink;
        if (sink != null) {
            registerBatteryReceiver();
            // Check initial charger state immediately (for already connected chargers)
            checkInitialChargerState();
        } else {
            unregisterBatteryReceiver();
        }
    }
    
    private void checkInitialChargerState() {
        try {
            boolean isConnected = isChargerConnected();
            Log.d("ChargerHandler", "Initial charger state check: " + isConnected);
            // Send initial state to Flutter
            if (chargerEventSink != null) {
                chargerEventSink.success(isConnected ? "connected" : "disconnected");
            }
        } catch (Exception e) {
            Log.e("ChargerHandler", "Error checking initial charger state: " + e.getMessage(), e);
        }
    }
    
    private boolean isChargerConnected() {
        try {
            Intent intent = activity.registerReceiver(null, new IntentFilter(Intent.ACTION_BATTERY_CHANGED));
            int plugged = intent != null ? intent.getIntExtra(BatteryManager.EXTRA_PLUGGED, -1) : -1;
            boolean isConnected = plugged == BatteryManager.BATTERY_PLUGGED_AC ||
                    plugged == BatteryManager.BATTERY_PLUGGED_USB ||
                    plugged == BatteryManager.BATTERY_PLUGGED_WIRELESS;
            Log.d("ChargerHandler", "Charger plugged status: " + plugged + ", connected: " + isConnected);
            return isConnected;
        } catch (Exception e) {
            Log.e("ChargerHandler", "Error checking charger connection: " + e.getMessage(), e);
            return false;
        }
    }
    
    private void registerBatteryReceiver() {
        if (batteryReceiver == null) {
            batteryReceiver = new BroadcastReceiver() {
                @Override
                public void onReceive(Context context, Intent intent) {
                    if (Intent.ACTION_BATTERY_CHANGED.equals(intent.getAction())) {
                        int plugged = intent.getIntExtra(BatteryManager.EXTRA_PLUGGED, -1);
                        boolean isConnected = plugged == BatteryManager.BATTERY_PLUGGED_AC ||
                                plugged == BatteryManager.BATTERY_PLUGGED_USB ||
                                plugged == BatteryManager.BATTERY_PLUGGED_WIRELESS;
                        
                        Log.d("ChargerHandler", "Battery changed - plugged: " + plugged + ", connected: " + isConnected);
                        if (chargerEventSink != null) {
                            chargerEventSink.success(isConnected ? "connected" : "disconnected");
                        }
                    }
                }
            };
            
            IntentFilter filter = new IntentFilter();
            filter.addAction(Intent.ACTION_BATTERY_CHANGED);
            
            try {
                activity.registerReceiver(batteryReceiver, filter);
                Log.d("ChargerHandler", "Battery receiver registered");
            } catch (Exception e) {
                Log.e("ChargerHandler", "Error registering battery receiver: " + e.getMessage(), e);
            }
        }
    }
    
    public void unregisterBatteryReceiver() {
        if (batteryReceiver != null) {
            try {
                activity.unregisterReceiver(batteryReceiver);
                Log.d("ChargerHandler", "Battery receiver unregistered");
            } catch (Exception e) {
                Log.e("ChargerHandler", "Error unregistering battery receiver: " + e.getMessage(), e);
            }
            batteryReceiver = null;
        }
    }
}

