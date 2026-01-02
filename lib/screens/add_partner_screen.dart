import 'package:flutter/cupertino.dart';
import 'package:penny_pop_app/app/penny_pop_scope.dart';
import 'package:penny_pop_app/design/glass/glass.dart';
import 'package:penny_pop_app/households/household_service.dart';
import 'package:penny_pop_app/widgets/pixel_icon.dart';

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
      showGlassToast(context, 'Partner added: $email');
    } catch (e) {
      if (!mounted) return;
      showGlassToast(context, 'Add partner failed: $e');
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
    final canSubmit =
        isAdmin && householdId != null && !_saving && emailText.isNotEmpty;

    return CupertinoPageScaffold(
      navigationBar: const CupertinoNavigationBar(middle: Text('Add partner')),
      child: SafeArea(
        top: false,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            const Text(
              'Your partner must sign in once first, then enter their email here.',
              style: TextStyle(height: 1.3),
            ),
            if (_lastAddedEmail != null) ...[
              const SizedBox(height: 12),
              GlassCard(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Padding(
                      padding: EdgeInsets.only(top: 2),
                      child: PixelIcon(
                        'assets/icons/ui/check_circle.svg',
                        semanticLabel: 'Success',
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        _lastAddedUserId == null
                            ? 'Added ${_lastAddedEmail!}. They may need to open Account → Account & household → Troubleshooting → Sync membership (or restart the app) to see the shared household.'
                            : 'Added ${_lastAddedEmail!} (user: ${_lastAddedUserId!}). They may need to open Account → Account & household → Troubleshooting → Sync membership (or restart the app) to see the shared household.',
                        style: const TextStyle(height: 1.3),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 12),
            if (active == null)
              const Text('Household not loaded yet. Go back and try again.')
            else ...[
              CupertinoListSection.insetGrouped(
                children: [
                  CupertinoListTile(
                    title: const Text('Household'),
                    additionalInfo: Text('${active.name}\n${active.id}'),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              GlassCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    CupertinoTextField(
                      controller: _emailController,
                      keyboardType: TextInputType.emailAddress,
                      autofillHints: const [AutofillHints.email],
                      onChanged: (_) => setState(() {}),
                      placeholder: 'partner@gmail.com',
                    ),
                    const SizedBox(height: 12),
                    CupertinoButton.filled(
                      onPressed: !canSubmit
                          ? null
                          : () => _addPartner(
                                householdId: householdId,
                                email: emailText,
                              ),
                      child: _saving
                          ? const CupertinoActivityIndicator()
                          : const Text('Add partner'),
                    ),
                    if (!isAdmin) ...[
                      const SizedBox(height: 8),
                      Text(
                        'Only admins can add members (your role: ${role ?? 'unknown'}).',
                        style: TextStyle(
                          color: CupertinoColors.secondaryLabel.resolveFrom(context),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
