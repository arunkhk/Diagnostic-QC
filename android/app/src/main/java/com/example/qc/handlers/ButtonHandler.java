package com.example.qc.handlers;

import android.app.Activity;
import android.content.BroadcastReceiver;
import android.content.Context;
import android.content.Intent;
import android.content.IntentFilter;
import android.os.Build;
import android.os.Handler;
import android.os.Looper;
import android.util.Log;
import android.view.KeyEvent;
import io.flutter.plugin.common.EventChannel;

public class ButtonHandler {
    
    private final Activity activity;
    private EventChannel.EventSink buttonEventSink;
    private BroadcastReceiver screenReceiver;
    
    public ButtonHandler(Activity activity) {
        this.activity = activity;
    }
    
    public void setEventSink(EventChannel.EventSink sink) {
        buttonEventSink = sink;
        if (sink != null) {
            registerScreenReceiver();
        } else {
            unregisterScreenReceiver();
        }
    }
    
    public void onUserLeaveHint() {
        // Detect Home button press (app goes to background)
        Log.d("ButtonHandler", "Home button pressed - app going to background");
        if (buttonEventSink != null) {
            buttonEventSink.success("home");
        }
    }
    
    public boolean onKeyDown(int keyCode, KeyEvent event) {
        // Detect Menu button press (deprecated in Android 3.0+, but still works on some devices)
        if (keyCode == KeyEvent.KEYCODE_MENU) {
            Log.d("ButtonHandler", "Menu button pressed");
            if (buttonEventSink != null) {
                buttonEventSink.success("menu");
            }
            return true;
        }
        return false;
    }
    
    public boolean hasMenuButton() {
        // Menu button was deprecated in Android 3.0 (API 11)
        // Modern devices use on-screen navigation buttons
        return Build.VERSION.SDK_INT < Build.VERSION_CODES.HONEYCOMB;
    }
    
    private void registerScreenReceiver() {
        if (screenReceiver == null) {
            screenReceiver = new BroadcastReceiver() {
                @Override
                public void onReceive(Context context, Intent intent) {
                    if (Intent.ACTION_SCREEN_ON.equals(intent.getAction())) {
                        Log.d("ButtonHandler", "Screen turned on (Power button)");
                        // Use Handler to ensure event is sent after app resumes
                        new Handler(Looper.getMainLooper()).postDelayed(new Runnable() {
                            @Override
                            public void run() {
                                if (buttonEventSink != null) {
                                    buttonEventSink.success("power_on");
                                }
                            }
                        }, 100);
                    } else if (Intent.ACTION_SCREEN_OFF.equals(intent.getAction())) {
                        Log.d("ButtonHandler", "Screen turned off (Power button)");
                        if (buttonEventSink != null) {
                            buttonEventSink.success("power_off");
                        }
                    }
                }
            };
            
            IntentFilter filter = new IntentFilter();
            filter.addAction(Intent.ACTION_SCREEN_ON);
            filter.addAction(Intent.ACTION_SCREEN_OFF);
            // Register as a receiver that can receive broadcasts even when app is in background
            try {
                activity.registerReceiver(screenReceiver, filter);
            } catch (Exception e) {
                Log.e("ButtonHandler", "Error registering screen receiver: " + e.getMessage(), e);
            }
        }
    }
    
    public void unregisterScreenReceiver() {
        if (screenReceiver != null) {
            try {
                activity.unregisterReceiver(screenReceiver);
            } catch (Exception e) {
                Log.e("ButtonHandler", "Error unregistering screen receiver: " + e.getMessage(), e);
            }
            screenReceiver = null;
        }
    }
}

