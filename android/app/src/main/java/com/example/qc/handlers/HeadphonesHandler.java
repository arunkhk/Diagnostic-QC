package com.example.qc.handlers;

import android.app.Activity;
import android.content.Context;
import android.media.AudioManager;
import android.media.Ringtone;
import android.media.RingtoneManager;
import android.net.Uri;
import android.os.Handler;
import android.os.Looper;
import android.util.Log;
import io.flutter.plugin.common.MethodCall;
import io.flutter.plugin.common.MethodChannel;

public class HeadphonesHandler {
    
    private final Activity activity;
    
    public HeadphonesHandler(Activity activity) {
        this.activity = activity;
    }
    
    public void handleMethodCall(MethodCall call, MethodChannel.Result result) {
        Log.d("HeadphonesHandler", "Method called: " + call.method);
        if ("isHeadphonesConnected".equals(call.method)) {
            try {
                boolean isConnected = isHeadphonesConnected();
                Log.d("HeadphonesHandler", "Headphones connected: " + isConnected);
                result.success(isConnected);
            } catch (Exception e) {
                Log.e("HeadphonesHandler", "Error checking headphones: " + e.getMessage(), e);
                result.error("HEADPHONES_ERROR", "Failed to check headphones: " + e.getMessage(), null);
            }
        } else if ("playDefaultRingtone".equals(call.method)) {
            try {
                playDefaultRingtone();
                result.success(true);
            } catch (Exception e) {
                Log.e("HeadphonesHandler", "Error playing ringtone: " + e.getMessage(), e);
                result.error("RINGTONE_ERROR", "Failed to play ringtone: " + e.getMessage(), null);
            }
        } else {
            Log.w("HeadphonesHandler", "Unknown method: " + call.method);
            result.notImplemented();
        }
    }

    private boolean isHeadphonesConnected() {
        try {
            AudioManager audioManager = (AudioManager) activity.getSystemService(Context.AUDIO_SERVICE);
            boolean isWiredHeadsetOn = audioManager.isWiredHeadsetOn();
            boolean isBluetoothA2dpOn = audioManager.isBluetoothA2dpOn();
            return isWiredHeadsetOn || isBluetoothA2dpOn;
        } catch (Exception e) {
            Log.e("HeadphonesHandler", "Error checking headphones: " + e.getMessage(), e);
            return false;
        }
    }

    private void playDefaultRingtone() {
        try {
            Uri ringtoneUri = RingtoneManager.getDefaultUri(RingtoneManager.TYPE_RINGTONE);
            Ringtone ringtone = RingtoneManager.getRingtone(activity.getApplicationContext(), ringtoneUri);
            if (ringtone != null) {
                ringtone.play();
                
                // Stop after 5 seconds
                new Handler(Looper.getMainLooper()).postDelayed(new Runnable() {
                    @Override
                    public void run() {
                        ringtone.stop();
                    }
                }, 5000);
            }
        } catch (Exception e) {
            Log.e("HeadphonesHandler", "Error playing ringtone: " + e.getMessage(), e);
            throw e;
        }
    }
}

