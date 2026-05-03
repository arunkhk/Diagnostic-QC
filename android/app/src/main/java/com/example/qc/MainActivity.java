package com.example.qc;

import com.example.qc.handlers.*;
import io.flutter.embedding.android.FlutterFragmentActivity;
import io.flutter.embedding.engine.FlutterEngine;
import android.view.KeyEvent;

public class MainActivity extends FlutterFragmentActivity {
    
    // Handler instances
    private BluetoothHandler bluetoothHandler;
    private WifiHandler wifiHandler;
    private PhoneHandler phoneHandler;
    private HeadphonesHandler headphonesHandler;
    private SettingsHandler settingsHandler;
    private BrightnessHandler brightnessHandler;
    private ButtonHandler buttonHandler;
    private SDCardHandler sdCardHandler;
    private ChargerHandler chargerHandler;
    private BatteryHandler batteryHandler;
    private TouchHandler touchHandler;
    private OTGHandler otgHandler;

    @Override
    public void configureFlutterEngine(FlutterEngine flutterEngine) {
        super.configureFlutterEngine(flutterEngine);
        
        // Initialize handlers first (needed for lifecycle management)
        bluetoothHandler = new BluetoothHandler(this);
        wifiHandler = new WifiHandler(this);
        phoneHandler = new PhoneHandler(this);
        headphonesHandler = new HeadphonesHandler(this);
        settingsHandler = new SettingsHandler(this);
        brightnessHandler = new BrightnessHandler(this);
        buttonHandler = new ButtonHandler(this);
        sdCardHandler = new SDCardHandler(this);
        chargerHandler = new ChargerHandler(this);
        batteryHandler = new BatteryHandler(this);
        touchHandler = new TouchHandler(this);
        otgHandler = new OTGHandler(this);
        
        // Delegate handler registration to shared helper
        FlutterHandlerRegistrar.registerHandlers(flutterEngine, this, 
            bluetoothHandler, wifiHandler, phoneHandler, headphonesHandler,
            settingsHandler, brightnessHandler, buttonHandler, sdCardHandler,
            chargerHandler, batteryHandler, touchHandler, otgHandler);
    }
    
    @Override
    public void onUserLeaveHint() {
        super.onUserLeaveHint();
        if (buttonHandler != null) {
            buttonHandler.onUserLeaveHint();
        }
    }
    
    @Override
    public boolean onKeyDown(int keyCode, KeyEvent event) {
        if (buttonHandler != null) {
            boolean handled = buttonHandler.onKeyDown(keyCode, event);
            if (handled) return true;
        }
        return super.onKeyDown(keyCode, event);
    }
    
    
    @Override
    public void onDestroy() {
        super.onDestroy();
        if (buttonHandler != null) {
            buttonHandler.unregisterScreenReceiver();
        }
        if (chargerHandler != null) {
            chargerHandler.unregisterBatteryReceiver();
        }
        if (batteryHandler != null) {
            batteryHandler.unregisterBatteryReceiver();
        }
        if (otgHandler != null) {
            otgHandler.unregisterUsbReceivers();
        }
    }
}

