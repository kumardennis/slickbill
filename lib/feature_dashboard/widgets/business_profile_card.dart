import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:get/get.dart';
import 'package:slickbill/color_scheme.dart';
import 'package:slickbill/feature_auth/getx_controllers/user_controller.dart';

class BusinessProfileCard extends HookWidget {
  const BusinessProfileCard({super.key});

  @override
  Widget build(BuildContext context) {
    final userController = Get.find<UserController>();
    final publicNameController = useTextEditingController(
      text: userController.user.value.publicName ?? '',
    );
    final isSaving = useState(false);

    Future<void> save({
      required bool isBusiness,
      String? publicName,
    }) async {
      if (isSaving.value) return;
      isSaving.value = true;
      final saved = await userController.updateBusinessProfile(
        isBusiness: isBusiness,
        publicName: publicName,
      );
      isSaving.value = false;

      if (!context.mounted) return;
      Get.snackbar(
        saved ? 'Saved' : 'Oops..',
        saved ? 'inf_BusinessProfileSaved'.tr : 'inf_BusinessProfileSaveFailed'.tr,
        backgroundColor: saved
            ? Colors.green.withOpacity(0.1)
            : Theme.of(context).colorScheme.red,
        colorText: saved ? Colors.green : Colors.white,
      );
    }

    return Obx(() {
      final user = userController.user.value;
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(20),
        margin: const EdgeInsets.fromLTRB(20, 0, 20, 20),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.light,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(
                'lbl_UseAsBusiness'.tr,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: Theme.of(context).colorScheme.dark,
                      fontWeight: FontWeight.w600,
                    ),
              ),
              subtitle: Text(
                'lbl_UseAsBusinessHint'.tr,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.gray,
                    ),
              ),
              value: user.isBusiness,
              activeThumbColor: Theme.of(context).colorScheme.blue,
              onChanged: isSaving.value
                  ? null
                  : (value) async {
                      var name = publicNameController.text.trim();
                      if (value && name.isEmpty) {
                        name = [
                          user.firstName,
                          user.lastName,
                        ]
                            .whereType<String>()
                            .map((part) => part.trim())
                            .where((part) => part.isNotEmpty)
                            .join(' ');
                        publicNameController.text = name;
                      }
                      await save(
                        isBusiness: value,
                        publicName: name.isEmpty ? user.publicName : name,
                      );
                    },
            ),
            if (user.isBusiness) ...[
              const SizedBox(height: 8),
              TextField(
                controller: publicNameController,
                textCapitalization: TextCapitalization.words,
                enabled: !isSaving.value,
                cursorColor: Theme.of(context).colorScheme.blue,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Theme.of(context).colorScheme.dark,
                    ),
                decoration: InputDecoration(
                  labelText: 'lbl_PublicName'.tr,
                  hintText: 'lbl_PublicNameHint'.tr,
                  labelStyle: TextStyle(
                    color: Theme.of(context).colorScheme.gray,
                  ),
                  hintStyle: TextStyle(
                    color: Theme.of(context).colorScheme.gray,
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(
                      color: Theme.of(context).colorScheme.lightGray,
                    ),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(
                      color: Theme.of(context).colorScheme.blue,
                    ),
                  ),
                ),
                onSubmitted: (value) => save(
                  isBusiness: true,
                  publicName: value,
                ),
              ),
              const SizedBox(height: 8),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: isSaving.value
                      ? null
                      : () => save(
                            isBusiness: true,
                            publicName: publicNameController.text,
                          ),
                  child: Text('btn_Save'.tr),
                ),
              ),
            ],
          ],
        ),
      );
    });
  }
}
