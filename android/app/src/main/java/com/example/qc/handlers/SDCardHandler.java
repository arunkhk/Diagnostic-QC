package com.example.qc.handlers;

import android.app.Activity;
import android.os.Environment;
import android.util.Log;
import androidx.core.content.ContextCompat;
import io.flutter.plugin.common.MethodCall;
import io.flutter.plugin.common.MethodChannel;
import java.io.File;
import java.util.HashMap;
import java.util.Map;

public class SDCardHandler {
    
    private final Activity activity;
    
    public SDCardHandler(Activity activity) {
        this.activity = activity;
    }
    
    public void handleMethodCall(MethodCall call, MethodChannel.Result result) {
        Log.d("SDCardHandler", "Method called: " + call.method);
        if ("checkSDCard".equals(call.method)) {
            try {
                Map<String, Object> sdCardInfo = checkSDCard();
                Log.d("SDCardHandler", "SD Card check result: isSupported=" + sdCardInfo.get("isSupported") + ", isPresent=" + sdCardInfo.get("isPresent") + ", isAvailable=" + sdCardInfo.get("isAvailable"));
                result.success(sdCardInfo);
            } catch (Exception e) {
                Log.e("SDCardHandler", "Error checking SD card: " + e.getMessage(), e);
                result.error("SD_CARD_ERROR", "Failed to check SD card: " + e.getMessage(), null);
            }
        } else {
            Log.w("SDCardHandler", "Unknown method: " + call.method);
            result.notImplemented();
        }
    }
    
    private Map<String, Object> checkSDCard() {
        boolean isSDSupportedDevice = Environment.isExternalStorageRemovable();
        boolean isSDPresent = Environment.MEDIA_MOUNTED.equals(Environment.getExternalStorageState());
        boolean isAvailable = externalMemoryAvailable();
        
        Log.d("SDCardHandler", "SD Card Detection:");
        Log.d("SDCardHandler", "  isSDSupportedDevice: " + isSDSupportedDevice);
        Log.d("SDCardHandler", "  isSDPresent: " + isSDPresent);
        Log.d("SDCardHandler", "  externalMemoryAvailable: " + isAvailable);
        
        Map<String, Object> result = new HashMap<>();
        result.put("isSupported", isSDSupportedDevice);
        result.put("isPresent", isSDPresent);
        result.put("isAvailable", isAvailable);
        return result;
    }
    
    private boolean externalMemoryAvailable() {
        try {
            File[] storages = ContextCompat.getExternalFilesDirs(activity, null);
            boolean result = storages.length > 1 && storages[0] != null && storages[1] != null;
            Log.d("SDCardHandler", "External memory check: " + storages.length + " storage(s) found, available: " + result);
            return result;
        } catch (Exception e) {
            Log.e("SDCardHandler", "Error checking external memory: " + e.getMessage(), e);
            return false;
        }
    }
}

