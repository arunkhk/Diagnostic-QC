package com.example.qc.Utility;

import android.content.Context;
import android.graphics.Canvas;
import android.graphics.Color;
import android.graphics.Paint;
import android.graphics.Path;
import android.util.AttributeSet;
import android.view.MotionEvent;
import android.view.View;
import java.util.ArrayList;
import java.util.HashSet;

public class DrawView extends View {
    
    private int screenW = 0;
    private int screenH = 0;
    private Paint paint;
    private int x = 0;
    private int y = 0;
    private Paint paintFill;
    
    private Paint mPaint;
    private Path mPath;
    private Path mPath2;
    
    private ArrayList<Integer> list1;
    private ArrayList<Integer> list2;
    
    private int a1 = 0;
    private int b1 = 0;
    private boolean flag1 = false;
    
    private HashSet<String> colorList1;
    
    private int boxW = 0;
    private int boxH = 0;
    
    private final int boxWCount = 8;  // Reduced from 12 to make boxes larger
    private final int boxHCount = (int)(boxWCount * 1.5);  // Will be 12 (reduced from 18)
    
    private Runnable onCompleteListener;
    
    public DrawView(Context context) {
        this(context, null);
    }
    
    public DrawView(Context context, AttributeSet attrs) {
        this(context, attrs, 0);
    }
    
    public DrawView(Context context, AttributeSet attrs, int defStyleAttr) {
        super(context, attrs, defStyleAttr);
        init();
    }
    
    private void init() {
        paint = new Paint();
        paint.setColor(Color.BLACK);
        paint.setStrokeWidth(2f);
        paint.setStyle(Paint.Style.STROKE);
        
        mPaint = new Paint(Paint.ANTI_ALIAS_FLAG);
        mPaint.setColor(Color.BLUE);
        mPaint.setStyle(Paint.Style.STROKE);
        mPaint.setStrokeWidth(5f);
        
        paintFill = new Paint();
        paintFill.setColor(Color.GREEN);
        paintFill.setStyle(Paint.Style.FILL);
        
        mPath = new Path();
        mPath2 = new Path();
        list1 = new ArrayList<>();
        list2 = new ArrayList<>();
        colorList1 = new HashSet<>();
    }
    
    public void setOnCompleteListener(Runnable listener) {
        onCompleteListener = listener;
    }
    
    @Override
    protected void onDraw(Canvas canvas) {
        screenW = canvas.getWidth();
        screenH = canvas.getHeight();
        
        list1.clear();
        list2.clear();
        
        canvas.drawPath(mPath, mPaint);
        canvas.drawPath(mPath2, paintFill);
        
        boxW = screenW / boxWCount;
        boxH = screenH / boxHCount;
        
        for (int i = 0; i < boxHCount; i++) {
            for (int j = 0; j <= boxWCount; j++) {
                canvas.drawRect(
                    j * boxW,
                    i * boxH,
                    (j + 1) * boxW,
                    (i + 1) * boxH,
                    paint
                );
                if (!list1.contains(j * boxW)) {
                    list1.add(j * boxW);
                }
            }
            if (!list2.contains(i * boxH)) {
                list2.add(i * boxH);
            }
        }
    }
    
    @Override
    public boolean onTouchEvent(MotionEvent event) {
        x = (int) event.getX();
        y = (int) event.getY();
        
        flag1 = false;
        
        for (int i = 0; i < list2.size(); i++) {
            for (int j = 0; j < list1.size() - 1; j++) {
                if (x > list1.get(j) && x < list1.get(j + 1) && y > list2.get(i) && y < (list2.get(i) + boxH)) {
                    a1 = list1.get(j);
                    b1 = list2.get(i);
                    flag1 = true;
                    break;
                }
            }
            if (flag1) break;
        }
        
        switch (event.getAction()) {
            case MotionEvent.ACTION_DOWN:
                mPath.moveTo(x, y);
                
                if (flag1) {
                    mPath2.addRect(
                        a1,
                        b1,
                        (a1 + boxW),
                        (b1 + boxH),
                        Path.Direction.CW
                    );
                    colorList1.add(a1 + "" + b1);
                    checkComplete();
                }
                break;
                
            case MotionEvent.ACTION_MOVE:
                mPath.lineTo(x, y);
                
                if (flag1) {
                    mPath2.addRect(
                        a1,
                        b1,
                        (a1 + boxW),
                        (b1 + boxH),
                        Path.Direction.CW
                    );
                    colorList1.add(a1 + "" + b1);
                    checkComplete();
                }
                break;
        }
        
        invalidate();
        return true;
    }
    
    private void checkComplete() {
        int totalColorBox = colorList1.size();
        int totalBoxes = boxWCount * boxHCount;
        
        if (totalColorBox >= totalBoxes) {
            // All boxes are filled - touch test is complete
            if (onCompleteListener != null) {
                onCompleteListener.run();
            }
        }
    }
    
    public void clear() {
        mPath.reset();
        mPath2.reset();
        colorList1.clear();
        invalidate();
    }
}

