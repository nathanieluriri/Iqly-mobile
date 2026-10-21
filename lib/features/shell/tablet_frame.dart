import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/money.dart';
import '../../core/navigation.dart';
import '../../core/responsive.dart';
import '../../core/tablet_layout.dart';
import '../../core/transitions.dart';
import '../../data/help_service.dart' show supportShownProvider;
import '../../data/referrals_service.dart' show referralsShownProvider;
import '../../data/repository.dart';
import '../../router.dart';
import '../../theme/theme.dart';
import '../../ui/avatar.dart';
import '../../ui/icon.dart';
import '../../ui/tablet_icon.dart';
import '../../ui/tablet_nav.dart';
import '../../ui/web_account_menu.dart';
import '../../ui/web_app_bar.dart';
import '../avatar/avatar_state.dart';
import '../more/more_screen.dart' show confirmSignOut;
import '../more/more_state.dart';
import '../onboarding/onboarding_draft.dart' show accountNameProvider;
import '../settings/tablet_settings.dart';
import 'tablet_routes.dart';
import 'tablet_entry.dart';
import 'tablet_splits.dart';
import 'tablet_step_card.dart';
import 'tablet_search.dart';

/// T1 · Shell (Mobile App · tablet, 1838:41559): on a tablet the signed-in
/// app sits in a frame of Exp/Tablet/Nav and the Exp/Web/AppBar, its pages
/// on one white panel (radius 18, 12 from the right and bottom). Portrait
/// (600 to 839) has the 88 rail; landscape (840 and up) the 232 sidebar,
/// which collapses to the rail. The status bar and home indicator keep
/// their safe areas. Phones get [child] as it is.
///
/// The navigator stays in one place in the tree whatever the window does,
/// so a rotation keeps every page, draft, scroll position and dialog. The
/// chrome paints under the navigator, so a dialog's scrim covers it, and
/// takes taps before the navigator while a page with chrome is on top.
class TabletFrame extends ConsumerStatefulWidget {
  const TabletFrame({super.key, required this.router, required this.child});

  final GoRouter router;
  final Widget child;

  static const double edge = IqSpace.s3;

  @override
  ConsumerState<TabletFrame> createState() => _TabletFrameState();
}

class _TabletFrameState extends ConsumerState<TabletFrame> {
  final _navigator = GlobalKey();
  late TabletRouteWatch _watch;
  String _location = '';
  bool _popup = false;
  bool _collapsed = false;
  _Overlay _overlay = _Overlay.none;

  @override
  void initState() {
    super.initState();
    _attach();
  }

  @override
  void didUpdateWidget(TabletFrame old) {
    super.didUpdateWidget(old);
    if (old.router != widget.router) {
      old.router.routerDelegate.removeListener(_changed);
      _watch.removeListener(_changed);
      _attach();
    }
  }

  void _attach() {
    widget.router.routerDelegate.addListener(_changed);
    _watch = TabletRouteWatch.of(widget.router);
    _watch.addListener(_changed);
    _read();
  }

  @override
  void dispose() {
    widget.router.routerDelegate.removeListener(_changed);
    _watch.removeListener(_changed);
    super.dispose();
  }

  void _read() {
    final pages = openPages(widget.router.routerDelegate.currentConfiguration);
    _location = pages.isEmpty ? '' : pages.last.location.path;
    _popup = _watch.popupOnTop;
  }

  /// Route changes arrive while the navigator builds, so the frame follows
  /// them after the frame.
  void _changed() {
    if (SchedulerBinding.instance.schedulerPhase ==
        SchedulerPhase.persistentCallbacks) {
      SchedulerBinding.instance.addPostFrameCallback((_) => _apply());
    } else {
      _apply();
    }
  }

  void _apply() {
    if (!mounted) return;
    setState(() {
      final before = _location;
      _read();
      if (before != _location) _overlay = _Overlay.none;
    });
  }

  BuildContext? get _pageContext =>
      widget.router.routerDelegate.navigatorKey.currentContext;

  void _go(String location) {
    setState(() => _overlay = _Overlay.none);
    final router = widget.router;
    if (TabletRoutes.isTab(location)) {
      router.go(location, extra: NavDirection.forward);
    } else {
      router.open(location);
    }
  }

  static Widget _decorate(String location, Widget page) {
    if (TabletSettings.covers(location)) {
      return TabletSettings(location: location, child: page);
    }
    if (TabletEntrySplit.covers(location)) {
      return TabletEntrySplit(page: page);
    }
    if (TabletStepCard.covers(location)) {
      return TabletStepCard(location: location, child: page);
    }
    if (location == Routes.support) {
      return const TabletLocation(
        location: Routes.support,
        onCard: true,
        child: TabletSupportSplit(thread: null),
      );
    }
    if (TabletSupportSplit.threadOf(location) case final id?) {
      return TabletSupportSplit(thread: id, page: page);
    }
    if (TabletResultSplit.resultOf(location) case final id?) {
      return TabletLocation(
        location: location,
        onCard: true,
        child: TabletResultSplit(id: id, page: page),
      );
    }
    return page;
  }

  void _signOut() {
    setState(() => _overlay = _Overlay.none);
    final page = _pageContext;
    if (page != null) confirmSignOut(page, ref);
  }

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final size = Layout.sizeFor(media.size);
    final chrome = size.isTablet && TabletRoutes.hasChrome(_location);
    final rail = size == WindowSize.medium || _collapsed;
    final navWidth = rail ? IqTabletNav.railWidth : IqTabletNav.sidebarWidth;
    final pad = media.viewPadding;
    final panel = EdgeInsets.fromLTRB(
      pad.left + navWidth,
      pad.top + IqWebAppBar.height,
      pad.right + TabletFrame.edge,
      pad.bottom + TabletFrame.edge,
    );
    return WindowScope(
      size: size,
      child: TabletChrome(
        size: size,
        panel: panel,
        decorate: _decorate,
        cardPage: TabletStepCard.covers,
        child: _FrameStack(
          chromeFirst: chrome && !_popup,
          overlayOpen: chrome && _overlay != _Overlay.none,
          children: [
            if (chrome)
              Material(
                type: MaterialType.transparency,
                child: _Chrome(
                  location: _location,
                  rail: rail,
                  size: size,
                  collapsed: _collapsed,
                  panel: panel,
                  onGo: _go,
                  onToggle: () => setState(() => _collapsed = !_collapsed),
                  onSearch: () => setState(() => _overlay = _Overlay.search),
                  onAccount: () => setState(
                    () => _overlay = _overlay == _Overlay.account
                        ? _Overlay.none
                        : _Overlay.account,
                  ),
                ),
              )
            else
              const SizedBox.shrink(),
            KeyedSubtree(key: _navigator, child: widget.child),
            if (chrome && _overlay != _Overlay.none)
              _OverlayHost(
                child: Material(
                  type: MaterialType.transparency,
                  child: _Overlays(
                    overlay: _overlay,
                    panel: panel,
                    navWidth: navWidth,
                    onClose: () => setState(() => _overlay = _Overlay.none),
                    onGo: _go,
                    onSignOut: _signOut,
                  ),
                ),
              )
            else
              const SizedBox.shrink(),
          ],
        ),
      ),
    );
  }
}

enum _Overlay { none, account, search }

/// Paints the chrome, then the navigator, then the open menu; takes taps
/// in the other order, the chrome only while a page with chrome leads.
class _FrameStack extends Stack {
  const _FrameStack({
    required this.chromeFirst,
    required this.overlayOpen,
    required super.children,
  }) : super(fit: StackFit.expand);

  final bool chromeFirst;
  final bool overlayOpen;

  @override
  RenderStack createRenderObject(BuildContext context) => _RenderFrameStack(
    chromeFirst: chromeFirst,
    overlayOpen: overlayOpen,
    textDirection: Directionality.maybeOf(context),
    fit: fit,
  );

  @override
  void updateRenderObject(BuildContext context, RenderStack renderObject) {
    super.updateRenderObject(context, renderObject);
    (renderObject as _RenderFrameStack)
      ..chromeFirst = chromeFirst
      ..overlayOpen = overlayOpen;
  }
}

class _RenderFrameStack extends RenderStack {
  _RenderFrameStack({
    required this.chromeFirst,
    required this.overlayOpen,
    super.textDirection,
    super.fit,
  });

  bool chromeFirst;
  bool overlayOpen;

  @override
  bool hitTestChildren(BoxHitTestResult result, {required Offset position}) {
    final children = getChildrenAsList();
    final [chrome, navigator, overlay] = children;
    final order = [
      if (overlayOpen) overlay,
      if (chromeFirst) chrome,
      navigator,
    ];
    for (final child in order) {
      final data = child.parentData! as StackParentData;
      final hit = result.addWithPaintOffset(
        offset: data.offset,
        position: position,
        hitTest: (result, transformed) =>
            child.hitTest(result, position: transformed),
      );
      if (hit) return true;
    }
    return false;
  }
}

/// The nav, the app bar and the white panel the pages draw on. Only the
/// nav items and the bar take taps: the rest lets them through.
class _Chrome extends ConsumerWidget {
  const _Chrome({
    required this.location,
    required this.rail,
    required this.size,
    required this.collapsed,
    required this.panel,
    required this.onGo,
    required this.onToggle,
    required this.onSearch,
    required this.onAccount,
  });

  final String location;
  final bool rail;
  final WindowSize size;
  final bool collapsed;
  final EdgeInsets panel;
  final ValueChanged<String> onGo;
  final VoidCallback onToggle;
  final VoidCallback onSearch;
  final VoidCallback onAccount;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tabs = TabletRoutes.tabs(
      polls: ref.watch(pollsShownProvider),
      activations: ref.watch(activationsShownProvider),
    );
    final at = TabletRoutes.tabOf(location);
    final selected = tabs.indexWhere((t) => t.location == at);
    final support = ref.watch(supportShownProvider);
    final unread = ref.watch(unreadNotificationsProvider).value ?? 0;
    final pass = ref.watch(contributorPassProvider).value;
    final name = ref.watch(accountNameProvider) ?? pass?.user.name ?? '';
    final avatar = ref.watch(avatarProvider.select((a) => a.spec));
    final pad = MediaQuery.viewPaddingOf(context);
    return Stack(
      children: [
        const Positioned.fill(
          child: IgnorePointer(child: ColoredBox(color: IqColors.bg)),
        ),
        Positioned.fromRect(
          rect: panel.deflateRect(Offset.zero & MediaQuery.sizeOf(context)),
          child: IgnorePointer(
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: IqColors.card,
                borderRadius: BorderRadius.circular(TabletChrome.radius),
                border: Border.all(color: IqColors.line),
              ),
            ),
          ),
        ),
        Positioned(
          left: pad.left,
          top: pad.top,
          bottom: pad.bottom,
          child: IqTabletNav(
            layout: rail ? IqTabletNavLayout.rail : IqTabletNavLayout.sidebar,
            destinations: [for (final t in tabs) t.destination],
            selected: selected < 0 ? null : selected,
            support: support ? TabletRoutes.support : null,
            supportSelected: at == Routes.support,
            showToggle: size == WindowSize.expanded,
            onSelect: (i) => onGo(tabs[i].location),
            onSupport: () => onGo(Routes.support),
            onToggle: onToggle,
          ),
        ),
        Positioned(
          left: panel.left,
          right: panel.right,
          top: pad.top,
          child: IqWebAppBar(
            name: name,
            avatar: IqAvatar(avatar, size: 36),
            unread: '$unread',
            showUnread: unread > 0,
            showGift: ref.watch(referralsShownProvider),
            onSearch: onSearch,
            onGift: () => onGo(Routes.referrals),
            onNotifications: () => onGo(Routes.notifications),
            onAccount: onAccount,
          ),
        ),
      ],
    );
  }
}

/// The account menu and the search, over everything.
class _Overlays extends ConsumerWidget {
  const _Overlays({
    required this.overlay,
    required this.panel,
    required this.navWidth,
    required this.onClose,
    required this.onGo,
    required this.onSignOut,
  });

  final _Overlay overlay;
  final EdgeInsets panel;
  final double navWidth;
  final VoidCallback onClose;
  final ValueChanged<String> onGo;
  final VoidCallback onSignOut;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pad = MediaQuery.viewPaddingOf(context);
    final width = MediaQuery.sizeOf(context).width;
    return Stack(
      children: [
        Positioned.fill(
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: onClose,
            child: overlay == _Overlay.search
                ? ColoredBox(color: IqScrim.sheet)
                : const SizedBox.expand(),
          ),
        ),
        if (overlay == _Overlay.account)
          Positioned(
            right: pad.right + TabletFrame.edge,
            top: pad.top + 60,
            child: _AccountMenu(onGo: onGo, onSignOut: onSignOut),
          ),
        if (overlay == _Overlay.search)
          Positioned(
            left: pad.left + navWidth,
            top: pad.top + 68,
            width: math.min(640, width - pad.left - navWidth - panel.right),
            bottom: panel.bottom,
            child: Align(
              alignment: Alignment.topLeft,
              child: TabletSearch(onGo: onGo),
            ),
          ),
      ],
    );
  }
}

class _AccountMenu extends ConsumerWidget {
  const _AccountMenu({required this.onGo, required this.onSignOut});

  final ValueChanged<String> onGo;
  final VoidCallback onSignOut;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pass = ref.watch(contributorPassProvider).value;
    final name = ref.watch(accountNameProvider) ?? pass?.user.name ?? '';
    final avatar = ref.watch(avatarProvider.select((a) => a.spec));
    final referrals = ref.watch(referralsShownProvider);
    final points = ref.watch(leaderboardShownProvider);
    return IqWebAccountMenu(
      name: name,
      email: pass?.user.email ?? '',
      avatar: IqAvatar(avatar, size: 40),
      items: [
        IqWebAccountMenuItem(
          label: 'Your details',
          icon: IqIcons.profile,
          onTap: () => onGo(Routes.yourDetails),
        ),
        if (referrals)
          IqWebAccountMenuItem(
            label: 'Referrals',
            icon: IqIcons.gift,
            onTap: () => onGo(Routes.referrals),
          ),
        if (points)
          IqWebAccountMenuItem(
            label: 'iQL points',
            icon: IqIcons.medal,
            trail: switch (pass?.points) {
              final p? => wholeNumber(p),
              null => null,
            },
            onTap: () => onGo(Routes.pointsLeaderboard),
          ),
        IqWebAccountMenuItem(
          label: 'Settings',
          tabletIcon: IqTabletIcons.settings,
          onTap: () => onGo(Routes.yourDetails),
        ),
        IqWebAccountMenuItem(
          label: 'Sign out',
          icon: IqIcons.logout,
          dividerBefore: true,
          onTap: onSignOut,
        ),
      ],
    );
  }
}

/// Gives the search field the overlay its text selection needs: the menus
/// sit above the navigator, outside its overlay.
class _OverlayHost extends StatefulWidget {
  const _OverlayHost({required this.child});

  final Widget child;

  @override
  State<_OverlayHost> createState() => _OverlayHostState();
}

class _OverlayHostState extends State<_OverlayHost> {
  late final _entry = OverlayEntry(builder: (context) => widget.child);

  @override
  void didUpdateWidget(_OverlayHost old) {
    super.didUpdateWidget(old);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _entry.markNeedsBuild();
    });
  }

  @override
  Widget build(BuildContext context) => Overlay(initialEntries: [_entry]);
}
