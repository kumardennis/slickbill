import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:get/get.dart';
import 'package:slickbill/color_scheme.dart';
import 'package:slickbill/feature_send/models/receiver_user_model.dart';

class InputFieldAmount extends HookWidget {
  final ReceiverUserModel receiverUser;
  final Function changeReceiverAmount;

  const InputFieldAmount(
      {super.key,
      required this.receiverUser,
      required this.changeReceiverAmount});

  @override
  Widget build(BuildContext context) {
    var amountController = useTextEditingController();

    bool isNumeric(String value) {
      return num.tryParse(value) != null;
    }

    return Padding(
      padding: const EdgeInsets.all(10.0),
      child: TextFormField(
        validator: (value) {
          if (value != null && !isNumeric(value)) {
            return 'Please enter a valid number';
          }
          return null;
        },
        keyboardType: TextInputType.number,
        controller: amountController,
        onChanged: (value) {
          changeReceiverAmount(receiverUser.id, double.parse(value));
        },
        decoration: InputDecoration(
          labelText: 'lbl_Amount'.tr,
          labelStyle: TextStyle(color: Theme.of(context).colorScheme.gray),
          hintStyle: TextStyle(color: Theme.of(context).colorScheme.gray),
          enabledBorder: const UnderlineInputBorder(
            borderSide: BorderSide(
              color: Color(0xFFE0F2F1),
              width: 1,
            ),
            borderRadius: BorderRadius.only(
              topLeft: Radius.circular(4.0),
              topRight: Radius.circular(4.0),
            ),
          ),
          focusedBorder: UnderlineInputBorder(
            borderSide: BorderSide(
              color: Theme.of(context).colorScheme.blue,
              width: 1,
            ),
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(4.0),
              topRight: Radius.circular(4.0),
            ),
          ),
        ),
        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Theme.of(context).colorScheme.light,
            ),
        textAlign: TextAlign.start,
      ),
    );
  }
}
