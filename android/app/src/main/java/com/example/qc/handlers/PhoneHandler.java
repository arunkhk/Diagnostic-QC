package com.example.qc.handlers;

import android.app.Activity;
import android.content.Intent;
import android.net.Uri;
import android.util.Log;
import io.flutter.plugin.common.MethodCall;
import io.flutter.plugin.common.MethodChannel;

public class PhoneHandler {
    
    private final Activity activity;
    
    public PhoneHandler(Activity activity) {
        this.activity = activity;
    }
    
    public void handleMethodCall(MethodCall call, MethodChannel.Result result) {
        Log.d("PhoneHandler", "Method called: " + call.method);
        if ("openDialer".equals(call.method)) {
            try {
                String phoneNumber = call.argument("phoneNumber");
                if (phoneNumber != null) {
                    openPhoneDialer(phoneNumber);
                    result.success(true);
                } else {
                    result.error("INVALID_ARGUMENT", "Phone number is required", null);
                }
            } catch (Exception e) {
                Log.e("PhoneHandler", "Error opening phone dialer: " + e.getMessage(), e);
                result.error("DIALER_ERROR", "Failed to open phone dialer: " + e.getMessage(), null);
            }
        } else {
            Log.w("PhoneHandler", "Unknown method: " + call.method);
            result.notImplemented();
        }
    }

    private void openPhoneDialer(String phoneNumber) {
        try {
            Intent intent = new Intent(Intent.ACTION_DIAL);
            intent.setData(Uri.parse("tel:" + phoneNumber));
            intent.setFlags(Intent.FLAG_ACTIVITY_NEW_TASK);
            activity.startActivity(intent);
        } catch (Exception e) {
            Log.e("PhoneHandler", "Error opening dialer: " + e.getMessage(), e);
            throw e;
        }
    }
}

