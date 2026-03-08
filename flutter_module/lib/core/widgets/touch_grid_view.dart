import 'package:flutter/material.dart';
import '../constants/app_colors.dart';

/// A custom widget that displays a grid and tracks which boxes are touched
class TouchGridView extends StatefulWidget {
  final int rows;
  final int columns;
  final Color backgroundColor;
  final Color borderColor;
  final Color fillColor;
  final ValueChanged<int>? onBoxesFilledChanged;
  final VoidCallback? onTouchStart;
  final VoidCallback? onTouchEnd;
  final bool enabled;
  final String? counterText;

  const TouchGridView({
    super.key,
    this.rows = 8,
    this.columns = 6,
    this.backgroundColor = Colors.white,
    this.borderColor = Colors.black,
    this.fillColor = Colors.blue,
    this.onBoxesFilledChanged,
    this.onTouchStart,
    this.onTouchEnd,
    this.enabled = true,
    this.counterText,
  });

  @override
  State<TouchGridView> createState() => TouchGridViewState();
}

class TouchGridViewState extends State<TouchGridView> {
  // Track which boxes are filled (row, column) -> filled
  final Set<String> _filledBoxes = {};
  bool _isDrawing = false;

  int get totalBoxes => widget.rows * widget.columns;
  int get filledBoxesCount => _filledBoxes.length;

  void clear() {
    setState(() {
      _filledBoxes.clear();
      _isDrawing = false;
    });
    widget.onBoxesFilledChanged?.call(0);
  }

  void _handlePanStart(DragStartDetails details, Size gridSize) {
    if (!widget.enabled) return;
    
    setState(() {
      _isDrawing = true;
    });
    
    // Notify parent that touch started (to reset timer)
    widget.onTouchStart?.call();
    
    _fillBoxAtPosition(details.localPosition, gridSize);
  }

  void _handlePanUpdate(DragUpdateDetails details, Size gridSize) {
    if (!widget.enabled || !_isDrawing) return;
    
    _fillBoxAtPosition(details.localPosition, gridSize);
  }

  void _handlePanEnd(DragEndDetails details) {
    if (!widget.enabled) return;
    
    setState(() {
      _isDrawing = false;
    });
    
    // Notify parent that touch ended (to start timer)
    widget.onTouchEnd?.call();
  }

  void _handlePanCancel() {
    if (!widget.enabled) return;
    
    setState(() {
      _isDrawing = false;
    });
    
    // Notify parent that touch ended (to start timer)
    widget.onTouchEnd?.call();
  }

  void _fillBoxAtPosition(Offset position, Size gridSize) {
    final boxWidth = gridSize.width / widget.columns;
    final boxHeight = gridSize.height / widget.rows;
    
    final column = (position.dx / boxWidth).floor().clamp(0, widget.columns - 1);
    final row = (position.dy / boxHeight).floor().clamp(0, widget.rows - 1);
    
    final boxKey = '$row,$column';
    
    if (!_filledBoxes.contains(boxKey)) {
      setState(() {
        _filledBoxes.add(boxKey);
      });
      widget.onBoxesFilledChanged?.call(_filledBoxes.length);
    }
  }

  bool isBoxFilled(int row, int column) {
    return _filledBoxes.contains('$row,$column');
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return GestureDetector(
          onPanStart: (details) => _handlePanStart(details, constraints.biggest),
          onPanUpdate: (details) => _handlePanUpdate(details, constraints.biggest),
          onPanEnd: _handlePanEnd,
          onPanCancel: _handlePanCancel,
          child: Stack(
            children: [
              // Grid background
              CustomPaint(
                painter: _GridPainter(
                  rows: widget.rows,
                  columns: widget.columns,
                  backgroundColor: widget.backgroundColor,
                  borderColor: widget.borderColor,
                  fillColor: widget.fillColor,
                  filledBoxes: _filledBoxes,
                ),
                size: constraints.biggest,
              ),
              // Counter overlay - positioned in top right, but still touchable
              if (widget.counterText != null)
                Positioned(
                  top: 16,
                  right: 16,
                  child: Text(
                    widget.counterText!,
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      color: AppColors.text,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}

class _GridPainter extends CustomPainter {
  final int rows;
  final int columns;
  final Color backgroundColor;
  final Color borderColor;
  final Color fillColor;
  final Set<String> filledBoxes;

  _GridPainter({
    required this.rows,
    required this.columns,
    required this.backgroundColor,
    required this.borderColor,
    required this.fillColor,
    required this.filledBoxes,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final boxWidth = size.width / columns;
    final boxHeight = size.height / rows;

    // Draw background
    final backgroundPaint = Paint()..color = backgroundColor;
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), backgroundPaint);

    // Draw grid and filled boxes
    final borderPaint = Paint()
      ..color = borderColor
      ..strokeWidth = 2.0
      ..style = PaintingStyle.stroke;

    final fillPaint = Paint()
      ..color = fillColor
      ..style = PaintingStyle.fill;

    for (int row = 0; row < rows; row++) {
      for (int col = 0; col < columns; col++) {
        final x = col * boxWidth;
        final y = row * boxHeight;
        final rect = Rect.fromLTWH(x, y, boxWidth, boxHeight);

        // Check if this box is filled
        final boxKey = '$row,$col';
        if (filledBoxes.contains(boxKey)) {
          // Draw filled box
          canvas.drawRect(rect, fillPaint);
        }

        // Draw border
        canvas.drawRect(rect, borderPaint);
      }
    }
  }


  @override
  bool shouldRepaint(_GridPainter oldDelegate) {
    return oldDelegate.rows != rows ||
        oldDelegate.columns != columns ||
        oldDelegate.backgroundColor != backgroundColor ||
        oldDelegate.borderColor != borderColor ||
        oldDelegate.fillColor != fillColor ||
        oldDelegate.filledBoxes != filledBoxes;
  }
}

