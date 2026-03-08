package com.example.qc.Activity;

import android.graphics.Color;
import android.os.Bundle;
import android.util.Log;
import android.view.View;
import android.app.Activity;
import com.example.qc.Utility.DrawView;
import android.widget.Toast;
// R class will be resolved from the build context (android/app or flutter_module)

public class TouchActivity extends Activity {
    
    private DrawView drawView;
    private boolean touchCompleteFlag = false;
    private int counter = 0;
    private static final String TAG = "TouchActivity";
    
    @Override
    protected void onCreate(Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);
        // Create DrawView programmatically to avoid R class issues
        // This works in both android/app and flutter_module builds
        drawView = new DrawView(this);
        drawView.setBackgroundColor(Color.WHITE);
        setContentView(drawView);
        
        // Hide system UI (full screen immersive mode)
        hideSystemUI(this);
        
        // Listen for completion events (when all grid boxes are filled)
        drawView.setOnCompleteListener(new Runnable() {
            @Override
            public void run() {
                if (!touchCompleteFlag) {
                    touchCompleteFlag = true;
                    // All boxes filled - touch is working - send pass result
                    sendResultToFlutter(true);
                }
            }
        });
    }
    
    private void sendResultToFlutter(boolean isPass) {
        try {
            // Send result via TouchHandler static method
            com.example.qc.handlers.TouchHandler.sendTouchResult(isPass);
            Log.d(TAG, "Result sent to Flutter: " + (isPass ? "PASS" : "FAIL"));
            
            // Restore system UI before finishing to ensure MainActivity has proper insets
            restoreSystemUI();
            
            // Close activity after sending result
            finish();
        } catch (Exception e) {
            Log.e(TAG, "Error sending result to Flutter: " + e.getMessage(), e);
        }
    }
    
    private void restoreSystemUI() {
        try {
            View decorView = getWindow().getDecorView();
            decorView.setSystemUiVisibility(View.SYSTEM_UI_FLAG_VISIBLE);
            Log.d(TAG, "System UI restored before finishing");
        } catch (Exception e) {
            Log.e(TAG, "Error restoring system UI: " + e.getMessage(), e);
        }
    }
    
    @Override
    public void onBackPressed() {
        if (counter == 0) {
            counter++;
            Toast.makeText(
                this,
                "Click one more time back button to skip!",
                Toast.LENGTH_SHORT
            ).show();
        } else {
            // User skipped - send fail result
            sendResultToFlutter(false);
        }
    }
    
    public static void hideSystemUI(Activity activity) {
        try {
            View decorView = activity.getWindow().getDecorView();
            decorView.setSystemUiVisibility(
                View.SYSTEM_UI_FLAG_LAYOUT_STABLE
                | View.SYSTEM_UI_FLAG_LAYOUT_HIDE_NAVIGATION
                | View.SYSTEM_UI_FLAG_LAYOUT_FULLSCREEN
                | View.SYSTEM_UI_FLAG_HIDE_NAVIGATION
                | View.SYSTEM_UI_FLAG_FULLSCREEN
                | View.SYSTEM_UI_FLAG_IMMERSIVE_STICKY
            );
        } catch (Exception e) {
            Log.e(TAG, "Error hiding system UI: " + e.getMessage(), e);
        }
    }
    
    @Override
    protected void onResume() {
        super.onResume();
        // Re-hide system UI when activity resumes
        hideSystemUI(this);
    }
}

