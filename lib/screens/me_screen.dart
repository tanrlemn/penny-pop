import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$label copied')),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('My info')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text(
            'Share these with your partner/admin if needed.',
            style: TextStyle(height: 1.3),
          ),
          const SizedBox(height: 16),
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('User ID'),
            subtitle: Text(userId),
            trailing: IconButton(
              onPressed: user?.id == null ? null : () => copy(userId, 'User ID'),
              icon: const Icon(Icons.copy),
              tooltip: 'Copy',
            ),
          ),
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Email'),
            subtitle: Text(email),
            trailing: IconButton(
              onPressed: user?.email == null ? null : () => copy(email, 'Email'),
              icon: const Icon(Icons.copy),
              tooltip: 'Copy',
            ),
          ),
        ],
      ),
    );
  }
}


