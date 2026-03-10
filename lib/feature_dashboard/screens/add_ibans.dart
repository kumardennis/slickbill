//// filepath: /Users/denniskumar/Documents/GitHub/slickbill/lib/feature_dashboard/screens/add_iban_screen.dart
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:slickbill/color_scheme.dart';
import 'package:slickbill/feature_auth/getx_controllers/user_controller.dart';
import 'package:slickbill/feature_auth/utils/supabase_auth_manger.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class AddIbanScreen extends StatefulWidget {
  const AddIbanScreen({super.key});

  @override
  State<AddIbanScreen> createState() => _AddIbanScreenState();
}

class _AddIbanScreenState extends State<AddIbanScreen> {
  final _ibanController = TextEditingController();
  final _bankNameController = TextEditingController(); // institution
  final _bankAccountNameController = TextEditingController(); // account name
  final _formKey = GlobalKey<FormState>();
  bool _isSubmitting = false;

  final _userController = Get.find<UserController>();
  final _authManager = SupabaseAuthManger();

  @override
  void dispose() {
    _ibanController.dispose();
    _bankNameController.dispose();
    _bankAccountNameController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSubmitting = true);

    try {
      final user = Supabase.instance.client.auth.currentUser;
      if (user == null) throw Exception('Not authenticated');

      await Supabase.instance.client.from('banks').insert({
        'user_id': user.id,
        'iban': _ibanController.text.trim(),
        'account_holder': _bankAccountNameController.text.trim(),
        'created_at': DateTime.now().toIso8601String(),
      });

      if (!mounted) return;

      Get.snackbar(
        'Success',
        'Bank account added successfully',
        backgroundColor: Colors.green.withOpacity(0.1),
        colorText: Colors.green,
      );

      // ✅ Return true to trigger refresh
      Get.back(result: true);
    } catch (e) {
      if (!mounted) return;

      Get.snackbar(
        'Error',
        'Failed to add bank account: ${e.toString()}',
        backgroundColor: Theme.of(context).colorScheme.red,
        colorText: Colors.white,
      );
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Add bank account / IBAN'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              TextFormField(
                style: TextStyle(
                  color: Theme.of(context).colorScheme.dark,
                ),
                controller: _bankNameController,
                decoration: const InputDecoration(
                  labelText: 'Bank name (e.g. LHV Bank AS)',
                ),
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? 'Required' : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                style: TextStyle(
                  color: Theme.of(context).colorScheme.dark,
                ),
                controller: _bankAccountNameController,
                decoration: const InputDecoration(
                  labelText: 'Bank account name',
                ),
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? 'Required' : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                style: TextStyle(
                  color: Theme.of(context).colorScheme.dark,
                ),
                controller: _ibanController,
                decoration: const InputDecoration(
                  labelText: 'IBAN',
                ),
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? 'Required' : null,
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isSubmitting ? null : _submit,
                  child: _isSubmitting
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Save'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
