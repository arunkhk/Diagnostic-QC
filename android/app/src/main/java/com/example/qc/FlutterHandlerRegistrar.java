package com.example.qc;

import com.example.qc.handlers.*;
import io.flutter.embedding.engine.FlutterEngine;
import io.flutter.plugin.common.EventChannel;
import io.flutter.plugin.common.MethodChannel;
import android.app.Activity;
import android.util.Log;

/**
 * Helper class to register all Flutter platform channels and handlers.
 * This can be used by both android/app MainActivity and flutter_module MainActivity.
 */
public class FlutterHandlerRegistrar {
    private static final String PACKAGE_NAME = "com.example.qc";
    
    // Method channel names
    private static final String BLUETOOTH_CHANNEL = PACKAGE_NAME + "/bluetooth";
    private static final String WIFI_CHANNEL = PACKAGE_NAME + "/wifi";
    private static final String PHONE_CHANNEL = PACKAGE_NAME + "/phone";
    private static final String HEADPHONES_CHANNEL = PACKAGE_NAME + "/headphones";
    private static final String SETTINGS_CHANNEL = PACKAGE_NAME + "/settings";
    private static final String BRIGHTNESS_CHANNEL = PACKAGE_NAME + "/brightness";
    private static final String BUTTON_CHANNEL = PACKAGE_NAME + "/buttons";
    private static final String SD_CARD_CHANNEL = PACKAGE_NAME + "/sdcard";
    private static final String CHARGER_CHANNEL = PACKAGE_NAME + "/charger";
    private static final String BATTERY_CHANNEL = PACKAGE_NAME + "/battery";
    private static final String TOUCH_CHANNEL = PACKAGE_NAME + "/touch";
    private static final String OTG_CHANNEL = PACKAGE_NAME + "/otg";
    
    /**
     * Register all handlers with the Flutter engine.
     * This method can be called from any MainActivity (android/app or flutter_module).
     * 
     * @param handlers Optional handler instances. If provided, uses them; otherwise creates new ones.
     */
    public static void registerHandlers(
        FlutterEngine flutterEngine, 
        Activity activity,
        BluetoothHandler bluetoothHandler,
        WifiHandler wifiHandler,
        PhoneHandler phoneHandler,
        HeadphonesHandler headphonesHandler,
        SettingsHandler settingsHandler,
        BrightnessHandler brightnessHandler,
        ButtonHandler buttonHandler,
        SDCardHandler sdCardHandler,
        ChargerHandler chargerHandler,
        BatteryHandler batteryHandler,
        TouchHandler touchHandler,
        OTGHandler otgHandler
    ) {
        // Use provided handlers or create new ones
        BluetoothHandler bluetooth = bluetoothHandler != null ? bluetoothHandler : new BluetoothHandler(activity);
        WifiHandler wifi = wifiHandler != null ? wifiHandler : new WifiHandler(activity);
        PhoneHandler phone = phoneHandler != null ? phoneHandler : new PhoneHandler(activity);
        HeadphonesHandler headphones = headphonesHandler != null ? headphonesHandler : new HeadphonesHandler(activity);
        SettingsHandler settings = settingsHandler != null ? settingsHandler : new SettingsHandler(activity);
        BrightnessHandler brightness = brightnessHandler != null ? brightnessHandler : new BrightnessHandler(activity);
        ButtonHandler button = buttonHandler != null ? buttonHandler : new ButtonHandler(activity);
        SDCardHandler sdCard = sdCardHandler != null ? sdCardHandler : new SDCardHandler(activity);
        ChargerHandler charger = chargerHandler != null ? chargerHandler : new ChargerHandler(activity);
        BatteryHandler battery = batteryHandler != null ? batteryHandler : new BatteryHandler(activity);
        TouchHandler touch = touchHandler != null ? touchHandler : new TouchHandler(activity);
        OTGHandler otg = otgHandler != null ? otgHandler : new OTGHandler(activity);
        
        // Bluetooth channel
        new MethodChannel(flutterEngine.getDartExecutor().getBinaryMessenger(), BLUETOOTH_CHANNEL)
            .setMethodCallHandler((call, result) -> bluetooth.handleMethodCall(call, result));
        
        // WiFi channel
        new MethodChannel(flutterEngine.getDartExecutor().getBinaryMessenger(), WIFI_CHANNEL)
            .setMethodCallHandler((call, result) -> wifi.handleMethodCall(call, result));
        
        // Phone dialer channel
        new MethodChannel(flutterEngine.getDartExecutor().getBinaryMessenger(), PHONE_CHANNEL)
            .setMethodCallHandler((call, result) -> phone.handleMethodCall(call, result));
        
        // Headphones channel
        new MethodChannel(flutterEngine.getDartExecutor().getBinaryMessenger(), HEADPHONES_CHANNEL)
            .setMethodCallHandler((call, result) -> headphones.handleMethodCall(call, result));
        
        // Settings channel
        new MethodChannel(flutterEngine.getDartExecutor().getBinaryMessenger(), SETTINGS_CHANNEL)
            .setMethodCallHandler((call, result) -> settings.handleMethodCall(call, result));
        
        // Brightness channel
        new MethodChannel(flutterEngine.getDartExecutor().getBinaryMessenger(), BRIGHTNESS_CHANNEL)
            .setMethodCallHandler((call, result) -> brightness.handleMethodCall(call, result));
        
        // Button detection channel (for Home, Menu, Power buttons)
        MethodChannel buttonMethodChannel = new MethodChannel(flutterEngine.getDartExecutor().getBinaryMessenger(), BUTTON_CHANNEL);
        buttonMethodChannel.setMethodCallHandler((call, result) -> {
            if ("hasMenuButton".equals(call.method)) {
                result.success(button.hasMenuButton());
            } else {
                result.notImplemented();
            }
        });
        
        new EventChannel(flutterEngine.getDartExecutor().getBinaryMessenger(), BUTTON_CHANNEL + "/events")
            .setStreamHandler(new EventChannel.StreamHandler() {
                @Override
                public void onListen(Object arguments, EventChannel.EventSink events) {
                    Log.d("FlutterHandlerRegistrar", "Button event channel listener attached");
                    button.setEventSink(events);
                }
                
                @Override
                public void onCancel(Object arguments) {
                    Log.d("FlutterHandlerRegistrar", "Button event channel listener cancelled");
                    button.setEventSink(null);
                }
            });
        
        // SD Card detection channel
        new MethodChannel(flutterEngine.getDartExecutor().getBinaryMessenger(), SD_CARD_CHANNEL)
            .setMethodCallHandler((call, result) -> sdCard.handleMethodCall(call, result));
        
        // Charger detection channel
        new MethodChannel(flutterEngine.getDartExecutor().getBinaryMessenger(), CHARGER_CHANNEL)
            .setMethodCallHandler((call, result) -> charger.handleMethodCall(call, result));
        
        new EventChannel(flutterEngine.getDartExecutor().getBinaryMessenger(), CHARGER_CHANNEL + "/events")
            .setStreamHandler(new EventChannel.StreamHandler() {
                @Override
                public void onListen(Object arguments, EventChannel.EventSink events) {
                    Log.d("FlutterHandlerRegistrar", "Charger event channel listener attached");
                    charger.setEventSink(events);
                }
                
                @Override
                public void onCancel(Object arguments) {
                    Log.d("FlutterHandlerRegistrar", "Charger event channel listener cancelled");
                    charger.setEventSink(null);
                }
            });
        
        // Battery detection channel
        new MethodChannel(flutterEngine.getDartExecutor().getBinaryMessenger(), BATTERY_CHANNEL)
            .setMethodCallHandler((call, result) -> battery.handleMethodCall(call, result));
        
        new EventChannel(flutterEngine.getDartExecutor().getBinaryMessenger(), BATTERY_CHANNEL + "/events")
            .setStreamHandler(new EventChannel.StreamHandler() {
                @Override
                public void onListen(Object arguments, EventChannel.EventSink events) {
                    Log.d("FlutterHandlerRegistrar", "Battery event channel listener attached");
                    battery.setEventSink(events);
                }
                
                @Override
                public void onCancel(Object arguments) {
                    Log.d("FlutterHandlerRegistrar", "Battery event channel listener cancelled");
                    battery.setEventSink(null);
                }
            });
        
        // Touch detection channel - Method channel only (for launching TouchActivity)
        new MethodChannel(flutterEngine.getDartExecutor().getBinaryMessenger(), TOUCH_CHANNEL)
            .setMethodCallHandler((call, result) -> touch.handleMethodCall(call, result));
        
        // Touch event channels disabled - not needed for TouchActivity launch
        
        // OTG detection channel
        new MethodChannel(flutterEngine.getDartExecutor().getBinaryMessenger(), OTG_CHANNEL)
            .setMethodCallHandler((call, result) -> otg.handleMethodCall(call, result));
        
        new EventChannel(flutterEngine.getDartExecutor().getBinaryMessenger(), OTG_CHANNEL + "/events")
            .setStreamHandler(new EventChannel.StreamHandler() {
                @Override
                public void onListen(Object arguments, EventChannel.EventSink events) {
                    Log.d("FlutterHandlerRegistrar", "OTG event channel listener attached");
                    otg.setEventSink(events);
                }
                
                @Override
                public void onCancel(Object arguments) {
                    Log.d("FlutterHandlerRegistrar", "OTG event channel listener cancelled");
                    otg.setEventSink(null);
                }
            });
        
        // Cache FlutterEngine
        io.flutter.embedding.engine.FlutterEngineCache.getInstance().put("main_engine", flutterEngine);
    }
}

