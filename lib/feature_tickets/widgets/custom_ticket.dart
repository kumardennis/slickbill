import 'package:flutter/material.dart';
import 'package:flutter/src/widgets/framework.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:intl/intl.dart';
import 'package:slickbill/color_scheme.dart';
// import 'package:ticket_widget/ticket_widget.dart';

class CustomTicket extends HookWidget {
  final String title;
  final DateTime dateOfActivity;
  final String description;
  final String category;
  final bool isInPast;

  const CustomTicket(
      {super.key,
      required this.title,
      required this.dateOfActivity,
      required this.description,
      required this.category,
      required this.isInPast});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(20.0),
      // child: (TicketWidget(
      //   width: MediaQuery.of(context).size.width - 100,
      //   height: 250,
      //   isCornerRounded: true,
      //   padding: const EdgeInsets.all(20),
      //   color: isInPast
      //       ? Theme.of(context).colorScheme.gray
      //       : Theme.of(context).colorScheme.light,
      //   child: Padding(
      //     padding: const EdgeInsets.only(left: 8.0),
      //     child: Column(
      //       mainAxisAlignment: MainAxisAlignment.spaceBetween,
      //       crossAxisAlignment: CrossAxisAlignment.start,
      //       children: [
      //         Row(
      //           mainAxisAlignment: MainAxisAlignment.spaceBetween,
      //           crossAxisAlignment: CrossAxisAlignment.start,
      //           children: [
      //             Flexible(
      //               child: Padding(
      //                 padding: const EdgeInsets.only(right: 8.0),
      //                 child: Column(
      //                   mainAxisAlignment: MainAxisAlignment.start,
      //                   crossAxisAlignment: CrossAxisAlignment.start,
      //                   children: [
      //                     Text(
      //                       title,
      //                       style: Theme.of(context)
      //                           .textTheme
      //                           .headlineMedium
      //                           ?.copyWith(
      //                               color: Theme.of(context).colorScheme.dark),
      //                     ),
      //                     Text(
      //                       DateFormat('EEE, dd MMM').format(dateOfActivity),
      //                       style: Theme.of(context)
      //                           .textTheme
      //                           .bodySmall
      //                           ?.copyWith(
      //                               color: Theme.of(context).colorScheme.dark),
      //                     ),
      //                   ],
      //                 ),
      //               ),
      //             ),
      //             const FaIcon(FontAwesomeIcons.qrcode)
      //           ],
      //         ),
      //         Padding(
      //           padding: const EdgeInsets.only(top: 15.0, bottom: 15.0),
      //           child: Text(
      //             description,
      //             style: Theme.of(context)
      //                 .textTheme
      //                 .bodyMedium
      //                 ?.copyWith(color: Theme.of(context).colorScheme.dark),
      //           ),
      //         ),
      //         Align(
      //           alignment: Alignment.centerRight,
      //           child: Text(
      //             category,
      //             style: Theme.of(context)
      //                 .textTheme
      //                 .bodySmall
      //                 ?.copyWith(color: Theme.of(context).colorScheme.dark),
      //           ),
      //         ),
      //       ],
      //     ),
      //   ),
      // )),
    );
  }
}
