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
        cursorColor: Theme.of(context).colorScheme.deepNavy,
        decoration: InputDecoration(
          labelText: label,
          labelStyle: TextStyle(
            color: Theme.of(context).colorScheme.darkGray,
          ),
          hintStyle: TextStyle(color: Theme.of(context).colorScheme.gray),
        ),
        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: isTextDark == false
                  ? Theme.of(context).colorScheme.light
                  : Theme.of(context).colorScheme.dark,
            ),
        textAlign: TextAlign.start,
      ),
    );
  }
}
