import 'package:flutter/material.dart';
import 'dart:ui' as ui;

/// A custom widget that allows drawing/dragging on the screen
/// Similar to Android DrawView, used for touch screen testing
class TouchDrawView extends StatefulWidget {
  final Color backgroundColor;
  final Color drawColor;
  final double strokeWidth;
  final ValueChanged<bool>? onTouchDetected;
  final bool enabled;

  const TouchDrawView({
    super.key,
    this.backgroundColor = Colors.white,
    this.drawColor = Colors.black,
    this.strokeWidth = 4.0,
    this.onTouchDetected,
    this.enabled = true,
  });

  @override
  State<TouchDrawView> createState() => _TouchDrawViewState();
}

class _TouchDrawViewState extends State<TouchDrawView> {
  final List<Offset> _points = [];
  final List<List<Offset>> _paths = [];
  bool _hasDrawn = false;
  bool _isDrawing = false;

  void _handlePanStart(DragStartDetails details) {
    if (!widget.enabled) return;
    
    setState(() {
      _isDrawing = true;
      _points.clear();
      _points.add(details.localPosition);
    });
  }

  void _handlePanUpdate(DragUpdateDetails details) {
    if (!widget.enabled || !_isDrawing) return;
    
    setState(() {
      _points.add(details.localPosition);
      _hasDrawn = true;
      
      // Notify parent that touch is detected
      if (_points.length > 5 && widget.onTouchDetected != null) {
        widget.onTouchDetected?.call(true);
      }
    });
  }

  void _handlePanEnd(DragEndDetails details) {
    if (!widget.enabled) return;
    
    setState(() {
      if (_points.isNotEmpty) {
        _paths.add(List.from(_points));
        _points.clear();
      }
      _isDrawing = false;
    });
  }

  void _handlePanCancel() {
    if (!widget.enabled) return;
    
    setState(() {
      _points.clear();
      _isDrawing = false;
    });
  }

  void clear() {
    setState(() {
      _points.clear();
      _paths.clear();
      _hasDrawn = false;
      _isDrawing = false;
    });
  }

  bool get hasDrawn => _hasDrawn;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onPanStart: _handlePanStart,
      onPanUpdate: _handlePanUpdate,
      onPanEnd: _handlePanEnd,
      onPanCancel: _handlePanCancel,
      child: CustomPaint(
        painter: _TouchDrawPainter(
          points: _points,
          paths: _paths,
          drawColor: widget.drawColor,
          strokeWidth: widget.strokeWidth,
        ),
        child: Container(
          color: widget.backgroundColor,
        ),
      ),
    );
  }
}

class _TouchDrawPainter extends CustomPainter {
  final List<Offset> points;
  final List<List<Offset>> paths;
  final Color drawColor;
  final double strokeWidth;

  _TouchDrawPainter({
    required this.points,
    required this.paths,
    required this.drawColor,
    required this.strokeWidth,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = drawColor
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..style = PaintingStyle.stroke;

    // Draw all completed paths
    for (final path in paths) {
      if (path.length > 1) {
        final pathToDraw = ui.Path();
        pathToDraw.moveTo(path[0].dx, path[0].dy);
        for (int i = 1; i < path.length; i++) {
          pathToDraw.lineTo(path[i].dx, path[i].dy);
        }
        canvas.drawPath(pathToDraw, paint);
      }
    }

    // Draw current path being drawn
    if (points.length > 1) {
      final currentPath = ui.Path();
      currentPath.moveTo(points[0].dx, points[0].dy);
      for (int i = 1; i < points.length; i++) {
        currentPath.lineTo(points[i].dx, points[i].dy);
      }
      canvas.drawPath(currentPath, paint);
    }
  }

  @override
  bool shouldRepaint(_TouchDrawPainter oldDelegate) {
    return oldDelegate.points != points || oldDelegate.paths != paths;
  }
}

