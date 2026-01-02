import 'package:flutter/cupertino.dart';
import 'package:penny_pop_app/widgets/pixel_icon.dart';
import 'package:penny_pop_app/widgets/user_menu_sheet.dart';

class CoachScreen extends StatelessWidget {
  const CoachScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      navigationBar: CupertinoNavigationBar(
        middle: const Text('Guide'),
        trailing: CupertinoButton(
          padding: EdgeInsets.zero,
          onPressed: () => showUserMenuSheet(context),
          child: const PixelIcon(
            'assets/icons/ui/account.svg',
            semanticLabel: 'Account',
          ),
        ),
      ),
      child: const Center(child: Text('Guide Screen')),
    );
  }
}
