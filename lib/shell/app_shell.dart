import 'package:flutter/cupertino.dart';
import 'package:go_router/go_router.dart';
import 'package:penny_pop_app/design/glass/glass.dart';
import 'package:penny_pop_app/widgets/pixel_nav_icon.dart';

class AppShell extends StatelessWidget {
  const AppShell({super.key, required this.navigationShell});

  final StatefulNavigationShell navigationShell;

  void _onTap(int index) {
    navigationShell.goBranch(
      index,
      initialLocation: index == navigationShell.currentIndex,
    );
  }

  @override
  Widget build(BuildContext context) {
    final reduceMotion = GlassAdaptive.reduceMotionOf(context);
    final keyboardInset = MediaQuery.of(context).viewInsets.bottom;
    final safeBottom = MediaQuery.of(context).padding.bottom;

    const barHeight = 66.0;
    const horizontalInset = 12.0;
    const verticalInset = 10.0;

    return CupertinoPageScaffold(
      child: Stack(
        children: <Widget>[
          Positioned.fill(
            child: Padding(
              padding: EdgeInsets.only(
                bottom: barHeight + verticalInset + safeBottom,
              ),
              child: navigationShell,
            ),
          ),
          Positioned(
            left: horizontalInset,
            right: horizontalInset,
            bottom: 0,
            child: SafeArea(
              top: false,
              child: AnimatedPadding(
                padding: EdgeInsets.only(
                  bottom: keyboardInset > 0 ? keyboardInset : verticalInset,
                ),
                duration: reduceMotion
                    ? Duration.zero
                    : const Duration(milliseconds: 220),
                curve: Curves.easeOutCubic,
                child: _GlassBottomTabBar(
                  currentIndex: navigationShell.currentIndex,
                  onTap: _onTap,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _GlassBottomTabBar extends StatelessWidget {
  const _GlassBottomTabBar({required this.currentIndex, required this.onTap});

  final int currentIndex;
  final ValueChanged<int> onTap;

  @override
  Widget build(BuildContext context) {
    final reduceMotion = GlassAdaptive.reduceMotionOf(context);
    final brightness = GlassAdaptive.brightnessOf(context);

    const tabCount = 4;
    const bubbleSideInset = 6.0;

    final bubbleColor = brightness == Brightness.dark
        ? const Color(0x22FFFFFF) // subtle highlight on dark
        : const Color(0x66FFFFFF); // stronger highlight on light

    final bubbleBorder = brightness == Brightness.dark
        ? const Color(0x33FFFFFF)
        : const Color(0x40FFFFFF);

    final textStyle = CupertinoTheme.of(context).textTheme.tabLabelTextStyle
        .copyWith(fontSize: 11, fontWeight: FontWeight.w600);

    Color resolveIconColor({required bool selected}) {
      final base = brightness == Brightness.dark
          ? CupertinoColors.white
          : CupertinoColors.black;
      return selected ? base : base.withValues(alpha: 0.55);
    }

    Widget tab({
      required int index,
      required String label,
      required String assetPath,
    }) {
      final selected = index == currentIndex;
      final color = resolveIconColor(selected: selected);

      return Expanded(
        child: Semantics(
          selected: selected,
          button: true,
          label: label,
          child: CupertinoButton(
            padding: EdgeInsets.zero,
            minimumSize: Size.zero,
            onPressed: () => onTap(index),
            child: IconTheme(
              data: IconThemeData(color: color, size: 24),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: <Widget>[
                  PixelNavIcon(assetPath, semanticLabel: label),
                  const SizedBox(height: 4),
                  DefaultTextStyle(
                    style: textStyle.copyWith(color: color),
                    child: Text(
                      label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    return GlassBar(
      height: 66,
      // Give the “liquid” bubble more vertical room so it can read like the
      // bar’s own material, not a small pill.
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final slotWidth = constraints.maxWidth / tabCount;
          final bubbleWidth = (slotWidth - bubbleSideInset * 2).clamp(
            0.0,
            slotWidth,
          );
          final bubbleHeight = constraints.maxHeight;
          final targetLeft = slotWidth * currentIndex + bubbleSideInset;

          return Stack(
            clipBehavior: Clip.none,
            children: [
              AnimatedPositioned(
                duration: reduceMotion
                    ? Duration.zero
                    : const Duration(milliseconds: 220),
                curve: Curves.easeOutCubic,
                left: targetLeft,
                top: 0,
                width: bubbleWidth,
                height: bubbleHeight,
                child: IgnorePointer(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: bubbleColor,
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(color: bubbleBorder, width: 1),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF000000).withValues(
                            alpha: brightness == Brightness.dark ? 0.25 : 0.10,
                          ),
                          blurRadius: 14,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              Row(
                children: <Widget>[
                  tab(
                    index: 0,
                    label: 'Overview',
                    assetPath: 'assets/icons/nav/overview.svg',
                  ),
                  tab(
                    index: 1,
                    label: 'Pods',
                    assetPath: 'assets/icons/nav/pods.svg',
                  ),
                  tab(
                    index: 2,
                    label: 'Guide',
                    assetPath: 'assets/icons/nav/guide.svg',
                  ),
                  tab(
                    index: 3,
                    label: 'Transactions',
                    assetPath: 'assets/icons/nav/transactions.svg',
                  ),
                ],
              ),
            ],
          );
        },
      ),
    );
  }
}
