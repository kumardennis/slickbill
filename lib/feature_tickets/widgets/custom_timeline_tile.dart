import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:slickbill/color_scheme.dart';
import 'package:timeline_tile/timeline_tile.dart';

import 'custom_ticket.dart';

class CustomTimelineTile extends StatelessWidget {
  final String title;
  final String dateOfActivity;
  final String description;
  final String category;
  final bool isInPast;

  const CustomTimelineTile(
      {super.key,
      required this.title,
      required this.dateOfActivity,
      required this.description,
      required this.category,
      required this.isInPast});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 10.0, right: 10.0),
      child: TimelineTile(
        beforeLineStyle: LineStyle(
            color: isInPast
                ? Theme.of(context).colorScheme.gray
                : Theme.of(context).colorScheme.light),
        afterLineStyle: LineStyle(
            color: isInPast
                ? Theme.of(context).colorScheme.gray
                : Theme.of(context).colorScheme.light),
        indicatorStyle: IndicatorStyle(
            width: 30,
            color: isInPast
                ? Theme.of(context).colorScheme.gray
                : Theme.of(context).colorScheme.light),
        alignment: TimelineAlign.manual,
        lineXY: 0.18,
        startChild: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              DateFormat('dd').format(DateTime.parse(dateOfActivity)),
              style: Theme.of(context).textTheme.displayLarge?.copyWith(
                  color: isInPast
                      ? Theme.of(context).colorScheme.gray
                      : Theme.of(context).colorScheme.light),
            ),
            Text(
              DateFormat('MMM').format(DateTime.parse(dateOfActivity)),
              style: Theme.of(context).textTheme.displayMedium?.copyWith(
                  color: isInPast
                      ? Theme.of(context).colorScheme.gray
                      : Theme.of(context).colorScheme.light),
            )
          ],
        ),
        endChild: CustomTicket(
          title: title,
          description: description,
          dateOfActivity: DateTime.parse(dateOfActivity),
          category: category,
          isInPast: isInPast,
        ),
      ),
    );
  }
}
