---
name: chatgpt_like_chat_ux
overview: Improve iOS chat UX to feel closer to ChatGPT by adding keyboard-dismiss on drag, scroll-to-bottom affordances, message actions, and response state feedback while keeping the current chat data flow intact.
todos: []
---

# ChatGPT-like Chat UX Plan (iOS)

## Goals

- Match expected iOS chat interactions: drag-to-dismiss keyboard, scroll-to-bottom ergonomics, long-press actions, and clearer message state feedback.
- Keep current backend integration and message modeling in place, focusing on UX polish in the UI layer.

## Key Files

- [lib/screens/chat_screen.dart](/Volumes/Crucial%20X10/other-work/Penny%20Pixel%20Pop/penny_pop_app/lib/screens/chat_screen.dart)
- (Optional) [lib/widgets/user_menu_sheet.dart](/Volumes/Crucial%20X10/other-work/Penny%20Pixel%20Pop/penny_pop_app/lib/widgets/user_menu_sheet.dart) for common action sheet styling

## Plan

1. **Keyboard dismissal on drag**

- Set `keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag` on the chat `ListView` and ensure the input bar respects safe areas.
- Keep the existing tap-to-dismiss as a secondary path.

2. **Scroll tracking + jump-to-bottom affordance**

- Track whether the user is near the bottom by listening to `_scrollController`.
- When not at bottom, show a small floating “jump to bottom” pill/button above the input bar.
- Ensure `_scrollToBottom()` only auto-scrolls when already near bottom to avoid hijacking user scroll.

3. **Message actions (long-press)**

- Add `GestureDetector`/`ContextMenu` on message bubbles for `Copy` and `Share` (iOS-style `CupertinoActionSheet`).
- For assistant bubbles, enable “Copy” by default; for user bubbles, “Copy” and “Edit Draft” (prefill input) if desired.

4. **Message send/failed states**

- Track a per-message status (sending/sent/failed) in `ChatItem`.
- Render subtle status under user messages (e.g., “Sending…” / “Failed. Tap to retry”).
- Add a retry path that re-sends the failed message without duplicating the bubble.

5. **Typing/response feedback (non-streaming)**

- While awaiting the assistant response, insert a temporary assistant “typing” row (e.g., dots spinner) and replace it with the final response.
- Keep `_sending` for input disablement but prefer the per-message status for UI clarity.

6. **UX polish for input bar**

- Ensure input expands to 4 lines but retains send button alignment.
- Optionally add a one-tap “scroll to latest” when keyboard opens to keep the newest message visible.

## Notes on Implementation

- The existing chat list is built with a standard `ListView` and manual `_scrollToBottom()` calls; steps 1–2 will adjust behavior without major refactors.
- `ChatItem` is currently a lightweight model. Adding status and a temporary typing item can be done in-place to avoid new state management.
- All changes can remain inside `ChatScreen` unless you want reusable action sheets or bubble widgets.

## Todos

- Add keyboard-dismiss-on-drag and scroll position tracking in `ChatScreen`.
- Implement jump-to-bottom affordance with near-bottom detection.
- Add message actions via long-press/context menu on bubbles.
- Add per-message status + retry flow for failed sends.
- Add assistant typing placeholder handling and replace on response.