import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/config/app_config.dart';
import '../../core/widgets/savestream_widgets.dart';
import '../../features/account/presentation/account_screen.dart';
import '../../features/account/presentation/account_status_screens.dart';
import '../../features/account/presentation/delete_account_screen.dart';
import '../../features/account/presentation/help_center_screen.dart';
import '../../features/account/presentation/legal_screen.dart';
import '../../features/account/presentation/profile_screen.dart';
import '../../features/account/presentation/report_screen.dart';
import '../../features/auth/data/auth_providers.dart';
import '../../features/auth/presentation/check_email_screen.dart';
import '../../features/auth/presentation/forgot_password_screen.dart';
import '../../features/auth/presentation/register_screen.dart';
import '../../features/auth/presentation/reset_password_screen.dart';
import '../../features/auth/presentation/sign_in_screen.dart';
import '../../features/auth/presentation/verify_email_screen.dart';
import '../../features/channels/presentation/auto_record_settings_screen.dart';
import '../../features/channels/presentation/channel_detail_screen.dart';
import '../../features/channels/presentation/channels_screen.dart';
import '../../features/channels/presentation/live_notification_screen.dart';
import '../../features/channels/presentation/verify_ownership_screen.dart';
import '../../features/credits/presentation/ad_privacy_screen.dart';
import '../../features/credits/presentation/credits_screen.dart';
import '../../features/credits/presentation/purchase_status_screens.dart';
import '../../features/credits/presentation/purchases_screen.dart';
import '../../features/credits/presentation/usage_history_screen.dart';
import '../../features/design_system/presentation/component_gallery_screen.dart';
import '../../features/entitlement/presentation/entitlement_providers.dart';
import '../../features/home/presentation/home_screen.dart';
import '../../features/onboarding/presentation/add_first_creator_screen.dart';
import '../../features/onboarding/presentation/first_creator_added_screen.dart';
import '../../features/onboarding/presentation/intro_watch_detect_screen.dart';
import '../../features/onboarding/presentation/notification_rationale_screen.dart';
import '../../features/onboarding/presentation/welcome_screen.dart';
import '../../features/recordings/presentation/recording_detail_screen.dart';
import '../../features/recordings/presentation/recording_player_screen.dart';
import '../../features/recordings/presentation/recordings_screen.dart';
import '../../features/settings/presentation/language_screen.dart';
import '../../features/settings/presentation/notification_preferences_screen.dart';
import '../../features/settings/presentation/notifications_screen.dart';
import '../../features/settings/presentation/theme_screen.dart';
import '../../l10n/l10n.dart';
import '../app_settings_controller.dart';
import '../session/app_session_controller.dart';
import '../shell/main_shell.dart';
import '../splash/splash_screen.dart';
import 'app_routes.dart';

GoRouter createAppRouter({
  required AppConfig config,
  required AppSettingsController settings,
  required AppSessionController session,
}) {
  final GlobalKey<NavigatorState> rootNavigatorKey = GlobalKey<NavigatorState>(
    debugLabel: 'root',
  );

  return GoRouter(
    navigatorKey: rootNavigatorKey,
    initialLocation: AppRoutes.home,
    restorationScopeId: 'savestream_router',
    refreshListenable: Listenable.merge(<Listenable>[session, settings]),
    redirect: (BuildContext context, GoRouterState state) {
      final String location = state.matchedLocation;
      final bool isWelcome =
          location == AppRoutes.welcome || location == AppRoutes.onboarding;
      final bool isAuth = location.startsWith('/auth/');
      final bool isSplash = location == AppRoutes.splash;
      final bool isIntro = location.startsWith('/onboarding/');
      // Signed in, Profile → Change password uses the reset flow.
      final bool isPasswordFlow =
          location == AppRoutes.forgotPassword ||
          location == AppRoutes.checkEmail ||
          location == AppRoutes.resetPassword;

      final bool needsWelcome =
          !session.isAuthenticated &&
          (!session.hasCompletedOnboarding || !settings.hasCompletedIntro);

      if (needsWelcome) {
        if (isWelcome || isAuth) return null;
        return AppRoutes.welcome;
      }

      if (session.authStatus == AppAuthStatus.expired) {
        if (isAuth) return null;
        return null;
      }

      if (!session.isAuthenticated) {
        if (isAuth || isWelcome) return null;
        return AppRoutes.signIn;
      }

      if (!settings.hasCompletedIntro) {
        if (isIntro && !isWelcome) return null;
        return AppRoutes.introWatchDetect;
      }

      if (isWelcome ||
          (isAuth && !isPasswordFlow) ||
          isSplash ||
          (isIntro && location != AppRoutes.onboardingCreatorAdded)) {
        return AppRoutes.home;
      }

      return null;
    },
    errorBuilder: (BuildContext context, GoRouterState state) {
      return const _RouteErrorScreen();
    },
    routes: <RouteBase>[
      GoRoute(path: AppRoutes.root, redirect: (_, _) => AppRoutes.home),
      GoRoute(
        path: AppRoutes.splash,
        builder: (BuildContext context, GoRouterState state) {
          return const SplashScreen();
        },
      ),
      GoRoute(
        path: AppRoutes.welcome,
        builder: (BuildContext context, GoRouterState state) {
          return AnimatedBuilder(
            animation: settings,
            builder: (BuildContext context, Widget? child) {
              return WelcomeScreen(
                session: session,
                settings: settings,
                config: config,
              );
            },
          );
        },
      ),
      GoRoute(
        path: AppRoutes.onboarding,
        redirect: (_, _) => AppRoutes.welcome,
      ),
      GoRoute(
        path: AppRoutes.signIn,
        builder: (BuildContext context, GoRouterState state) {
          return Consumer(
            builder: (BuildContext context, WidgetRef ref, Widget? child) {
              return SignInScreen(
                repository: ref.watch(authRepositoryProvider),
                session: session,
                onSignedIn: () => ref.invalidate(entitlementProvider),
                onSignInMethod: settings.setSignInMethod,
              );
            },
          );
        },
      ),
      GoRoute(
        path: AppRoutes.register,
        builder: (BuildContext context, GoRouterState state) {
          return Consumer(
            builder: (BuildContext context, WidgetRef ref, Widget? child) {
              return RegisterScreen(
                repository: ref.watch(authRepositoryProvider),
                session: session,
                config: config,
                onSignedIn: () => ref.invalidate(entitlementProvider),
                onSignInMethod: settings.setSignInMethod,
              );
            },
          );
        },
      ),
      GoRoute(
        path: AppRoutes.verifyEmail,
        builder: (BuildContext context, GoRouterState state) {
          return Consumer(
            builder: (BuildContext context, WidgetRef ref, Widget? child) {
              return VerifyEmailScreen(
                repository: ref.watch(authRepositoryProvider),
                session: session,
                initialToken: state.uri.queryParameters['token'],
                justSent: state.uri.queryParameters['sent'] == '1',
              );
            },
          );
        },
      ),
      GoRoute(
        path: AppRoutes.forgotPassword,
        builder: (BuildContext context, GoRouterState state) {
          return Consumer(
            builder: (BuildContext context, WidgetRef ref, Widget? child) {
              return ForgotPasswordScreen(
                repository: ref.watch(authRepositoryProvider),
                session: session,
                initialEmail: state.uri.queryParameters['email'],
              );
            },
          );
        },
      ),
      GoRoute(
        path: AppRoutes.checkEmail,
        builder: (BuildContext context, GoRouterState state) {
          return CheckEmailScreen(
            email: state.uri.queryParameters['email'] ?? '',
          );
        },
      ),
      GoRoute(
        path: AppRoutes.resetPassword,
        builder: (BuildContext context, GoRouterState state) {
          return Consumer(
            builder: (BuildContext context, WidgetRef ref, Widget? child) {
              return ResetPasswordScreen(
                repository: ref.watch(authRepositoryProvider),
                session: session,
                initialToken: state.uri.queryParameters['token'],
              );
            },
          );
        },
      ),
      GoRoute(
        path: AppRoutes.accountSuspended,
        builder: (BuildContext context, GoRouterState state) {
          return AccountSuspendedScreen(
            reason: state.uri.queryParameters['reason'] ?? '',
            reference: state.uri.queryParameters['ref'] ?? '',
          );
        },
      ),
      GoRoute(
        path: AppRoutes.accountClosed,
        builder: (BuildContext context, GoRouterState state) {
          return AccountClosedScreen(
            reason: state.uri.queryParameters['reason'] ?? '',
          );
        },
      ),
      GoRoute(
        path: AppRoutes.accountDeleted,
        builder: (BuildContext context, GoRouterState state) {
          return AccountDeletedScreen(
            email: state.uri.queryParameters['email'] ?? '',
          );
        },
      ),
      GoRoute(
        path: AppRoutes.introWatchDetect,
        builder: (BuildContext context, GoRouterState state) {
          return const IntroWatchDetectScreen();
        },
      ),
      GoRoute(
        path: AppRoutes.onboardingNotifications,
        builder: (BuildContext context, GoRouterState state) {
          return const NotificationRationaleScreen();
        },
      ),
      GoRoute(
        path: AppRoutes.onboardingAddCreator,
        builder: (BuildContext context, GoRouterState state) {
          return const AddFirstCreatorScreen();
        },
      ),
      GoRoute(
        path: AppRoutes.onboardingCreatorAdded,
        builder: (BuildContext context, GoRouterState state) {
          return FirstCreatorAddedScreen(
            settings: settings,
            creatorName:
                state.uri.queryParameters['name'] ??
                context.l10n.onboardingSampleCreatorOneName,
            creatorHandle:
                state.uri.queryParameters['handle'] ??
                context.l10n.onboardingSampleCreatorOneHandle,
          );
        },
      ),
      // Recording time and its screens: full screen (no bottom bar), as
      // drawn. None of them shows the banner ad.
      GoRoute(
        path: AppRoutes.usage,
        builder: (BuildContext context, GoRouterState state) {
          return const CreditsScreen();
        },
        routes: <RouteBase>[
          GoRoute(path: 'cloud-hours', redirect: (_, _) => AppRoutes.usage),
          GoRoute(
            path: 'history',
            builder: (BuildContext context, GoRouterState state) {
              return const UsageHistoryScreen();
            },
          ),
          GoRoute(
            path: 'purchases',
            builder: (BuildContext context, GoRouterState state) {
              return const PurchasesScreen();
            },
          ),
          GoRoute(
            path: 'ad-privacy',
            builder: (BuildContext context, GoRouterState state) {
              return const AdPrivacyScreen();
            },
          ),
          GoRoute(
            path: 'purchase/success',
            builder: (BuildContext context, GoRouterState state) {
              return const PurchaseSuccessScreen();
            },
          ),
          GoRoute(
            path: 'purchase/pending',
            builder: (BuildContext context, GoRouterState state) {
              return const PurchasePendingScreen();
            },
          ),
        ],
      ),
      GoRoute(path: '/auth/register', redirect: (_, _) => AppRoutes.register),
      GoRoute(
        path: '/auth/verify-email',
        redirect: (BuildContext context, GoRouterState state) =>
            AppRoutes.verifyEmailLocation(
              token: state.uri.queryParameters['token'],
            ),
      ),
      GoRoute(
        path: '/auth/forgot-password',
        redirect: (_, _) => AppRoutes.forgotPassword,
      ),
      GoRoute(
        path: '/auth/reset-password',
        redirect: (BuildContext context, GoRouterState state) =>
            AppRoutes.resetPasswordLocation(
              token: state.uri.queryParameters['token'],
            ),
      ),
      GoRoute(
        path: '/live/:id',
        builder: (BuildContext context, GoRouterState state) {
          return LiveNotificationScreen(
            watchId: state.pathParameters['id']!,
            state: liveNotificationStateFromValue(
              state.uri.queryParameters['state'],
            ),
          );
        },
      ),
      // Full screen (no bottom bar), as drawn.
      GoRoute(
        path: '/channels/:id/verify',
        builder: (BuildContext context, GoRouterState state) {
          return VerifyOwnershipScreen(watchId: state.pathParameters['id']!);
        },
      ),
      GoRoute(
        path: '/recordings/player/:id',
        builder: (BuildContext context, GoRouterState state) {
          return RecordingPlayerScreen(
            recordingId: state.pathParameters['id']!,
            title:
                state.uri.queryParameters['title'] ??
                context.l10n.recordingDetailTitle,
            durationSeconds:
                int.tryParse(state.uri.queryParameters['duration'] ?? '') ?? 0,
            startedAt: DateTime.tryParse(
              state.uri.queryParameters['started'] ?? '',
            ),
            localPath: state.uri.queryParameters['path'],
          );
        },
      ),
      // Notifications inbox and preferences are full screen (no bottom bar),
      // as drawn.
      GoRoute(
        path: AppRoutes.notifications,
        builder: (BuildContext context, GoRouterState state) {
          return const NotificationsScreen();
        },
      ),
      GoRoute(
        path: AppRoutes.notificationPreferences,
        builder: (BuildContext context, GoRouterState state) {
          return const NotificationPreferencesScreen();
        },
      ),
      // The Account tab's screens are full screen (no bottom bar), as drawn.
      GoRoute(
        path: AppRoutes.profile,
        builder: (BuildContext context, GoRouterState state) {
          return ProfileScreen(settings: settings);
        },
      ),
      GoRoute(
        path: AppRoutes.language,
        builder: (BuildContext context, GoRouterState state) {
          return LanguageScreen(settings: settings);
        },
      ),
      GoRoute(
        path: AppRoutes.theme,
        builder: (BuildContext context, GoRouterState state) {
          return ThemeScreen(settings: settings);
        },
      ),
      GoRoute(
        path: AppRoutes.help,
        builder: (BuildContext context, GoRouterState state) {
          return const HelpCenterScreen();
        },
      ),
      GoRoute(
        path: AppRoutes.report,
        builder: (BuildContext context, GoRouterState state) {
          return const ReportScreen();
        },
        routes: <RouteBase>[
          GoRoute(
            path: 'sent',
            builder: (BuildContext context, GoRouterState state) {
              return ReportSentScreen(
                reference: state.uri.queryParameters['ref'] ?? '',
                email: state.uri.queryParameters['email'] ?? '',
              );
            },
          ),
        ],
      ),
      GoRoute(
        path: AppRoutes.legalHub,
        builder: (BuildContext context, GoRouterState state) {
          return const LegalScreen();
        },
      ),
      GoRoute(
        path: AppRoutes.deleteAccount,
        builder: (BuildContext context, GoRouterState state) {
          return DeleteAccountScreen(session: session);
        },
      ),
      // The v2 player is full screen (no bottom bar), as drawn.
      GoRoute(
        path: '/recordings/:id',
        builder: (BuildContext context, GoRouterState state) {
          return RecordingDetailScreen(
            recordingId: state.pathParameters['id']!,
          );
        },
      ),
      GoRoute(
        path: AppRoutes.componentGallery,
        builder: (BuildContext context, GoRouterState state) {
          return ComponentGalleryScreen(config: config, settings: settings);
        },
      ),
      StatefulShellRoute.indexedStack(
        restorationScopeId: 'main_shell',
        builder:
            (
              BuildContext context,
              GoRouterState state,
              StatefulNavigationShell navigationShell,
            ) {
              return MainShell(
                navigationShell: navigationShell,
                session: session,
              );
            },
        branches: <StatefulShellBranch>[
          StatefulShellBranch(
            restorationScopeId: 'home_branch',
            routes: <RouteBase>[
              GoRoute(
                path: AppRoutes.home,
                builder: (BuildContext context, GoRouterState state) {
                  return const HomeScreen();
                },
              ),
            ],
          ),
          StatefulShellBranch(
            restorationScopeId: 'channels_branch',
            routes: <RouteBase>[
              GoRoute(
                path: AppRoutes.channels,
                builder: (BuildContext context, GoRouterState state) {
                  return const ChannelsScreen();
                },
                routes: <RouteBase>[
                  // The Add channel sheet over the list.
                  GoRoute(
                    path: 'add',
                    builder: (BuildContext context, GoRouterState state) {
                      return const ChannelsScreen(openAddSheet: true);
                    },
                  ),
                  GoRoute(
                    path: ':id/auto-record',
                    builder: (BuildContext context, GoRouterState state) {
                      return AutoRecordSettingsScreen(
                        watchId: state.pathParameters['id']!,
                      );
                    },
                  ),
                  GoRoute(
                    path: ':id',
                    builder: (BuildContext context, GoRouterState state) {
                      return ChannelDetailScreen(
                        watchId: state.pathParameters['id']!,
                      );
                    },
                  ),
                ],
              ),
            ],
          ),
          StatefulShellBranch(
            restorationScopeId: 'recordings_branch',
            routes: <RouteBase>[
              GoRoute(
                path: AppRoutes.recordings,
                builder: (BuildContext context, GoRouterState state) {
                  return const RecordingsScreen();
                },
              ),
            ],
          ),
          StatefulShellBranch(
            restorationScopeId: 'settings_branch',
            routes: <RouteBase>[
              GoRoute(
                path: AppRoutes.settings,
                builder: (BuildContext context, GoRouterState state) {
                  return AccountScreen(
                    settings: settings,
                    session: session,
                    config: config,
                  );
                },
              ),
            ],
          ),
        ],
      ),
    ],
  );
}

class _RouteErrorScreen extends StatelessWidget {
  const _RouteErrorScreen();

  @override
  Widget build(BuildContext context) {
    return SsRoutePlaceholder(
      title: context.l10n.routeErrorTitle,
      message: context.l10n.routeErrorBody,
      action: SsPrimaryButton(
        label: context.l10n.backHomeAction,
        onPressed: () => context.go(AppRoutes.home),
      ),
    );
  }
}
