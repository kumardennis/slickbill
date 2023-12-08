import 'package:flutter/material.dart';
import 'package:flutter/src/widgets/framework.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:slickbill/feature_tickets/widgets/custom_ticket_paint.dart';

class CustomTicket extends HookWidget {
  const CustomTicket({super.key});

  @override
  Widget build(BuildContext context) {
    return (CustomPaint(
      painter: CustomTicketPainter(),
      size: Size(200.0, 200),
    ));
  }
}
