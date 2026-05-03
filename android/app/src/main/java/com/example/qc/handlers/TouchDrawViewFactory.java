package com.example.qc.handlers;

import android.content.Context;
import android.view.View;
import android.view.MotionEvent;
import io.flutter.plugin.common.BinaryMessenger;
import io.flutter.plugin.common.EventChannel;
import io.flutter.plugin.common.StandardMessageCodec;
import io.flutter.plugin.platform.PlatformView;
import io.flutter.plugin.platform.PlatformViewFactory;
import android.util.Log;

public class TouchDrawViewFactory extends PlatformViewFactory {
    
    private final BinaryMessenger messenger;
    
    public TouchDrawViewFactory(BinaryMessenger messenger) {
        super(StandardMessageCodec.INSTANCE);
        this.messenger = messenger;
    }
    
    @Override
    public PlatformView create(Context context, int viewId, Object args) {
        return new TouchDrawViewPlatformView(context, messenger, viewId);
    }
}

class TouchDrawViewPlatformView implements PlatformView {
    
    private final Context context;
    private final BinaryMessenger messenger;
    private final int viewId;
    private final TouchDrawView drawView;
    private EventChannel.EventSink eventSink;
    
    public TouchDrawViewPlatformView(Context context, BinaryMessenger messenger, int viewId) {
        this.context = context;
        this.messenger = messenger;
        this.viewId = viewId;
        this.drawView = new TouchDrawView(context);
        
        // Set white background as per the original implementation
        drawView.setBackgroundColor(android.graphics.Color.WHITE);
        
        // Set up event channel for touch events
        EventChannel eventChannel = new EventChannel(messenger, "com.example.qc/touch_draw_view/events");
        eventChannel.setStreamHandler(new EventChannel.StreamHandler() {
            @Override
            public void onListen(Object arguments, EventChannel.EventSink events) {
                Log.d("TouchDrawView", "Event channel listener attached");
                eventSink = events;
                drawView.setEventSink(events);
            }
            
            @Override
            public void onCancel(Object arguments) {
                Log.d("TouchDrawView", "Event channel listener cancelled");
                eventSink = null;
                drawView.setEventSink(null);
            }
        });
    }
    
    @Override
    public View getView() {
        return drawView;
    }
    
    @Override
    public void dispose() {
        eventSink = null;
        drawView.setEventSink(null);
    }
}

// Custom DrawView similar to Android DrawView - matches the Java implementation
class TouchDrawView extends View {
    private android.graphics.Paint paint;
    private java.util.List<android.graphics.Path> paths;
    private android.graphics.Path currentPath;
    private EventChannel.EventSink touchEventSink;
    private boolean hasDrawn = false;
    
    public TouchDrawView(Context context) {
        super(context);
        paint = new android.graphics.Paint();
        paint.setColor(android.graphics.Color.BLACK);
        paint.setStrokeWidth(4f);
        paint.setStyle(android.graphics.Paint.Style.STROKE);
        paint.setStrokeCap(android.graphics.Paint.Cap.ROUND);
        paint.setStrokeJoin(android.graphics.Paint.Join.ROUND);
        paths = new java.util.ArrayList<>();
    }
    
    public void setEventSink(EventChannel.EventSink sink) {
        touchEventSink = sink;
    }
    
    @Override
    protected void onDraw(android.graphics.Canvas canvas) {
        super.onDraw(canvas);
        // Background is set via setBackgroundColor, so we don't need to draw it here
        
        for (android.graphics.Path path : paths) {
            canvas.drawPath(path, paint);
        }
        
        if (currentPath != null) {
            canvas.drawPath(currentPath, paint);
        }
    }
    
    @Override
    public boolean onTouchEvent(MotionEvent event) {
        switch (event.getAction()) {
            case MotionEvent.ACTION_DOWN:
                currentPath = new android.graphics.Path();
                currentPath.moveTo(event.getX(), event.getY());
                invalidate();
                // Notify Flutter about touch down
                if (touchEventSink != null) {
                    touchEventSink.success("touch_down");
                }
                break;
            case MotionEvent.ACTION_MOVE:
                if (currentPath != null) {
                    currentPath.lineTo(event.getX(), event.getY());
                    invalidate();
                    hasDrawn = true;
                    // Notify Flutter about touch move (drawing detected)
                    if (hasDrawn && touchEventSink != null) {
                        touchEventSink.success("touch_drawn");
                    }
                }
                break;
            case MotionEvent.ACTION_UP:
                if (currentPath != null) {
                    paths.add(currentPath);
                    currentPath = null;
                    invalidate();
                }
                // Notify Flutter that touch is complete
                if (hasDrawn && touchEventSink != null) {
                    touchEventSink.success("touch_complete");
                }
                break;
            case MotionEvent.ACTION_CANCEL:
                currentPath = null;
                invalidate();
                if (touchEventSink != null) {
                    touchEventSink.success("touch_cancel");
                }
                break;
        }
        return true;
    }
    
    public void clear() {
        paths.clear();
        currentPath = null;
        hasDrawn = false;
        invalidate();
    }
}

