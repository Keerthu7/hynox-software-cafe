import 'package:flutter/material.dart';
import 'ui.dart';

Future<void> changeAccountPassword(
  BuildContext context,
  Future<void> Function(String current, String password) save,
) async {
  await showDialog<void>(
    context: context,
    builder: (_) => _PasswordDialog(save: save),
  );
}

class _PasswordDialog extends StatefulWidget {
  final Future<void> Function(String, String) save;
  const _PasswordDialog({required this.save});
  @override
  State<_PasswordDialog> createState() => _PasswordDialogState();
}

class _PasswordDialogState extends State<_PasswordDialog> {
  final current = TextEditingController();
  final password = TextEditingController();
  final confirm = TextEditingController();
  final form = GlobalKey<FormState>();
  bool busy = false;
  String? error;
  @override
  void dispose() {
    current.dispose();
    password.dispose();
    confirm.dispose();
    super.dispose();
  }

  Future<void> submit() async {
    if (!form.currentState!.validate()) return;
    setState(() {
      busy = true;
      error = null;
    });
    try {
      await widget.save(current.text, password.text);
      if (mounted) {
        Navigator.pop(context);
        toast(context, 'Password updated.');
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          busy = false;
          error = errorText(e);
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !busy,
    child: AlertDialog(
      title: const Text('Change password'),
      content: SizedBox(
        width: 380,
        child: Form(
          key: form,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: current,
                  enabled: !busy,
                  obscureText: true,
                  decoration: const InputDecoration(
                    labelText: 'Current password',
                  ),
                  validator: (v) => v == null || v.isEmpty
                      ? 'Enter your current password'
                      : null,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: password,
                  enabled: !busy,
                  obscureText: true,
                  maxLength: 128,
                  decoration: const InputDecoration(labelText: 'New password'),
                  validator: (v) => v == null || v.length < 4
                      ? 'Use at least 4 characters'
                      : null,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: confirm,
                  enabled: !busy,
                  obscureText: true,
                  decoration: const InputDecoration(
                    labelText: 'Confirm password',
                  ),
                  validator: (v) =>
                      v != password.text ? 'Passwords do not match' : null,
                ),
                if (error != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 12),
                    child: Text(
                      error!,
                      style: const TextStyle(color: Colors.red),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: busy ? null : () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: busy ? null : submit,
          child: Text(busy ? 'Saving…' : 'Save password'),
        ),
      ],
    ),
  );
}
