import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:get/get.dart';
import 'package:slickbill/color_scheme.dart';

class InputField extends HookWidget {
  final TextEditingController controller;
  final String label;
  final IconData? icon; // ✅ Add optional icon
  final TextInputType? type; // ✅ Add optional keyboard type

  const InputField({
    super.key,
    required this.controller,
    required this.label,
    this.icon, // ✅ Optional icon
    this.type, // ✅ Optional type
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(10.0),
      child: TextFormField(
        controller: controller,
        keyboardType: type ?? TextInputType.text, // ✅ Use provided type or default to text
        onChanged: (value) {},
        decoration: InputDecoration(
          labelText: label,
          labelStyle: TextStyle(color: Theme.of(context).colorScheme.gray),
          hintStyle: TextStyle(color: Theme.of(context).colorScheme.gray),
          // ✅ Add prefix icon if provided
          prefixIcon: icon != null
              ? Icon(
                  icon,
                  color: Theme.of(context).colorScheme.blue,
                  size: 20,
                )
              : null,
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
              color: Theme.of(context).colorScheme.dark,
            ),
        textAlign: TextAlign.start,
      ),
    );
  }
}
