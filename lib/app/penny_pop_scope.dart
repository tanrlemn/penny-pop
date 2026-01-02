import 'package:flutter/widgets.dart';
import 'package:penny_pop_app/households/household_service.dart';

class PennyPopScope extends InheritedNotifier<ActiveHouseholdController> {
  const PennyPopScope({
    super.key,
    required ActiveHouseholdController household,
    required super.child,
  }) : super(notifier: household);

  static ActiveHouseholdController householdOf(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<PennyPopScope>();
    final notifier = scope?.notifier;
    if (notifier == null) {
      throw FlutterError('PennyPopScope not found in widget tree.');
    }
    return notifier;
  }
}


