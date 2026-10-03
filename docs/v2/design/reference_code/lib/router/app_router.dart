// Routes theo docs/HANDOFF_FULL.md §06. Màn chưa code → SsPlaceholderScreen(id).
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../core/app_state.dart';
import '../core/enums.dart';
import '../features/home/home_screen.dart';
import '../features/paywall/paywall_screen.dart';
import '../features/placeholder/placeholder_screen.dart';
import '../features/recording/active_recording_screen.dart';
import '../features/recordings/recording_detail_screen.dart';
import '../features/recordings/recordings_screen.dart';
import '../features/settings/settings_screen.dart';
import '../features/splash/splash_screen.dart';
import '../features/watch/watch_screen.dart';
import '../widgets/ss_shell.dart';

GoRoute _ph(String path, String ids, String title, {List<RouteBase> routes = const []}) =>
    GoRoute(path: path, builder: (_, s) => SsPlaceholderScreen(ids: ids, title: title, location: s.uri.toString()), routes: routes);

Page<void> _modal(Widget child, GoRouterState s) => MaterialPage(key: s.pageKey, fullscreenDialog: true, child: child);

final _rootKey = GlobalKey<NavigatorState>();

final appRouter = GoRouter(
  navigatorKey: _rootKey,
  initialLocation: '/splash',
  refreshListenable: Listenable.merge([session, appGate]),
  redirect: (ctx, s) {
    final loc = s.matchedLocation;
    if (appGate.value == AppGate.forceUpdate && loc != '/force-update') return '/force-update';
    if (appGate.value == AppGate.maintenance && loc != '/maintenance') return '/maintenance';
    // G05: KHÔNG redirect khi đang record Local — chỉ hiện overlay re-login.
    if (session.value == SessionState.expired && !recorder.isActive && !loc.startsWith('/auth')) return '/auth/sign-in';
    return null;
  },
  routes: [
    GoRoute(path: '/splash', builder: (_, __) => const SplashScreen()),
    _ph('/welcome', 'A02', 'Welcome'),
    _ph('/auth/sign-in', 'A03 · A03-error · A03-social', 'Đăng nhập'),
    _ph('/auth/sign-up', 'A04', 'Đăng ký'),
    _ph('/auth/forgot', 'A05', 'Quên mật khẩu'),
    _ph('/auth/check-email', 'A06', 'Kiểm tra email'),
    _ph('/auth/verify', 'A06-verify', 'Xác minh email'),
    _ph('/auth/reset', 'A05b', 'Đặt lại mật khẩu'),
    _ph('/auth/link', 'A14', 'Liên kết tài khoản'),
    _ph('/account/foreign-local-files', 'A16', 'File của tài khoản khác'),
    _ph('/onboarding/intro/:step', 'A07 · A08', 'Giới thiệu'),
    _ph('/onboarding/notifications', 'A09', 'Thông báo'),
    _ph('/onboarding/android-permission', 'A10', 'Quyền Android'),
    _ph('/onboarding/ios-limits', 'A11', 'Giới hạn iOS'),
    _ph('/onboarding/add-creator', 'A12 · A13', 'Thêm creator đầu tiên'),
    StatefulShellRoute.indexedStack(
      builder: (c, s, shell) => SsShell(shell: shell),
      branches: [
        StatefulShellBranch(routes: [GoRoute(path: '/home', builder: (_, __) => const HomeScreen())]),
        StatefulShellBranch(routes: [
          GoRoute(path: '/watch', builder: (_, __) => const WatchScreen(), routes: [
            _ph('add', 'W04–W08', 'Thêm creator'),
            _ph('creator/:creatorId', 'W09–W11 · W10-waiting · Q06', 'Creator', routes: [
              _ph('auto-record', 'W15', 'Auto-record'),
            ]),
          ]),
        ]),
        StatefulShellBranch(routes: [
          GoRoute(path: '/recordings', builder: (_, __) => const RecordingsScreen(), routes: [
            _ph('search', 'L03', 'Tìm bản ghi'),
            GoRoute(path: ':recordingId', builder: (_, s) => RecordingDetailScreen(id: s.pathParameters['recordingId']!)),
          ]),
        ]),
        StatefulShellBranch(routes: [
          GoRoute(path: '/settings', builder: (_, __) => const SettingsScreen(), routes: [
            _ph('plan', 'M01 · M02 · M12 · M13 · M14', 'Gói & mức dùng', routes: [_ph('manage', 'M11', 'Quản lý gói')]),
            _ph('storage', 'S03', 'Bộ nhớ'),
            _ph('background', 'S04', 'Record nền'),
            _ph('notifications', 'S05', 'Thông báo'),
            _ph('appearance', 'S06', 'Giao diện'),
            _ph('language', 'S07', 'Ngôn ngữ'),
            _ph('account', 'S08 · S15 · S16', 'Tài khoản', routes: [
              _ph('devices', 'S09', 'Thiết bị'),
              _ph('password', 'S10 · S10b', 'Mật khẩu'),
              _ph('delete', 'S17', 'Xoá tài khoản', routes: [_ph('confirm', 'S18', 'Xác nhận xoá')]),
            ]),
            _ph('help', 'S11', 'Trợ giúp', routes: [_ph('report', 'S12', 'Báo lỗi')]),
            _ph('legal', 'S13', 'Pháp lý'),
            _ph('responsible-use', 'S14', 'Sử dụng có trách nhiệm'),
          ]),
        ]),
      ],
    ),
    GoRoute(
      path: '/recording/:sessionId',
      pageBuilder: (_, s) => _modal(ActiveRecordingScreen(sessionId: s.pathParameters['sessionId']!), s),
    ),
    _ph('/cloud-recording/:jobId', 'R26–R28 · Q05', 'Cloud recording'),
    _ph('/player/:recordingId', 'L08 · L08-landscape', 'Player'),
    GoRoute(
      path: '/paywall',
      pageBuilder: (_, s) => _modal(
          PaywallScreen(
            context: PaywallContext.values.asNameMap()[s.uri.queryParameters['context']] ?? PaywallContext.autoRecord,
          ),
          s),
    ),
    _ph('/cloud-pack', 'M10', 'Cloud Pack'),
    _ph('/notifications', 'N01 · N02 · N05', 'Thông báo'),
    _ph('/permission/notifications', 'N03', 'Bật thông báo'),
    _ph('/help/battery', 'AN03', 'Tối ưu pin'),
    _ph('/force-update', 'G04', 'Cần cập nhật'),
    _ph('/maintenance', 'G06', 'Bảo trì'),
  ],
);
