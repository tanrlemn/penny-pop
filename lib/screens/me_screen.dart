import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:penny_pop_app/design/glass/glass.dart';
import 'package:penny_pop_app/widgets/pixel_icon.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class MeScreen extends StatelessWidget {
  const MeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final user = Supabase.instance.client.auth.currentUser;
    final userId = user?.id ?? 'Not signed in';
    final email = user?.email ?? 'Not signed in';

    Future<void> copy(String value, String label) async {
      await Clipboard.setData(ClipboardData(text: value));
      if (!context.mounted) return;
      showGlassToast(context, '$label copied');
    }

    return CupertinoPageScaffold(
      navigationBar: const CupertinoNavigationBar(middle: Text('My info')),
      child: SafeArea(
        top: false,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            const Text(
              'Share these with your partner/admin if needed.',
              style: TextStyle(height: 1.3),
            ),
            const SizedBox(height: 16),
            CupertinoListSection.insetGrouped(
              children: [
                CupertinoListTile(
                  title: const Text('User ID'),
                  additionalInfo: Text(userId),
                  trailing: CupertinoButton(
                    padding: EdgeInsets.zero,
                    onPressed: user?.id == null ? null : () => copy(userId, 'User ID'),
                    child: const PixelIcon(
                      'assets/icons/ui/copy.svg',
                      semanticLabel: 'Copy',
                    ),
                  ),
                ),
                CupertinoListTile(
                  title: const Text('Email'),
                  additionalInfo: Text(email),
                  trailing: CupertinoButton(
                    padding: EdgeInsets.zero,
                    onPressed: user?.email == null ? null : () => copy(email, 'Email'),
                    child: const PixelIcon(
                      'assets/icons/ui/copy.svg',
                      semanticLabel: 'Copy',
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}


