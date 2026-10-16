import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../avatar/avatar_controller.dart';
import '../avatar/avatar_state.dart';
import '../data/connection.dart';
import '../data/gateway/chat_controller.dart';
import '../layout/ambient.dart';
import '../theme/tokens.dart';
import '../widgets/common.dart';
import '../widgets/frame.dart';
import '../widgets/icons.dart';
import 'chat_page.dart';
import 'clock_page.dart';
import 'google_workspace_page.dart';
import 'notifications_page.dart';
import 'settings_screen.dart';
import 'weather_page.dart';

/// Main screen: avatar stage + panel with swipeable Chat / Clock / Weather / Notifications / Google pages.
class HomeShell extends ConsumerStatefulWidget {
  const HomeShell({super.key});

  @override
  ConsumerState<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends ConsumerState<HomeShell> {
  final _pages = PageController();
  int _page = 0;

  static const _labels = ['Chat page', 'Clock page', 'Weather page', 'Notifications page', 'Google page'];

  @override
  void dispose() {
    _pages.dispose();
    super.dispose();
  }

  void _goTo(int i) => _pages.animateToPage(i, duration: const Duration(milliseconds: 280), curve: Curves.easeOutCubic);

  @override
  Widget build(BuildContext context) {
    final link = ref.watch(connectionProvider);
    // Keep the chat socket alive on every page without rebuilding the shell per streamed token.
    ref.listen(chatProvider, (_, _) {});
    // A lost link shows on the avatar too.
    final state = link.state == LinkState.offline ? AvatarState.oops : ref.watch(avatarProvider);
    final chatPhase = ref.watch(chatProvider.select((c) => c.phase));
    final disconnected = link.state == LinkState.offline || chatPhase == ChatPhase.offline;
    return ScreenFrame(
      state: state,
      onAvatarTap: ref.read(ambientProvider.notifier).petAvatar,
      stageAction: disconnected
          ? PillButton(
              'Reconnect',
              style: PillStyle.secondary,
              onPressed: () {
                ref.read(connectionProvider.notifier).check();
                ref.read(chatProvider.notifier).connect();
              },
            )
          : null,
      panelPadding: EdgeInsets.zero,
      panel: Column(
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 20, right: 16),
            child: SizedBox(
              height: 44,
              child: Row(
                children: [
                  Expanded(
                    child: GestureDetector(
                      onTap: () => ref.read(connectionProvider.notifier).check(),
                      child: StatusLine(link.label, dotColor: link.color),
                    ),
                  ),
                  for (var i = 0; i < _labels.length; i++)
                    Semantics(
                      button: true,
                      selected: _page == i,
                      label: _labels[i],
                      child: GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTap: () => _goTo(i),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          width: _page == i ? 40 : 28,
                          height: 44,
                          alignment: Alignment.center,
                          child: PageDot(active: _page == i),
                        ),
                      ),
                    ),
                  const SizedBox(width: 4),
                  IconTap(
                    icon: HIcon.sliders,
                    semanticLabel: 'Connection settings',
                    onPressed: () => Navigator.of(context).push(_fade(const SettingsScreen())),
                  ),
                ],
              ),
            ),
          ),
          Expanded(
            child: ClipRRect(
              borderRadius: const BorderRadius.vertical(bottom: Radius.circular(HRadii.panel)),
              child: PageView(
                controller: _pages,
                onPageChanged: (i) => setState(() => _page = i),
                children: const [
                  _PagePad(child: ChatPage()),
                  _PagePad(child: ClockPage()),
                  _PagePad(child: WeatherPage()),
                  _PagePad(child: NotificationsPage()),
                  _PagePad(bottom: 0, child: GoogleWorkspacePage()),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Panel padding from the design (0 16 12 20) applied per page so swipes span the whole panel.
class _PagePad extends StatelessWidget {
  const _PagePad({required this.child, this.bottom = 12});

  final Widget child;

  /// Bottom inset; scrolling pages pass 0 and pad their own list so rows aren't clipped mid-air.
  final double bottom;

  @override
  Widget build(BuildContext context) {
    // With the soft keyboard up the panel is only ~60dp tall (the Scaffold already shrank it):
    // give the page every dp. Normal pages get ~290dp.
    return LayoutBuilder(
      builder: (context, c) {
        final tight = c.maxHeight < _tightHeight;
        return Padding(padding: EdgeInsets.fromLTRB(20, tight ? 0 : 10, 16, tight ? 0 : bottom), child: child);
      },
    );
  }
}

/// Page height under which the soft keyboard must be up.
const _tightHeight = 120.0;

PageRoute<T> _fade<T>(Widget page) => PageRouteBuilder<T>(
  pageBuilder: (_, _, _) => page,
  transitionsBuilder: (_, a, _, child) => FadeTransition(opacity: a, child: child),
  transitionDuration: const Duration(milliseconds: 200),
);

PageRoute<T> fadeRoute<T>(Widget page) => _fade(page);
