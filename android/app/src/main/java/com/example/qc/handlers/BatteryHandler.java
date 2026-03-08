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
import java.util.HashMap;
import java.util.Map;

public class BatteryHandler {
    
    private final Activity activity;
    private EventChannel.EventSink batteryEventSink;
    private BroadcastReceiver batteryReceiver;
    
    public BatteryHandler(Activity activity) {
        this.activity = activity;
    }
    
    public void handleMethodCall(MethodCall call, MethodChannel.Result result) {
        Log.d("BatteryHandler", "Method called: " + call.method);
        if ("getBatteryInfo".equals(call.method)) {
            try {
                Map<String, Object> batteryInfo = getBatteryInfo();
                Log.d("BatteryHandler", "Battery info retrieved: health=" + batteryInfo.get("health") + ", level=" + batteryInfo.get("level"));
                result.success(batteryInfo);
            } catch (Exception e) {
                Log.e("BatteryHandler", "Error getting battery info: " + e.getMessage(), e);
                result.error("BATTERY_ERROR", "Failed to get battery info: " + e.getMessage(), null);
            }
        } else {
            Log.w("BatteryHandler", "Unknown method: " + call.method);
            result.notImplemented();
        }
    }
    
    public void setEventSink(EventChannel.EventSink sink) {
        batteryEventSink = sink;
        if (sink != null) {
            registerBatteryReceiver();
        } else {
            unregisterBatteryReceiver();
        }
    }
    
    private Map<String, Object> getBatteryInfo() {
        try {
            Intent intent = activity.registerReceiver(null, new IntentFilter(Intent.ACTION_BATTERY_CHANGED));
            if (intent != null) {
                return getBatteryInfoFromIntent(intent);
            } else {
                Log.e("BatteryHandler", "Battery intent is null");
                return new HashMap<>();
            }
        } catch (Exception e) {
            Log.e("BatteryHandler", "Error getting battery info: " + e.getMessage(), e);
            return new HashMap<>();
        }
    }
    
    private void registerBatteryReceiver() {
        if (batteryReceiver == null) {
            batteryReceiver = new BroadcastReceiver() {
                @Override
                public void onReceive(Context context, Intent intent) {
                    if (Intent.ACTION_BATTERY_CHANGED.equals(intent.getAction())) {
                        Map<String, Object> batteryInfo = getBatteryInfoFromIntent(intent);
                        Log.d("BatteryHandler", "Battery changed - health: " + batteryInfo.get("health") + ", level: " + batteryInfo.get("level"));
                        if (batteryEventSink != null) {
                            batteryEventSink.success(batteryInfo);
                        }
                    }
                }
            };
            
            IntentFilter filter = new IntentFilter();
            filter.addAction(Intent.ACTION_BATTERY_CHANGED);
            
            try {
                activity.registerReceiver(batteryReceiver, filter);
                Log.d("BatteryHandler", "Battery receiver registered");
            } catch (Exception e) {
                Log.e("BatteryHandler", "Error registering battery receiver: " + e.getMessage(), e);
            }
        }
    }
    
    private Map<String, Object> getBatteryInfoFromIntent(Intent intent) {
        int health = intent.getIntExtra(BatteryManager.EXTRA_HEALTH, BatteryManager.BATTERY_HEALTH_UNKNOWN);
        int level = intent.getIntExtra(BatteryManager.EXTRA_LEVEL, -1);
        int scale = intent.getIntExtra(BatteryManager.EXTRA_SCALE, -1);
        int status = intent.getIntExtra(BatteryManager.EXTRA_STATUS, BatteryManager.BATTERY_STATUS_UNKNOWN);
        String technology = intent.getStringExtra(BatteryManager.EXTRA_TECHNOLOGY);
        if (technology == null) technology = "Unknown";
        int temperature = intent.getIntExtra(BatteryManager.EXTRA_TEMPERATURE, -1);
        int voltage = intent.getIntExtra(BatteryManager.EXTRA_VOLTAGE, -1);
        
        String healthString;
        switch (health) {
            case BatteryManager.BATTERY_HEALTH_GOOD:
                healthString = "Good";
                break;
            case BatteryManager.BATTERY_HEALTH_OVERHEAT:
                healthString = "Overheat";
                break;
            case BatteryManager.BATTERY_HEALTH_DEAD:
                healthString = "Dead";
                break;
            case BatteryManager.BATTERY_HEALTH_OVER_VOLTAGE:
                healthString = "Over Voltage";
                break;
            case BatteryManager.BATTERY_HEALTH_UNSPECIFIED_FAILURE:
                healthString = "Unspecified Failure";
                break;
            case BatteryManager.BATTERY_HEALTH_COLD:
                healthString = "Cold";
                break;
            default:
                healthString = "Unknown";
        }
        
        String statusString;
        switch (status) {
            case BatteryManager.BATTERY_STATUS_CHARGING:
                statusString = "Charging";
                break;
            case BatteryManager.BATTERY_STATUS_DISCHARGING:
                statusString = "Discharging";
                break;
            case BatteryManager.BATTERY_STATUS_NOT_CHARGING:
                statusString = "Not Charging";
                break;
            case BatteryManager.BATTERY_STATUS_FULL:
                statusString = "Full";
                break;
            default:
                statusString = "Unknown";
        }
        
        double tempCelsius = temperature != -1 ? temperature / 10.0 : 0.0;
        
        Map<String, Object> batteryInfo = new HashMap<>();
        batteryInfo.put("health", healthString);
        batteryInfo.put("healthCode", health);
        batteryInfo.put("level", level);
        batteryInfo.put("scale", scale);
        batteryInfo.put("status", statusString);
        batteryInfo.put("statusCode", status);
        batteryInfo.put("technology", technology);
        batteryInfo.put("temperature", tempCelsius);
        batteryInfo.put("voltage", voltage);
        return batteryInfo;
    }
    
    public void unregisterBatteryReceiver() {
        if (batteryReceiver != null) {
            try {
                activity.unregisterReceiver(batteryReceiver);
                Log.d("BatteryHandler", "Battery receiver unregistered");
            } catch (Exception e) {
                Log.e("BatteryHandler", "Error unregistering battery receiver: " + e.getMessage(), e);
            }
            batteryReceiver = null;
        }
    }
}

