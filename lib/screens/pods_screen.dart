import 'package:flutter/cupertino.dart';
import 'package:penny_pop_app/widgets/pixel_icon.dart';
import 'package:penny_pop_app/widgets/user_menu_sheet.dart';

class PodsScreen extends StatelessWidget {
  const PodsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      navigationBar: CupertinoNavigationBar(
        middle: const Text('Pods'),
        trailing: CupertinoButton(
          padding: EdgeInsets.zero,
          onPressed: () => showUserMenuSheet(context),
          child: const PixelIcon(
            'assets/icons/ui/account.svg',
            semanticLabel: 'Account',
          ),
        ),
      ),
      child: const Center(child: Text('Pods Screen')),
    );
  }
}
