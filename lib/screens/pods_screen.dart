import 'package:flutter/material.dart';
import 'package:penny_pop_app/widgets/pixel_icon.dart';
import 'package:penny_pop_app/widgets/user_menu_sheet.dart';

class PodsScreen extends StatelessWidget {
  const PodsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Pods'),
        actions: [
          IconButton(
            tooltip: 'Account',
            icon: const PixelIcon(
              'assets/icons/ui/account.svg',
              semanticLabel: 'Account',
            ),
            onPressed: () => showUserMenuSheet(context),
          ),
        ],
      ),
      body: const Center(child: Text('Pods Screen')),
    );
  }
}
