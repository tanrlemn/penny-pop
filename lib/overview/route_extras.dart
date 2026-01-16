enum PodsFocusFilter {
  missingBudget,
  uncategorized,
}

class PodsFocusTarget {
  const PodsFocusTarget({
    this.filter,
    this.podId,
    this.sectionTitle,
  });

  final PodsFocusFilter? filter;
  final String? podId;
  final String? sectionTitle;
}

class PodsScreenArgs {
  const PodsScreenArgs({
    this.focusTarget,
  });

  final PodsFocusTarget? focusTarget;
}

class ChatScreenArgs {
  const ChatScreenArgs({
    this.initialPrompt,
  });

  final String? initialPrompt;
}

