import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:get/get.dart';
import 'package:slickbill/color_scheme.dart';

class InputField extends HookWidget {
  final TextEditingController controller;

  final String label;
  final bool obscure;
  final bool? isTextDark;

  const InputField(
      {super.key,
      required this.controller,
      required this.label,
      required this.obscure,
      this.isTextDark});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(10.0),
      child: TextFormField(
        obscureText: obscure,
        controller: controller,
        onChanged: (value) {},
        decoration: InputDecoration(
          labelText: label,
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
              color: isTextDark != null && isTextDark!
                  ? Theme.of(context).colorScheme.dark
                  : Theme.of(context).colorScheme.light,
            ),
        textAlign: TextAlign.start,
      ),
    );
  }
}
