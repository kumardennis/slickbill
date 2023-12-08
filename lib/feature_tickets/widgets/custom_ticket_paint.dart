import 'dart:ui';

import 'package:flutter/material.dart';

class CustomTicketPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    // Layer 1

    Paint paint_fill_0 = Paint()
      ..color = const Color.fromARGB(255, 243, 249, 250)
      ..style = PaintingStyle.fill
      ..strokeWidth = size.width * 0.00
      ..strokeCap = StrokeCap.butt
      ..strokeJoin = StrokeJoin.miter;

    Path path_0 = Path();
    path_0.moveTo(size.width * 0.0041500, size.height * 0.1866625);
    path_0.lineTo(size.width * 1.0017250, size.height * 0.1908375);
    path_0.lineTo(size.width * 0.8742500, size.height * 0.3136500);
    path_0.lineTo(size.width * 0.7805500, size.height * 0.3181375);
    path_0.lineTo(size.width * 0.8142500, size.height * 0.3586500);
    path_0.lineTo(size.width * 0.8808250, size.height * 0.3743250);
    path_0.lineTo(size.width * 1.0028000, size.height * 0.5033375);
    path_0.lineTo(size.width * 0.0057000, size.height * 0.5005625);
    path_0.lineTo(size.width * 0.1290000, size.height * 0.3760125);
    path_0.lineTo(size.width * 0.2102750, size.height * 0.3551750);
    path_0.lineTo(size.width * 0.2736750, size.height * 0.3221375);
    path_0.lineTo(size.width * 0.1311000, size.height * 0.3130750);
    path_0.lineTo(size.width * 0.0041500, size.height * 0.1866625);
    path_0.close();

    canvas.drawPath(path_0, paint_fill_0);

    // Layer 1

    Paint paint_stroke_0 = Paint()
      ..color = const Color.fromARGB(255, 243, 249, 250)
      ..style = PaintingStyle.stroke
      ..strokeWidth = size.width * 0.02
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.bevel;

    canvas.drawPath(path_0, paint_stroke_0);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) {
    return true;
  }
}
