package com.example.qc.handlers;

import android.app.Activity;
import android.content.BroadcastReceiver;
import android.content.Context;
import android.content.Intent;
import android.content.IntentFilter;
import android.content.pm.PackageManager;
import android.hardware.usb.UsbDevice;
import android.hardware.usb.UsbManager;
import android.os.Build;
import android.util.Log;
import io.flutter.plugin.common.EventChannel;
import io.flutter.plugin.common.MethodCall;
import io.flutter.plugin.common.MethodChannel;
import java.util.HashMap;
import java.util.Map;

public class OTGHandler {

    private final Activity activity;
    private EventChannel.EventSink otgEventSink;
    private BroadcastReceiver usbAttachReceiver;
    private BroadcastReceiver usbDetachReceiver;
    private boolean isListening = false;

    public OTGHandler(Activity activity) {
        this.activity = activity;
    }

    public void handleMethodCall(MethodCall call, MethodChannel.Result result) {
        Log.d("OTGHandler", "Method called: " + call.method);
        if ("checkOTGSupport".equals(call.method)) {
            try {
                boolean isSupported = checkOTGSupport();
                Log.d("OTGHandler", "OTG support check: " + isSupported);
                result.success(isSupported);
            } catch (Exception e) {
                Log.e("OTGHandler", "Error checking OTG support: " + e.getMessage(), e);
                result.error("OTG_ERROR", "Failed to check OTG support: " + e.getMessage(), null);
            }
        } else if ("startOTGDetection".equals(call.method)) {
            try {
                startOTGDetection();
                result.success(true);
            } catch (Exception e) {
                Log.e("OTGHandler", "Error starting OTG detection: " + e.getMessage(), e);
                result.error("OTG_ERROR", "Failed to start OTG detection: " + e.getMessage(), null);
            }
        } else if ("stopOTGDetection".equals(call.method)) {
            try {
                stopOTGDetection();
                result.success(true);
            } catch (Exception e) {
                Log.e("OTGHandler", "Error stopping OTG detection: " + e.getMessage(), e);
                result.error("OTG_ERROR", "Failed to stop OTG detection: " + e.getMessage(), null);
            }
        } else {
            Log.w("OTGHandler", "Unknown method: " + call.method);
            result.notImplemented();
        }
    }

    public void setEventSink(EventChannel.EventSink sink) {
        otgEventSink = sink;
        if (sink != null) {
            isListening = true;
            startOTGDetection();
        } else {
            isListening = false;
            stopOTGDetection();
        }
    }

    private boolean checkOTGSupport() {
        try {
            boolean hasUsbHost = activity.getPackageManager().hasSystemFeature(PackageManager.FEATURE_USB_HOST);
            Log.d("OTGHandler", "USB Host feature available: " + hasUsbHost);
            return hasUsbHost;
        } catch (Exception e) {
            Log.e("OTGHandler", "Error checking USB host feature: " + e.getMessage(), e);
            return false;
        }
    }

    private void startOTGDetection() {
        if (isListening && otgEventSink != null) {
            registerUsbReceivers();
            // Check for already connected devices on background thread to avoid ANR
            new Thread(new Runnable() {
                @Override
                public void run() {
                    checkAlreadyConnectedDevices();
                }
            }).start();
            Log.d("OTGHandler", "OTG detection started");
        }
    }

    private void checkAlreadyConnectedDevices() {
        try {
            UsbManager usbManager = (UsbManager) activity.getSystemService(Context.USB_SERVICE);
            if (usbManager != null) {
                Map<String, UsbDevice> deviceList = usbManager.getDeviceList();
                if (!deviceList.isEmpty()) {
                    UsbDevice device = deviceList.values().iterator().next();
                    int vendorId = device.getVendorId();
                    int productId = device.getProductId();
                    Log.d("OTGHandler", "Found already connected USB device - VendorId: " + vendorId + ", ProductId: " + productId);
                    
                    final Map<String, Object> deviceInfo = new HashMap<>();
                    deviceInfo.put("attached", true);
                    deviceInfo.put("vendorId", vendorId);
                    deviceInfo.put("productId", productId);
                    deviceInfo.put("vendorIdText", "Vendor Id : " + vendorId);
                    deviceInfo.put("productIdText", "Product Id : " + productId);
                    // Send on main thread to avoid threading issues
                    activity.runOnUiThread(new Runnable() {
                        @Override
                        public void run() {
                            if (otgEventSink != null) {
                                otgEventSink.success(deviceInfo);
                            }
                        }
                    });
                } else {
                    Log.d("OTGHandler", "No already connected USB devices found");
                }
            }
        } catch (Exception e) {
            Log.e("OTGHandler", "Error checking already connected devices: " + e.getMessage(), e);
        }
    }

    private void stopOTGDetection() {
        unregisterUsbReceivers();
        Log.d("OTGHandler", "OTG detection stopped");
    }

    private void registerUsbReceivers() {
        if (usbAttachReceiver == null) {
            usbAttachReceiver = new BroadcastReceiver() {
                @Override
                public void onReceive(Context context, Intent intent) {
                    if (UsbManager.ACTION_USB_DEVICE_ATTACHED.equals(intent.getAction())) {
                        UsbDevice device = null;
                        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
                            device = intent.getParcelableExtra(UsbManager.EXTRA_DEVICE, UsbDevice.class);
                        } else {
                            device = intent.getParcelableExtra(UsbManager.EXTRA_DEVICE);
                        }
                        if (device != null) {
                            int vendorId = device.getVendorId();
                            int productId = device.getProductId();
                            Log.d("OTGHandler", "USB device attached - VendorId: " + vendorId + ", ProductId: " + productId);
                            
                            Map<String, Object> deviceInfo = new HashMap<>();
                            deviceInfo.put("attached", true);
                            deviceInfo.put("vendorId", vendorId);
                            deviceInfo.put("productId", productId);
                            deviceInfo.put("vendorIdText", "Vendor Id : " + vendorId);
                            deviceInfo.put("productIdText", "Product Id : " + productId);
                            if (otgEventSink != null) {
                                otgEventSink.success(deviceInfo);
                            }
                        }
                    }
                }
            };

            IntentFilter attachFilter = new IntentFilter(UsbManager.ACTION_USB_DEVICE_ATTACHED);
            try {
                activity.registerReceiver(usbAttachReceiver, attachFilter);
                Log.d("OTGHandler", "USB attach receiver registered");
            } catch (Exception e) {
                Log.e("OTGHandler", "Error registering USB attach receiver: " + e.getMessage(), e);
            }
        }

        if (usbDetachReceiver == null) {
            usbDetachReceiver = new BroadcastReceiver() {
                @Override
                public void onReceive(Context context, Intent intent) {
                    if (UsbManager.ACTION_USB_DEVICE_DETACHED.equals(intent.getAction())) {
                        Log.d("OTGHandler", "USB device detached");
                        Map<String, Object> deviceInfo = new HashMap<>();
                        deviceInfo.put("attached", false);
                        deviceInfo.put("vendorId", -1);
                        deviceInfo.put("productId", -1);
                        deviceInfo.put("vendorIdText", "No Device Found");
                        deviceInfo.put("productIdText", "");
                        if (otgEventSink != null) {
                            otgEventSink.success(deviceInfo);
                        }
                    }
                }
            };

            IntentFilter detachFilter = new IntentFilter(UsbManager.ACTION_USB_DEVICE_DETACHED);
            try {
                activity.registerReceiver(usbDetachReceiver, detachFilter);
                Log.d("OTGHandler", "USB detach receiver registered");
            } catch (Exception e) {
                Log.e("OTGHandler", "Error registering USB detach receiver: " + e.getMessage(), e);
            }
        }
    }

    public void unregisterUsbReceivers() {
        if (usbAttachReceiver != null) {
            try {
                activity.unregisterReceiver(usbAttachReceiver);
                Log.d("OTGHandler", "USB attach receiver unregistered");
            } catch (Exception e) {
                Log.e("OTGHandler", "Error unregistering USB attach receiver: " + e.getMessage(), e);
            }
            usbAttachReceiver = null;
        }

        if (usbDetachReceiver != null) {
            try {
                activity.unregisterReceiver(usbDetachReceiver);
                Log.d("OTGHandler", "USB detach receiver unregistered");
            } catch (Exception e) {
                Log.e("OTGHandler", "Error unregistering USB detach receiver: " + e.getMessage(), e);
            }
            usbDetachReceiver = null;
        }
    }
}

