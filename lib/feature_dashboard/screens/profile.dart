import 'package:flutter/material.dart';
import 'package:flutter/src/widgets/framework.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:get/get.dart';
import 'package:slickbill/color_scheme.dart';
import 'package:slickbill/feature_auth/getx_controllers/user_controller.dart';
import 'package:slickbill/shared_widgets/custom_appbar.dart';
import 'package:slickbill/shared_widgets/input_field.dart';

class Profile extends HookWidget {
  const Profile({super.key});

  @override
  Widget build(BuildContext context) {
    UserController userController = Get.find();

    var ibanController =
        useTextEditingController(text: userController.user.value.iban);
    var bankAccNameController = useTextEditingController.fromValue(
        TextEditingValue(
            text:
                userController.user.value.bankAccountName ?? "Not set yet..."));

    return (Scaffold(
      appBar: CustomAppbar(title: 'Profile', appbarIcon: null),
      body: Container(
        width: MediaQuery.of(context).size.width,
        height: MediaQuery.of(context).size.height,
        child: Column(children: [
          SizedBox(
            height: 100,
            child: Center(
              child: Text(
                userController.user.value.fullName ??
                    userController.user.value.firstName ??
                    "No user",
                style: Theme.of(context)
                    .textTheme
                    .displayLarge
                    ?.copyWith(color: Theme.of(context).colorScheme.darkerBlue),
              ),
            ),
          ),
          SizedBox(
            height: 100,
            child: Center(
              child: Text(
                '@${userController.user.value.username}',
                style: Theme.of(context).textTheme.displayLarge?.copyWith(
                    color: Theme.of(context).colorScheme.lighterBlue),
              ),
            ),
          ),
          Center(
            child: Column(
              children: [
                InputField(
                  controller: bankAccNameController,
                  label: 'Bank Account Name',
                  obscure: false,
                  isTextDark: true,
                ),
                InputField(
                  controller: ibanController,
                  label: 'IBAN',
                  obscure: false,
                  isTextDark: true,
                ),
              ],
            ),
          )
        ]),
      ),
    ));
  }
}
