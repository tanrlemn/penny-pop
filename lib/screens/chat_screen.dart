import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:penny_pop_app/app/penny_pop_scope.dart';
import 'package:penny_pop_app/api/api_errors.dart';
import 'package:penny_pop_app/api/api_models.dart';
import 'package:penny_pop_app/chat/chat_models.dart';
import 'package:penny_pop_app/chat/chat_service.dart';
import 'package:penny_pop_app/design/glass/glass.dart';
import 'package:penny_pop_app/pods/pods_refresh_bus.dart';
import 'package:penny_pop_app/widgets/pixel_icon.dart';
import 'package:penny_pop_app/widgets/user_menu_sheet.dart';
import 'package:share_plus/share_plus.dart';

class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key, this.initialPrompt});

  final String? initialPrompt;

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final ChatService _service = ChatService();
  final List<ChatItem> _items = [];

  final TextEditingController _messageController = TextEditingController();
  final FocusNode _messageFocus = FocusNode();
  final ScrollController _scrollController = ScrollController();

  String? _lastHouseholdId;
  bool _sending = false;
  String? _applyingActionId;

  static const double _nearBottomThresholdPx = 140;
  bool _isNearBottom = true;

  static const bool _debugShowEntityChips = kDebugMode;

  final Map<String, String> _selectedRepairGroupActionIds = {};
  final Set<String> _dismissedRepairGroups = {};

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_handleScroll);
    _applyInitialPrompt();
  }

  @override
  void didUpdateWidget(covariant ChatScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.initialPrompt != oldWidget.initialPrompt) {
      _applyInitialPrompt(force: true);
    }
  }

  @override
  void dispose() {
    _scrollController.removeListener(_handleScroll);
    _messageController.dispose();
    _messageFocus.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final householdId = PennyPopScope.householdOf(context).active?.id;
    if (householdId != _lastHouseholdId) {
      _lastHouseholdId = householdId;
      setState(() {
        _items.clear();
      });
    }
  }

  void _applyInitialPrompt({bool force = false}) {
    final prompt = widget.initialPrompt?.trim();
    if (prompt == null || prompt.isEmpty) return;
    if (!force && _messageController.text.trim().isNotEmpty) return;

    _messageController.text = prompt;
    _messageController.selection = TextSelection.collapsed(offset: prompt.length);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _messageFocus.requestFocus();
      _scrollToBottom(force: true);
    });
  }

  Future<void> _sendMessage() async {
    if (_sending) return;
    final householdId = PennyPopScope.householdOf(context).active?.id;
    if (householdId == null) return;

    final message = _messageController.text.trim();
    if (message.isEmpty) return;
    if (message.length > kMaxMessageChars) {
      showGlassToast(context, 'Message is too long (max 500 chars).');
      return;
    }

    final localMessageId = DateTime.now().microsecondsSinceEpoch.toString();
    final typingId = 'typing_$localMessageId';
    setState(() {
      _sending = true;
      _items.add(
        ChatItem.user(
          id: localMessageId,
          text: message,
          status: ChatMessageStatus.sending,
        ),
      );
      _items.add(ChatItem.typing(id: typingId));
    });
    _messageController.clear();
    _scrollToBottom(force: true);

    try {
      final response = await _service.postMessage(
        householdId: householdId,
        messageText: message,
      );
      debugPrint(
        'Chat message ok: traceId=${response.traceId} actions=${response.proposedActions.length}',
      );
      // TEMP DEBUG (remove later): backend debug + assistantText
      debugPrint('Chat response assistantText: ${response.assistantText}');
      debugPrint('Chat response debug: ${response.debug}');
      final debug = response.debug;
      if (debug != null) {
        debugPrint('Chat response debug.aiEnabled: ${debug['aiEnabled']}');
        debugPrint('Chat response debug.aiAttempted: ${debug['aiAttempted']}');
        debugPrint('Chat response debug.aiSucceeded: ${debug['aiSucceeded']}');
        debugPrint(
          'Chat response debug.aiFailureStage: ${debug['aiFailureStage']}',
        );
        debugPrint('Chat response debug.modeChosen: ${debug['modeChosen']}');
        debugPrint(
          'Chat response debug.aiErrorMessage: ${debug['aiErrorMessage']}',
        );
      }
      final mapped = _mapResponseToChatItem(response);

      if (!mounted) return;
      setState(() {
        _updateMessageStatus(localMessageId, ChatMessageStatus.sent);
        _removeItemById(typingId);
        _items.add(mapped);
      });
      _scrollToBottom();
    } catch (e) {
      final traceId = (e is ApiException) ? e.traceId : null;
      debugPrint('Chat message failed: traceId=$traceId error=$e');
      if (!mounted) return;
      setState(() {
        _updateMessageStatus(localMessageId, ChatMessageStatus.failed);
        _removeItemById(typingId);
      });
      _showChatErrorToast(e);
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  Future<void> _sendCannedMessage() async {
    if (_sending) return;
    _messageController.text = 'I moved \$220 from Moving Fund to Health';
    await _sendMessage();
  }

  void _updateMessageStatus(String id, ChatMessageStatus status) {
    for (var i = 0; i < _items.length; i++) {
      final item = _items[i];
      if (item.id == id) {
        _items[i] = item.copyWith(status: status);
        return;
      }
    }
  }

  void _removeItemById(String id) {
    _items.removeWhere((e) => e.id == id);
  }

  Future<void> _retryMessage(ChatItem item) async {
    if (_sending) return;
    final householdId = PennyPopScope.householdOf(context).active?.id;
    if (householdId == null) return;
    if (item.kind != ChatItemKind.userMessage) return;
    if (item.status != ChatMessageStatus.failed) return;

    final message = item.text.trim();
    if (message.isEmpty) return;
    if (message.length > kMaxMessageChars) {
      showGlassToast(context, 'Message is too long (max 500 chars).');
      return;
    }

    final typingId = 'typing_${item.id}';
    setState(() {
      _sending = true;
      _updateMessageStatus(item.id, ChatMessageStatus.sending);
      _removeItemById(typingId);
      _items.add(ChatItem.typing(id: typingId));
    });
    _scrollToBottom(force: true);

    try {
      final response = await _service.postMessage(
        householdId: householdId,
        messageText: message,
      );
      debugPrint(
        'Chat retry ok: traceId=${response.traceId} actions=${response.proposedActions.length}',
      );
      // TEMP DEBUG (remove later): backend debug + assistantText
      debugPrint('Chat response assistantText: ${response.assistantText}');
      debugPrint('Chat response debug: ${response.debug}');
      final debug = response.debug;
      if (debug != null) {
        debugPrint('Chat response debug.aiEnabled: ${debug['aiEnabled']}');
        debugPrint('Chat response debug.aiAttempted: ${debug['aiAttempted']}');
        debugPrint('Chat response debug.aiSucceeded: ${debug['aiSucceeded']}');
        debugPrint(
          'Chat response debug.aiFailureStage: ${debug['aiFailureStage']}',
        );
        debugPrint('Chat response debug.modeChosen: ${debug['modeChosen']}');
        debugPrint(
          'Chat response debug.aiErrorMessage: ${debug['aiErrorMessage']}',
        );
      }
      final mapped = _mapResponseToChatItem(response);

      if (!mounted) return;
      setState(() {
        _updateMessageStatus(item.id, ChatMessageStatus.sent);
        _removeItemById(typingId);
        _items.add(mapped);
      });
      _scrollToBottom();
    } catch (e) {
      final traceId = (e is ApiException) ? e.traceId : null;
      debugPrint('Chat retry failed: traceId=$traceId error=$e');
      if (!mounted) return;
      setState(() {
        _updateMessageStatus(item.id, ChatMessageStatus.failed);
        _removeItemById(typingId);
      });
      _showChatErrorToast(e);
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  Future<void> _applyAction(ProposedAction action) async {
    if (_applyingActionId != null) return;
    final householdId = PennyPopScope.householdOf(context).active?.id;
    if (householdId == null) return;

    setState(() => _applyingActionId = action.id);
    try {
      debugPrint(
        'Apply request: household=$householdId actionCount=1 actionId=${action.id}',
      );
      final response = await _service.applyActions(
        householdId: householdId,
        actionIds: [action.id],
      );
      debugPrint(
        'Chat apply ok: traceId=${response.traceId} applied=${response.appliedActionIds.length}',
      );
      if (!response.verifiedApplied(action.id)) {
        throw ApiParseException(
          traceId: response.traceId,
          message: 'Apply response missing applied action id',
        );
      }

      if (!mounted) return;
      _setActionStatus(action.id, ActionStatus.applied);
      setState(() {
        _items.add(ChatItem.assistant('✅ Updated budgets.'));
        final summary = _formatApplyChangesSummary(response.changes);
        if (summary != null) {
          _items.add(ChatItem.assistant(summary));
        }
        _applyingActionId = null;
      });
      _scrollToBottom();
      _triggerPodsRefresh();
    } catch (e) {
      final traceId = (e is ApiException) ? e.traceId : null;
      debugPrint('Chat apply failed: traceId=$traceId error=$e');
      if (!mounted) return;
      _showChatErrorToast(e);
      setState(() => _applyingActionId = null);
      _scrollToBottom();
    }
  }

  Future<void> _applyRepairGroup({
    required String selectedActionId,
    required List<String> groupActionIds,
  }) async {
    if (_applyingActionId != null) return;
    final householdId = PennyPopScope.householdOf(context).active?.id;
    if (householdId == null) return;

    setState(() => _applyingActionId = selectedActionId);
    try {
      debugPrint(
        'Apply request: household=$householdId actionCount=1 actionId=$selectedActionId (repair group)',
      );
      final response = await _service.applyActions(
        householdId: householdId,
        actionIds: [selectedActionId],
      );
      debugPrint(
        'Chat apply ok: traceId=${response.traceId} applied=${response.appliedActionIds.length}',
      );
      if (!response.verifiedApplied(selectedActionId)) {
        throw ApiParseException(
          traceId: response.traceId,
          message: 'Apply response missing applied action id',
        );
      }

      if (!mounted) return;
      _setActionsStatus(groupActionIds, ActionStatus.applied);
      setState(() {
        _items.add(ChatItem.assistant('✅ Updated budgets.'));
        final summary = _formatApplyChangesSummary(response.changes);
        if (summary != null) {
          _items.add(ChatItem.assistant(summary));
        }
        _applyingActionId = null;
      });
      _scrollToBottom();
      _triggerPodsRefresh();
    } catch (e) {
      final traceId = (e is ApiException) ? e.traceId : null;
      debugPrint('Chat apply failed: traceId=$traceId error=$e');
      if (!mounted) return;
      _showChatErrorToast(e);
      setState(() => _applyingActionId = null);
      _scrollToBottom();
    }
  }

  void _triggerPodsRefresh() {
    debugPrint('Refreshing pods from DB after apply...');
    PodsRefreshBus.instance.requestRefresh(reason: 'apply');
  }

  void _showChatErrorToast(Object e) {
    String? traceId;
    if (e is ApiException) traceId = e.traceId;

    if (e is ApiRateLimitedException) {
      final n = e.retryAfterSeconds;
      if (n != null) {
        showGlassToast(context, 'Too many requests. Try again in ${n}s.');
      } else {
        showGlassToast(context, 'Too many requests. Try again soon.');
      }
      _maybeShowCopyTraceId(traceId);
      return;
    }

    if (e is TimeoutException) {
      showGlassToast(context, 'Network timeout. Try again.');
      _maybeShowCopyTraceId(traceId);
      return;
    }

    if (e is ApiParseException) {
      showGlassToast(context, 'Server response error. Try again.');
      _maybeShowCopyTraceId(traceId);
      return;
    }

    showGlassToast(context, 'Something went wrong. Try again.');
    _maybeShowCopyTraceId(traceId);
  }

  void _maybeShowCopyTraceId(String? traceId) {
    if (!kDebugMode) return;
    final id = traceId?.trim();
    if (id == null || id.isEmpty) return;
    if (!mounted) return;
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      await showCupertinoModalPopup<void>(
        context: context,
        builder: (sheetContext) => CupertinoActionSheet(
          title: const Text('Debug'),
          message: Text('traceId: $id'),
          actions: [
            CupertinoActionSheetAction(
              onPressed: () {
                Navigator.of(sheetContext).pop();
                Clipboard.setData(ClipboardData(text: id));
                showGlassToast(context, 'Trace id copied');
              },
              child: const Text('Copy trace id'),
            ),
          ],
          cancelButton: CupertinoActionSheetAction(
            isDefaultAction: true,
            onPressed: () => Navigator.of(sheetContext).pop(),
            child: const Text('Cancel'),
          ),
        ),
      );
    });
  }

  void _scrollToBottom({bool force = false}) {
    if (!force && !_isNearBottom) return;
    if (!_scrollController.hasClients) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollController.hasClients) return;
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOutCubic,
      );
    });
  }

  void _handleScroll() {
    if (!_scrollController.hasClients) return;
    final pos = _scrollController.position;
    final distanceFromBottom = pos.maxScrollExtent - pos.pixels;
    final nextIsNearBottom = distanceFromBottom <= _nearBottomThresholdPx;
    if (nextIsNearBottom == _isNearBottom) return;
    setState(() => _isNearBottom = nextIsNearBottom);
  }

  Future<void> _showMessageActions(ChatItem item) async {
    final text = item.text.trim();
    if (text.isEmpty && item.kind != ChatItemKind.userMessage) return;
    await showCupertinoModalPopup<void>(
      context: context,
      builder: (sheetContext) {
        final isRetryable =
            item.kind == ChatItemKind.userMessage && item.status == ChatMessageStatus.failed;
        return CupertinoActionSheet(
          actions: [
            if (isRetryable)
              CupertinoActionSheetAction(
                onPressed: () {
                  Navigator.of(sheetContext).pop();
                  _retryMessage(item);
                },
                child: const Text('Retry'),
              ),
            CupertinoActionSheetAction(
              onPressed: () {
                Navigator.of(sheetContext).pop();
                Clipboard.setData(ClipboardData(text: text));
                showGlassToast(context, 'Copied');
              },
              child: const Text('Copy'),
            ),
            CupertinoActionSheetAction(
              onPressed: () {
                Navigator.of(sheetContext).pop();
                SharePlus.instance.share(
                  ShareParams(text: text),
                );
              },
              child: const Text('Share'),
            ),
            if (item.kind == ChatItemKind.userMessage)
              CupertinoActionSheetAction(
                onPressed: () {
                  Navigator.of(sheetContext).pop();
                  _messageController.text = text;
                  _messageController.selection =
                      TextSelection.collapsed(offset: text.length);
                  _messageFocus.requestFocus();
                  _scrollToBottom(force: true);
                },
                child: const Text('Edit draft'),
              ),
          ],
          cancelButton: CupertinoActionSheetAction(
            isDefaultAction: true,
            onPressed: () => Navigator.of(sheetContext).pop(),
            child: const Text('Cancel'),
          ),
        );
      },
    );
  }

  void _insertCandidate(
    String candidate, {
    required CandidateInsertMode mode,
  }) {
    final trimmed = _messageController.text.trim();
    final insertion = switch (mode) {
      CandidateInsertMode.plain => candidate,
      CandidateInsertMode.from => 'from $candidate',
      CandidateInsertMode.to => 'to $candidate',
    };
    final next = trimmed.isEmpty ? insertion : '$trimmed $insertion';
    _messageController.text = next;
    _messageController.selection = TextSelection.collapsed(offset: next.length);
    _messageFocus.requestFocus();
  }

  ChatItem _mapResponseToChatItem(ChatApiResponse response) {
    final actions = _resolveActions(response.proposedActions);
    final clarification = (_debugShowEntityChips && actions.isEmpty)
        ? _resolveClarification(response.entities)
        : null;
    return ChatItem.assistant(
      response.assistantText,
      actions: actions,
      warnings: response.warnings,
      clarification: clarification,
    );
  }

  List<ProposedAction> _resolveActions(List<ProposedActionDto> dtos) {
    final actions = <ProposedAction>[];
    for (var i = 0; i < dtos.length; i++) {
      final dto = dtos[i];
      actions.add(
        ProposedAction.fromJson(
          <String, dynamic>{
            'id': dto.id,
            'type': dto.type,
            'status': dto.status,
            'payload': dto.payload,
            'title': dto.title,
            'summary': dto.summary,
            'confidence': dto.confidence,
          },
          fallbackId: 'action_$i',
        ),
      );
    }
    return actions;
  }

  ChatClarification? _resolveClarification(Map<String, dynamic>? entities) {
    if (entities == null) return null;
    final fromCandidate = entities['fromCandidate']?.toString().trim();
    final toCandidate = entities['toCandidate']?.toString().trim();

    final rawCandidates = entities['candidates'];
    final candidates = (rawCandidates is List)
        ? rawCandidates
            .map((e) => e.toString().trim())
            .where((e) => e.isNotEmpty)
            .toList()
        : const <String>[];

    // Key rule: never show chips by default. Only show when the backend has
    // partial intent (from/to candidate) but is missing the other side.
    final hasPartialIntent =
        (fromCandidate != null && fromCandidate.isNotEmpty) ||
        (toCandidate != null && toCandidate.isNotEmpty);
    if (!hasPartialIntent) return null;
    if (candidates.isEmpty) return null;

    final hasFrom = fromCandidate != null && fromCandidate.isNotEmpty;
    final hasTo = toCandidate != null && toCandidate.isNotEmpty;

    if (!hasFrom && hasTo) {
      return ChatClarification(
        prompt: 'Pick the source',
        insertMode: CandidateInsertMode.from,
        choices: candidates,
      );
    }
    if (hasFrom && !hasTo) {
      return ChatClarification(
        prompt: 'Pick the destination',
        insertMode: CandidateInsertMode.to,
        choices: candidates,
      );
    }
    return null;
  }

  String _formatDollarsFromCents(int cents) {
    final abs = cents.abs();
    final dollars = abs ~/ 100;
    final remainder = abs % 100;
    final amount = remainder == 0
        ? '\$$dollars'
        : '\$$dollars.${remainder.toString().padLeft(2, '0')}';
    return cents < 0 ? '-$amount' : amount;
  }

  String? _formatApplyChangesSummary(List<ChangeDto>? changes) {
    if (changes == null || changes.isEmpty) return null;
    final parts = <String>[];
    for (final c in changes) {
      final sign = c.deltaInCents < 0 ? '−' : '+';
      final amt = _formatDollarsFromCents(c.deltaInCents.abs());
      parts.add('${c.podName} $sign$amt');
      if (parts.length >= 4) break;
    }
    final text = 'Updated budgets: ${parts.join(', ')}';
    return _truncateOneLine(text, 110);
  }

  String _truncateOneLine(String text, int maxChars) {
    final s = text.replaceAll(RegExp(r'\s+'), ' ').trim();
    if (s.length <= maxChars) return s;
    return '${s.substring(0, maxChars)}…';
  }

  String? _confidenceLabel(double? confidence) {
    if (confidence == null) return null;
    final c = confidence.clamp(0.0, 1.0);
    if (c >= 0.75) return 'High';
    if (c >= 0.45) return 'Med';
    return 'Low';
  }

  void _setActionStatus(String actionId, ActionStatus status) {
    setState(() {
      for (var i = 0; i < _items.length; i++) {
        final item = _items[i];
        if (item.actions.any((a) => a.id == actionId)) {
          _items[i] = item.copyWith(
            actions: item.actions
                .map((a) => a.id == actionId ? a.copyWith(status: status) : a)
                .toList(),
          );
        }
      }
    });
  }

  void _setActionsStatus(List<String> actionIds, ActionStatus status) {
    final idSet = actionIds.toSet();
    setState(() {
      for (var i = 0; i < _items.length; i++) {
        final item = _items[i];
        if (item.actions.any((a) => idSet.contains(a.id))) {
          _items[i] = item.copyWith(
            actions: item.actions
                .map((a) => idSet.contains(a.id) ? a.copyWith(status: status) : a)
                .toList(),
          );
        }
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final primaryText = CupertinoColors.label.resolveFrom(context);
    final secondaryText = CupertinoColors.secondaryLabel.resolveFrom(context);
    final dividerColor = CupertinoColors.separator.resolveFrom(context);

    final isApplying = _applyingActionId != null;
    final isShowingJumpToBottom = !_isNearBottom && _items.isNotEmpty;

    return CupertinoPageScaffold(
      navigationBar: CupertinoNavigationBar(
        middle: const Text('Chat'),
        leading: CupertinoButton(
          padding: EdgeInsets.zero,
          onPressed: () {
            if (context.canPop()) {
              context.pop();
            } else {
              context.go('/');
            }
          },
          child: const Icon(CupertinoIcons.back, size: 20),
        ),
        trailing: CupertinoButton(
          padding: EdgeInsets.zero,
          onPressed: () => showUserMenuSheet(context),
          child: const PixelIcon(
            'assets/icons/ui/account.svg',
            semanticLabel: 'Account',
          ),
        ),
      ),
      child: SafeArea(
        child: GestureDetector(
          behavior: HitTestBehavior.translucent,
          onTap: () => FocusScope.of(context).unfocus(),
          child: Stack(
            children: [
              Column(
                children: [
                  Expanded(
                    child: ListView(
                      controller: _scrollController,
                      keyboardDismissBehavior:
                          ScrollViewKeyboardDismissBehavior.onDrag,
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
                      children: [
                        if (_items.isEmpty)
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            child: Text(
                              'Ask about budgets, envelopes, or ideas for next steps.',
                              style: TextStyle(color: secondaryText),
                            ),
                          ),
                        ..._items.map(
                          (item) => _buildMessageRow(
                            item,
                            primaryText: primaryText,
                            secondaryText: secondaryText,
                            dividerColor: dividerColor,
                            isApplying: isApplying,
                          ),
                        ),
                        const SizedBox(height: 6),
                      ],
                    ),
                  ),
                  SafeArea(
                    top: false,
                    child: Container(
                      color: CupertinoColors.systemBackground.resolveFrom(context),
                      padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          color: CupertinoColors.systemGrey6.resolveFrom(context),
                          borderRadius: BorderRadius.circular(22),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Expanded(
                                child: CupertinoTextField(
                                  controller: _messageController,
                                  focusNode: _messageFocus,
                                  placeholder: 'Message Penny Pixel Pop',
                                  padding:
                                      const EdgeInsets.symmetric(vertical: 10),
                                  maxLines: 4,
                                  minLines: 1,
                                  textInputAction: TextInputAction.send,
                                  onSubmitted: (_) => _sendMessage(),
                                  decoration: null,
                                ),
                              ),
                              if (kDebugMode) ...[
                                const SizedBox(width: 8),
                                CupertinoButton(
                                  padding:
                                      const EdgeInsets.symmetric(horizontal: 6),
                                  onPressed: _sending ? null : _sendCannedMessage,
                                  child: const Text('Test'),
                                ),
                              ],
                              const SizedBox(width: 10),
                              CupertinoButton(
                                padding: EdgeInsets.zero,
                                onPressed: _sending ? null : _sendMessage,
                                child: DecoratedBox(
                                  decoration: BoxDecoration(
                                    color:
                                        CupertinoColors.label.resolveFrom(context),
                                    shape: BoxShape.circle,
                                  ),
                                  child: SizedBox(
                                    width: 34,
                                    height: 34,
                                    child: _sending
                                        ? const CupertinoActivityIndicator(
                                            radius: 10,
                                          )
                                        : Icon(
                                            CupertinoIcons.arrow_up,
                                            size: 18,
                                            color: CupertinoColors.systemBackground
                                                .resolveFrom(context),
                                          ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              if (isShowingJumpToBottom)
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 78 + MediaQuery.of(context).viewInsets.bottom,
                  child: Center(
                    child: CupertinoButton(
                      padding: EdgeInsets.zero,
                      onPressed: () => _scrollToBottom(force: true),
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          color: CupertinoColors.systemGrey6
                              .resolveFrom(context)
                              .withValues(alpha: 0.95),
                          borderRadius: BorderRadius.circular(18),
                          boxShadow: const [
                            BoxShadow(
                              color: Color(0x22000000),
                              blurRadius: 12,
                              offset: Offset(0, 6),
                            ),
                          ],
                        ),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 8,
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                CupertinoIcons.chevron_down,
                                size: 16,
                                color: primaryText,
                              ),
                              const SizedBox(width: 6),
                              Text(
                                'Jump to latest',
                                style: TextStyle(
                                  color: primaryText,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMessageRow(
    ChatItem item, {
    required Color primaryText,
    required Color secondaryText,
    required Color dividerColor,
    required bool isApplying,
  }) {
    final isUser = item.kind == ChatItemKind.userMessage;
    final bubbleColor = isUser
        ? CupertinoColors.systemGrey5.resolveFrom(context)
        : CupertinoColors.systemBackground.resolveFrom(context);
    final textColor = CupertinoColors.label.resolveFrom(context);

    if (item.kind == ChatItemKind.userMessage) {
      final statusLabel = switch (item.status) {
        ChatMessageStatus.sending => 'Sending…',
        ChatMessageStatus.failed => 'Failed • Tap to retry',
        ChatMessageStatus.sent || null => null,
      };
      final isRetryable = item.status == ChatMessageStatus.failed;
      return Align(
        alignment: Alignment.centerRight,
        child: GestureDetector(
          onTap: isRetryable ? () => _retryMessage(item) : null,
          onLongPress: () => _showMessageActions(item),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Container(
                margin: const EdgeInsets.symmetric(vertical: 6),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                constraints: const BoxConstraints(maxWidth: 320),
                decoration: BoxDecoration(
                  color: bubbleColor,
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Text(
                  item.text,
                  style: TextStyle(color: textColor, fontSize: 15),
                ),
              ),
              if (statusLabel != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Text(
                    statusLabel,
                    style: TextStyle(
                      color: secondaryText,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
            ],
          ),
        ),
      );
    }

    if (item.kind == ChatItemKind.assistantTyping) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 28,
              height: 28,
              decoration: BoxDecoration(
                color: CupertinoColors.systemGrey5.resolveFrom(context),
                shape: BoxShape.circle,
              ),
              child: const Icon(CupertinoIcons.sparkles, size: 14),
            ),
            const SizedBox(width: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: CupertinoColors.systemGrey6.resolveFrom(context),
                borderRadius: BorderRadius.circular(18),
              ),
              child: const CupertinoActivityIndicator(radius: 9),
            ),
          ],
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  color: CupertinoColors.systemGrey5.resolveFrom(context),
                  shape: BoxShape.circle,
                ),
                child: const Icon(CupertinoIcons.sparkles, size: 14),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: GestureDetector(
                  behavior: HitTestBehavior.translucent,
                  onLongPress: () => _showMessageActions(item),
                  child: Text(
                    item.text,
                    style: TextStyle(color: textColor, fontSize: 15),
                  ),
                ),
              ),
            ],
          ),
          if (item.warnings.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              item.warnings.join(' • '),
              style: TextStyle(
                color: secondaryText,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
          if (item.actions.isNotEmpty) ...[
            const SizedBox(height: 12),
            ..._buildActionWidgets(
              item,
              primaryText: primaryText,
              secondaryText: secondaryText,
              dividerColor: dividerColor,
              isApplying: isApplying,
            ),
          ],
          if (item.clarification != null) ...[
            const SizedBox(height: 12),
            Text(
              item.clarification!.prompt,
              style: TextStyle(
                color: secondaryText,
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: item.clarification!.choices
                  .map(
                    (candidate) => CupertinoButton(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      color: CupertinoColors.systemGrey5.resolveFrom(context),
                      borderRadius: BorderRadius.circular(16),
                      onPressed: () => _insertCandidate(
                        candidate,
                        mode: item.clarification!.insertMode,
                      ),
                      child: Text(
                        candidate,
                        style: TextStyle(
                          color: primaryText,
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  )
                  .toList(),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildActionCard(
    ProposedAction action, {
    required Color primaryText,
    required Color secondaryText,
    required Color dividerColor,
    required bool isApplying,
  }) {
    final isBusy = _applyingActionId == action.id;
    final isApplied = action.status == ActionStatus.applied;
    final isIgnored = action.status == ActionStatus.ignored;
    final isDisabled = isApplying || isApplied || isIgnored;

    final buttonLabel = switch (action.status) {
      ActionStatus.applied => 'Applied',
      ActionStatus.ignored => 'Ignored',
      ActionStatus.proposed => 'Apply budget changes',
    };

    final helperText = 'Updates budgets only — no money is moved.';

    String title = 'Budget change';
    String? line1;
    String? line2;

    final repairPayload = action.budgetRepairRestoreDonorPayload;
    final transferPayload = action.budgetTransferPayload;

    if (repairPayload != null) {
      title = 'Fix budget after transfer';
      final donor = repairPayload.donorPodName;
      final funding = repairPayload.fundingPodName;
      final amount = repairPayload.amountInCents;
      if (donor != null && donor.isNotEmpty && amount != null) {
        line1 = '$donor budget: +${_formatDollarsFromCents(amount)}';
      }
      if (funding != null && funding.isNotEmpty && amount != null) {
        line2 = '$funding budget: −${_formatDollarsFromCents(amount)}';
      }
    } else if (transferPayload != null) {
      title = 'Update budget';
      final from = transferPayload.fromPodName;
      final to = transferPayload.toPodName;
      final amount = transferPayload.amountInCents;
      if (to != null && to.isNotEmpty && amount != null) {
        line1 = '$to budget: +${_formatDollarsFromCents(amount)}';
      }
      if (from != null && from.isNotEmpty && amount != null) {
        line2 = '$from budget: −${_formatDollarsFromCents(amount)}';
      }
    }

    final effectiveTitle =
        action.title?.trim().isNotEmpty == true ? action.title!.trim() : title;
    final summary = action.summary?.trim();
    final confidenceLabel = _confidenceLabel(action.confidence);

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: GlassCard(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Text(
                    effectiveTitle,
                    style: TextStyle(
                      color: primaryText,
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                if (confidenceLabel != null) ...[
                  const SizedBox(width: 8),
                  Text(
                    confidenceLabel,
                    style: TextStyle(
                      color: secondaryText,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ],
            ),
            if (summary != null && summary.isNotEmpty) ...[
              const SizedBox(height: 6),
              Text(
                summary,
                style: TextStyle(color: secondaryText, fontSize: 13),
              ),
            ],
            if (line1 != null && line1.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                line1,
                style: TextStyle(
                  color: primaryText,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
            if (line2 != null && line2.isNotEmpty) ...[
              const SizedBox(height: 6),
              Text(
                line2,
                style: TextStyle(
                  color: primaryText,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
            const SizedBox(height: 10),
            Container(height: 1, color: dividerColor),
            const SizedBox(height: 10),
            CupertinoButton(
              padding: EdgeInsets.zero,
              minSize: 0,
              onPressed: isDisabled ? null : () => _applyAction(action),
              child: isBusy
                  ? const CupertinoActivityIndicator(radius: 10)
                  : Text(
                      buttonLabel,
                      style: TextStyle(
                        color: isDisabled
                            ? secondaryText
                            : CupertinoColors.activeBlue.resolveFrom(context),
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        decoration: TextDecoration.underline,
                      ),
                    ),
            ),
            const SizedBox(height: 8),
            Text(
              helperText,
              style: TextStyle(color: secondaryText, fontSize: 11),
            ),
          ],
        ),
      ),
    );
  }

  List<Widget> _buildActionWidgets(
    ChatItem item, {
    required Color primaryText,
    required Color secondaryText,
    required Color dividerColor,
    required bool isApplying,
  }) {
    final repairGroups = <String, List<ProposedAction>>{};
    for (final action in item.actions) {
      final payload = action.budgetRepairRestoreDonorPayload;
      if (action.type == 'budget_repair_restore_donor' &&
          payload?.donorPodId != null) {
        repairGroups.putIfAbsent(payload!.donorPodId!, () => []).add(action);
      }
    }

    final groupableDonorIds = <String>{};
    repairGroups.forEach((donorId, actions) {
      final labels = actions
          .map((a) => a.budgetRepairRestoreDonorPayload?.optionLabel)
          .where((label) => label != null && label.trim().isNotEmpty)
          .toSet();
      if (actions.length > 1 && labels.length > 1) {
        groupableDonorIds.add(donorId);
      }
    });

    final widgets = <Widget>[];
    final renderedGroups = <String>{};

    for (final action in item.actions) {
      final payload = action.budgetRepairRestoreDonorPayload;
      if (action.type == 'budget_repair_restore_donor' &&
          payload?.donorPodId != null &&
          groupableDonorIds.contains(payload!.donorPodId)) {
        final groupId = '${item.id}:${payload.donorPodId}';
        if (renderedGroups.add(groupId) &&
            !_dismissedRepairGroups.contains(groupId)) {
          widgets.add(
            _buildRepairOptionsGroup(
              groupId: groupId,
              actions: repairGroups[payload.donorPodId] ?? const [],
              primaryText: primaryText,
              secondaryText: secondaryText,
              dividerColor: dividerColor,
              isApplying: isApplying,
            ),
          );
        }
        continue;
      }
      widgets.add(
        _buildActionCard(
          action,
          primaryText: primaryText,
          secondaryText: secondaryText,
          dividerColor: dividerColor,
          isApplying: isApplying,
        ),
      );
    }

    return widgets;
  }

  Widget _buildRepairOptionsGroup({
    required String groupId,
    required List<ProposedAction> actions,
    required Color primaryText,
    required Color secondaryText,
    required Color dividerColor,
    required bool isApplying,
  }) {
    final sortedActions = [...actions]..sort((a, b) {
        final aLabel = a.budgetRepairRestoreDonorPayload?.optionLabel;
        final bLabel = b.budgetRepairRestoreDonorPayload?.optionLabel;
        return _optionSortIndex(aLabel).compareTo(_optionSortIndex(bLabel));
      });

    final donorName =
        sortedActions.first.budgetRepairRestoreDonorPayload?.donorPodName ??
            'Donor';
    final amount = sortedActions.first.budgetRepairRestoreDonorPayload?.amountInCents;
    final amountText =
        amount == null ? null : _formatDollarsFromCents(amount);

    final summary = amountText == null
        ? 'Restore $donorName'
        : 'Restore $donorName by $amountText';

    final hasApplied = sortedActions.any((a) => a.status == ActionStatus.applied);
    final selectedId = _selectedRepairGroupActionIds[groupId] ??
        _defaultRepairOptionActionId(sortedActions) ??
        sortedActions.first.id;
    final isBusy =
        _applyingActionId != null && sortedActions.any((a) => a.id == _applyingActionId);
    final isDisabled = isApplying || hasApplied;

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: GlassCard(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Fix budget after transfer',
                    style: TextStyle(
                      color: primaryText,
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                CupertinoButton(
                  padding: EdgeInsets.zero,
                  onPressed: () {
                    setState(() {
                      _dismissedRepairGroups.add(groupId);
                      _selectedRepairGroupActionIds.remove(groupId);
                    });
                  },
                  child: Icon(
                    CupertinoIcons.xmark,
                    size: 16,
                    color: secondaryText,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              summary,
              style: TextStyle(color: secondaryText, fontSize: 13),
            ),
            const SizedBox(height: 10),
            Text(
              'Choose one',
              style: TextStyle(
                color: secondaryText,
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            ...sortedActions.map((action) {
              final label = _repairOptionLabel(action);
              final isSelected = action.id == selectedId;
              return Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: CupertinoButton(
                  padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 10),
                  color: CupertinoColors.systemGrey6.resolveFrom(context),
                  borderRadius: BorderRadius.circular(12),
                  onPressed: isDisabled
                      ? null
                      : () => setState(() {
                            _selectedRepairGroupActionIds[groupId] = action.id;
                          }),
                  child: Row(
                    children: [
                      Icon(
                        isSelected
                            ? CupertinoIcons.check_mark_circled_solid
                            : CupertinoIcons.circle,
                        size: 18,
                        color: isSelected ? primaryText : secondaryText,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          label,
                          style: TextStyle(
                            color: primaryText,
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }),
            const SizedBox(height: 6),
            Container(height: 1, color: dividerColor),
            const SizedBox(height: 10),
            CupertinoButton(
              padding: EdgeInsets.zero,
              minSize: 0,
              onPressed: isDisabled
                  ? null
                  : () => _applyRepairGroup(
                        selectedActionId: selectedId,
                        groupActionIds: sortedActions.map((a) => a.id).toList(),
                      ),
              child: isBusy
                  ? const CupertinoActivityIndicator(radius: 10)
                  : Text(
                      hasApplied ? 'Applied' : 'Apply selected option',
                      style: TextStyle(
                        color: isDisabled
                            ? secondaryText
                            : CupertinoColors.activeBlue.resolveFrom(context),
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        decoration: TextDecoration.underline,
                      ),
                    ),
            ),
            const SizedBox(height: 8),
            Text(
              'Updates budgets only — no money is moved.',
              style: TextStyle(color: secondaryText, fontSize: 11),
            ),
          ],
        ),
      ),
    );
  }

  String? _defaultRepairOptionActionId(List<ProposedAction> actions) {
    for (final action in actions) {
      final label = action.budgetRepairRestoreDonorPayload?.optionLabel;
      if (_isOptionA(label)) return action.id;
    }
    return actions.isEmpty ? null : actions.first.id;
  }

  bool _isOptionA(String? label) {
    if (label == null) return false;
    final normalized = label.trim().toLowerCase();
    return normalized == 'a' ||
        normalized == 'option a' ||
        RegExp(r'\ba\b', caseSensitive: false).hasMatch(normalized);
  }

  int _optionSortIndex(String? label) {
    if (label == null) return 999;
    final match = RegExp(r'[A-Za-z]').firstMatch(label);
    if (match == null) return 999;
    switch (match.group(0)!.toUpperCase()) {
      case 'A':
        return 0;
      case 'B':
        return 1;
      case 'C':
        return 2;
      default:
        return 999;
    }
  }

  String _repairOptionLabel(ProposedAction action) {
    final payload = action.budgetRepairRestoreDonorPayload;
    final rawLabel = payload?.optionLabel?.trim();
    final optionLabel = (rawLabel == null || rawLabel.isEmpty)
        ? 'Option'
        : rawLabel.toLowerCase().startsWith('option')
            ? rawLabel
            : 'Option $rawLabel';
    final amount = payload?.amountInCents;
    final funding = payload?.fundingPodName;
    if (amount != null && funding != null && funding.isNotEmpty) {
      return '$optionLabel — take ${_formatDollarsFromCents(amount)} from $funding';
    }
    if (funding != null && funding.isNotEmpty) {
      return '$optionLabel — take from $funding';
    }
    return optionLabel;
  }
}

enum CandidateInsertMode { plain, from, to }

class ChatClarification {
  const ChatClarification({
    required this.prompt,
    required this.insertMode,
    required this.choices,
  });

  final String prompt;
  final CandidateInsertMode insertMode;
  final List<String> choices;
}

class ChatItem {
  ChatItem({
    required this.id,
    required this.text,
    required this.kind,
    List<ProposedAction>? actions,
    required this.clarification,
    required this.status,
    List<String>? warnings,
  })  : actions = actions ?? const [],
        warnings = warnings ?? const [];

  final String id;
  final String text;
  final ChatItemKind kind;
  final List<ProposedAction> actions;
  final ChatClarification? clarification;
  final ChatMessageStatus? status;
  final List<String> warnings;

  ChatItem copyWith({
    String? id,
    String? text,
    ChatItemKind? kind,
    List<ProposedAction>? actions,
    ChatClarification? clarification,
    ChatMessageStatus? status,
    List<String>? warnings,
  }) {
    return ChatItem(
      id: id ?? this.id,
      text: text ?? this.text,
      kind: kind ?? this.kind,
      actions: actions ?? this.actions,
      clarification: clarification ?? this.clarification,
      status: status ?? this.status,
      warnings: warnings ?? this.warnings,
    );
  }

  factory ChatItem.user({
    required String id,
    required String text,
    required ChatMessageStatus status,
  }) =>
      ChatItem(
        id: id,
        text: text,
        kind: ChatItemKind.userMessage,
        clarification: null,
        status: status,
        warnings: const [],
      );

  factory ChatItem.typing({required String id}) => ChatItem(
        id: id,
        text: '',
        kind: ChatItemKind.assistantTyping,
        clarification: null,
        status: null,
        warnings: const [],
      );

  factory ChatItem.assistant(
    String text, {
    List<ProposedAction>? actions,
    List<String>? warnings,
    ChatClarification? clarification,
  }) {
    return ChatItem(
      id: DateTime.now().microsecondsSinceEpoch.toString(),
      text: text,
      kind: ChatItemKind.assistantMessage,
      actions: actions,
      warnings: warnings,
      clarification: clarification,
      status: null,
    );
  }
}

enum ChatItemKind { userMessage, assistantMessage, assistantTyping }

enum ChatMessageStatus { sending, sent, failed }
