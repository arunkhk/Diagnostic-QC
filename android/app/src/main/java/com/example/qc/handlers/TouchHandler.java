package com.example.qc.handlers;

import android.app.Activity;
import android.content.Intent;
import android.util.Log;
import android.view.MotionEvent;
import io.flutter.plugin.common.EventChannel;
import io.flutter.plugin.common.MethodCall;
import io.flutter.plugin.common.MethodChannel;

public class TouchHandler {
    
    private final Activity activity;
    private EventChannel.EventSink touchEventSink;
    private EventChannel.EventSink touchResultEventSink;
    private boolean isListening = false;
    
    private static volatile TouchHandler instance;
    
    public TouchHandler(Activity activity) {
        this.activity = activity;
        instance = this;
    }
    
    public static void sendTouchResult(boolean isPass) {
        if (instance != null && instance.touchResultEventSink != null) {
            java.util.Map<String, Object> result = new java.util.HashMap<>();
            result.put("passed", isPass);
            instance.touchResultEventSink.success(result);
            Log.d("TouchHandler", "Static sendTouchResult called with: " + isPass);
        }
    }
    
    public void handleMethodCall(MethodCall call, MethodChannel.Result result) {
        Log.d("TouchHandler", "Method called: " + call.method);
        if ("startTouchTest".equals(call.method)) {
            try {
                startTouchTest();
                result.success(true);
            } catch (Exception e) {
                Log.e("TouchHandler", "Error starting touch test: " + e.getMessage(), e);
                result.error("TOUCH_ERROR", "Failed to start touch test: " + e.getMessage(), null);
            }
        } else if ("startTouchDetection".equals(call.method)) {
            try {
                startTouchDetection();
                result.success(true);
            } catch (Exception e) {
                Log.e("TouchHandler", "Error starting touch detection: " + e.getMessage(), e);
                result.error("TOUCH_ERROR", "Failed to start touch detection: " + e.getMessage(), null);
            }
        } else if ("stopTouchDetection".equals(call.method)) {
            try {
                stopTouchDetection();
                result.success(true);
            } catch (Exception e) {
                Log.e("TouchHandler", "Error stopping touch detection: " + e.getMessage(), e);
                result.error("TOUCH_ERROR", "Failed to stop touch detection: " + e.getMessage(), null);
            }
        } else if ("hideSystemUI".equals(call.method)) {
            try {
                hideSystemUI();
                result.success(true);
            } catch (Exception e) {
                Log.e("TouchHandler", "Error hiding system UI: " + e.getMessage(), e);
                result.error("TOUCH_ERROR", "Failed to hide system UI: " + e.getMessage(), null);
            }
        } else if ("showSystemUI".equals(call.method)) {
            try {
                showSystemUI();
                result.success(true);
            } catch (Exception e) {
                Log.e("TouchHandler", "Error showing system UI: " + e.getMessage(), e);
                result.error("TOUCH_ERROR", "Failed to show system UI: " + e.getMessage(), null);
            }
        } else {
            Log.w("TouchHandler", "Unknown method: " + call.method);
            result.notImplemented();
        }
    }
    
    private void startTouchTest() {
        Log.d("TouchHandler", "Starting native TouchActivity");
        Intent intent = new Intent(activity, com.example.qc.Activity.TouchActivity.class);
        activity.startActivity(intent);
    }
    
    public void setEventSink(EventChannel.EventSink sink) {
        touchEventSink = sink;
        if (sink != null) {
            isListening = true;
        } else {
            isListening = false;
        }
    }
    
    public void setResultEventSink(EventChannel.EventSink sink) {
        touchResultEventSink = sink;
    }
    
    public boolean onTouchEvent(MotionEvent event) {
        if (!isListening || touchEventSink == null) {
            return false;
        }
        
        switch (event.getAction()) {
            case MotionEvent.ACTION_DOWN:
                Log.d("TouchHandler", "Touch down at (" + event.getX() + ", " + event.getY() + ")");
                touchEventSink.success("touch_down");
                break;
            case MotionEvent.ACTION_MOVE:
                Log.d("TouchHandler", "Touch move at (" + event.getX() + ", " + event.getY() + ")");
                touchEventSink.success("touch_move");
                break;
            case MotionEvent.ACTION_UP:
                Log.d("TouchHandler", "Touch up at (" + event.getX() + ", " + event.getY() + ")");
                touchEventSink.success("touch_up");
                break;
            case MotionEvent.ACTION_CANCEL:
                Log.d("TouchHandler", "Touch cancel");
                touchEventSink.success("touch_cancel");
                break;
        }
        
        return true;
    }
    
    private void startTouchDetection() {
        Log.d("TouchHandler", "Starting touch detection");
        isListening = true;
    }
    
    private void stopTouchDetection() {
        Log.d("TouchHandler", "Stopping touch detection");
        isListening = false;
    }
    
    private void hideSystemUI() {
        activity.runOnUiThread(new Runnable() {
            @Override
            public void run() {
                try {
                    android.view.View decorView = activity.getWindow().getDecorView();
                    decorView.setSystemUiVisibility(
                        android.view.View.SYSTEM_UI_FLAG_LAYOUT_STABLE
                        | android.view.View.SYSTEM_UI_FLAG_LAYOUT_HIDE_NAVIGATION
                        | android.view.View.SYSTEM_UI_FLAG_LAYOUT_FULLSCREEN
                        | android.view.View.SYSTEM_UI_FLAG_HIDE_NAVIGATION
                        | android.view.View.SYSTEM_UI_FLAG_FULLSCREEN
                        | android.view.View.SYSTEM_UI_FLAG_IMMERSIVE_STICKY
                    );
                    Log.d("TouchHandler", "System UI hidden");
                } catch (Exception e) {
                    Log.e("TouchHandler", "Error hiding system UI: " + e.getMessage(), e);
                }
            }
        });
    }
    
    private void showSystemUI() {
        activity.runOnUiThread(new Runnable() {
            @Override
            public void run() {
                try {
                    android.view.View decorView = activity.getWindow().getDecorView();
                    decorView.setSystemUiVisibility(android.view.View.SYSTEM_UI_FLAG_VISIBLE);
                    Log.d("TouchHandler", "System UI shown");
                } catch (Exception e) {
                    Log.e("TouchHandler", "Error showing system UI: " + e.getMessage(), e);
                }
            }
        });
    }
}

