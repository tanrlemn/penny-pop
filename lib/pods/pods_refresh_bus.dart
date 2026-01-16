import 'dart:async';

class PodsRefreshBus {
  PodsRefreshBus._();

  static final PodsRefreshBus instance = PodsRefreshBus._();

  final StreamController<String?> _controller =
      StreamController<String?>.broadcast();

  Stream<String?> get stream => _controller.stream;

  void requestRefresh({String? reason}) {
    _controller.add(reason);
  }
}
