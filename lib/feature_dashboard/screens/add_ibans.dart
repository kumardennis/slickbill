//// filepath: /Users/denniskumar/Documents/GitHub/slickbill/lib/feature_dashboard/screens/add_iban_screen.dart
import 'package:flutter/material.dart';
import 'package:get/get.dart';
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
      final client = Supabase.instance.client;
      final session = client.auth.currentSession;
      if (session == null || session.user == null) {
        Get.snackbar('Error', 'No active session, please sign in again.');
        return;
      }

      final user = _userController.user.value;
      if (user.privateUserId == null) {
        Get.snackbar('Error', 'No private user profile found.');
        return;
      }

      final privateUserId = user.privateUserId!;

      final iban = _ibanController.text.trim();
      final bankName = _bankNameController.text.trim();
      final bankAccountName = _bankAccountNameController.text.trim();

      // Load existing ibans JSON for this private user
      final existing = await client
          .from('private_users')
          .select('ibans, iban, bankAccountName')
          .eq('id', privateUserId)
          .maybeSingle();

      final List<dynamic> existingIbansJson =
          (existing?['ibans'] as List<dynamic>?) ?? [];

      // New entry with all fields
      final newEntry = {
        'iban': iban,
        'bankName': bankName, // institution
        'bankAccountName': bankAccountName, // per-account name/alias
        'isPrimary': true,
      };

      // Mark previous entries as non-primary
      for (final item in existingIbansJson) {
        if (item is Map<String, dynamic>) {
          item['isPrimary'] = false;
        }
      }
      existingIbansJson.add(newEntry);

      // Update private_users row (scalar fields follow the primary)
      await client.from('private_users').update({
        'iban': iban,
        'bankAccountName': bankAccountName,
        'ibans': existingIbansJson,
      }).eq('id', privateUserId);

      // Reload full user so Profile sees updated iban / bankAccountName
      await _authManager.loadFreshUser(
        session.user!.id,
        session.accessToken,
      );

      Get.back(); // Close screen
      Get.snackbar(
        'Success',
        'Bank account saved.',
        snackPosition: SnackPosition.TOP,
      );
    } catch (e) {
      Get.snackbar(
        'Error',
        'Failed to save bank account: $e',
        snackPosition: SnackPosition.TOP,
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
                controller: _bankNameController,
                decoration: const InputDecoration(
                  labelText: 'Bank name (e.g. LHV Bank AS)',
                ),
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? 'Required' : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _bankAccountNameController,
                decoration: const InputDecoration(
                  labelText: 'Bank account name',
                ),
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? 'Required' : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
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
