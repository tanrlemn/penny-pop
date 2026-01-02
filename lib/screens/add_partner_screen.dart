import 'package:flutter/material.dart';
import 'package:penny_pop_app/app/penny_pop_scope.dart';
import 'package:penny_pop_app/households/household_service.dart';

class AddPartnerScreen extends StatefulWidget {
  const AddPartnerScreen({super.key});

  @override
  State<AddPartnerScreen> createState() => _AddPartnerScreenState();
}

class _AddPartnerScreenState extends State<AddPartnerScreen> {
  final _emailController = TextEditingController();
  bool _saving = false;
  String? _lastAddedEmail;
  String? _lastAddedUserId;

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _addPartner({
    required String householdId,
    required String email,
  }) async {
    if (_saving) return;
    setState(() => _saving = true);

    try {
      final userId = await HouseholdService().addHouseholdMemberByEmail(
        householdId: householdId,
        email: email,
      );
      if (!mounted) return;
      FocusScope.of(context).unfocus();
      _emailController.clear();
      setState(() {
        _lastAddedEmail = email;
        _lastAddedUserId = userId;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Partner added: $email')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Add partner failed: $e')),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final household = PennyPopScope.householdOf(context);
    final active = household.active;

    final role = active?.role;
    final isAdmin = role == 'admin';
    final householdId = active?.id;
    final emailText = _emailController.text.trim();
    final canSubmit = isAdmin && householdId != null && !_saving && emailText.isNotEmpty;

    return Scaffold(
      appBar: AppBar(title: const Text('Add partner')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text(
            'Your partner must sign in once first, then enter their email here.',
            style: TextStyle(height: 1.3),
          ),
          if (_lastAddedEmail != null) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primaryContainer,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Padding(
                    padding: EdgeInsets.only(top: 2),
                    child: Icon(Icons.check_circle),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      _lastAddedUserId == null
                          ? 'Added ${_lastAddedEmail!}. They may need to refresh Settings or restart the app to see the shared household.'
                          : 'Added ${_lastAddedEmail!} (user: ${_lastAddedUserId!}). They may need to refresh Settings or restart the app to see the shared household.',
                      style: const TextStyle(height: 1.3),
                    ),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 12),
          if (active == null)
            const ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text('Household not loaded yet'),
              subtitle: Text('Go back and try again in a moment.'),
            )
          else ...[
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Household'),
              subtitle: Text('${active.name}\n${active.id}'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _emailController,
              keyboardType: TextInputType.emailAddress,
              autofillHints: const [AutofillHints.email],
              onChanged: (_) => setState(() {}),
              decoration: const InputDecoration(
                labelText: 'Partner email',
                hintText: 'partner@gmail.com',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            FilledButton(
              onPressed: !canSubmit
                  ? null
                  : () => _addPartner(householdId: householdId, email: emailText),
              child: _saving
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Add partner'),
            ),
            if (!isAdmin) ...[
              const SizedBox(height: 8),
              Text(
                'Only admins can add members (your role: ${role ?? 'unknown'}).',
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurface.withValues(
                        alpha: 0.7,
                      ),
                ),
              ),
            ],
          ],
        ],
      ),
    );
  }
}


