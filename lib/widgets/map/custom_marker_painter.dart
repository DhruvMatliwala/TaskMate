import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../../models/task_model.dart';

class CustomMarkerPainter extends CustomPainter {
  final Color color;
  final IconData icon;
  final double size;

  const CustomMarkerPainter({
    required this.color,
    required this.icon,
    this.size = 48,
  });

  @override
  void paint(Canvas canvas, Size sz) {
    final paint = Paint()..color = color;
    final shadowPaint = Paint()
      ..color = color.withValues(alpha: 0.35)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8);

    // Shadow
    canvas.drawCircle(Offset(sz.width / 2, sz.height / 2 + 2), sz.width / 2 - 2, shadowPaint);

    // Main circle
    canvas.drawCircle(Offset(sz.width / 2, sz.height / 2), sz.width / 2 - 2, paint);

    // White border
    canvas.drawCircle(
      Offset(sz.width / 2, sz.height / 2),
      sz.width / 2 - 2,
      Paint()
        ..color = Colors.white.withValues(alpha: 0.3)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2,
    );

    // Draw icon
    final textPainter = TextPainter(textDirection: TextDirection.ltr)
      ..text = TextSpan(
        text: String.fromCharCode(icon.codePoint),
        style: TextStyle(
          fontSize: sz.width * 0.45,
          fontFamily: icon.fontFamily,
          color: Colors.white,
        ),
      );
    textPainter.layout();
    textPainter.paint(
      canvas,
      Offset(
        (sz.width - textPainter.width) / 2,
        (sz.height - textPainter.height) / 2,
      ),
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// Generate a BitmapDescriptor from a colored circle with icon
Future<BitmapDescriptor> createCustomMarker({
  required Color color,
  required IconData icon,
  double size = 96,
}) async {
  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder);
  final painter = CustomMarkerPainter(color: color, icon: icon, size: size);
  painter.paint(canvas, Size(size, size));

  final picture = recorder.endRecording();
  final img = await picture.toImage(size.toInt(), size.toInt());
  final byteData = await img.toByteData(format: ui.ImageByteFormat.png);

  return BitmapDescriptor.bytes(
    byteData!.buffer.asUint8List(),
    width: size / 2,
    height: size / 2,
  );
}

/// Get marker color for a task status
Color getMarkerColor(TaskStatus status) {
  switch (status) {
    case TaskStatus.open:
      return const Color(0xFF43E97B);
    case TaskStatus.accepted:
      return const Color(0xFFFFD700);
    case TaskStatus.inProgress:
      return const Color(0xFF6C63FF);
    case TaskStatus.completed:
      return const Color(0xFF9E9E9E);
    case TaskStatus.cancelled:
      return const Color(0xFFFF6584);
  }
}

/// Get marker icon for a task status
IconData getMarkerIcon(TaskStatus status) {
  switch (status) {
    case TaskStatus.open:
      return Icons.circle;
    case TaskStatus.accepted:
      return Icons.handshake;
    case TaskStatus.inProgress:
      return Icons.directions_run;
    case TaskStatus.completed:
      return Icons.check;
    case TaskStatus.cancelled:
      return Icons.close;
  }
}
