import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/config/app_config.dart';
import '../../core/widgets/savestream_widgets.dart';
import '../../features/auth/data/auth_providers.dart';
import '../../features/auth/presentation/forgot_password_screen.dart';
import '../../features/auth/presentation/register_screen.dart';
import '../../features/auth/presentation/reset_password_screen.dart';
import '../../features/auth/presentation/sign_in_screen.dart';
import '../../features/auth/presentation/verify_email_screen.dart';
import '../../features/billing/presentation/billing_return_screen.dart';
import '../../features/billing/presentation/billing_screen.dart';
import '../../features/channels/presentation/add_channel_screen.dart';
import '../../features/channels/presentation/channel_detail_screen.dart';
import '../../features/channels/presentation/channels_screen.dart';
import '../../features/credits/presentation/credits_screen.dart';
import '../../features/design_system/presentation/component_gallery_screen.dart';
import '../../features/home/presentation/home_screen.dart';
import '../../features/onboarding/presentation/onboarding_screen.dart';
import '../../features/recordings/presentation/recording_detail_screen.dart';
import '../../features/recordings/presentation/recordings_screen.dart';
import '../../features/settings/presentation/language_screen.dart';
import '../../features/settings/presentation/legal_link_screen.dart';
import '../../features/settings/presentation/notification_settings_screen.dart';
import '../../features/settings/presentation/profile_screen.dart';
import '../../features/settings/presentation/settings_screen.dart';
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
    refreshListenable: session,
    redirect: (BuildContext context, GoRouterState state) {
      final String location = state.matchedLocation;
      final bool isOnboarding = location == AppRoutes.onboarding;
      final bool isAuth = location.startsWith('/auth/');
      final bool isSplash = location == AppRoutes.splash;

      if (!session.hasCompletedOnboarding) {
        return isOnboarding ? null : AppRoutes.onboarding;
      }

      if (!session.isAuthenticated) {
        return isAuth ? null : AppRoutes.signIn;
      }

      if (isOnboarding || isAuth || isSplash) {
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
        path: AppRoutes.onboarding,
        builder: (BuildContext context, GoRouterState state) {
          return OnboardingScreen(session: session);
        },
      ),
      GoRoute(
        path: AppRoutes.signIn,
        builder: (BuildContext context, GoRouterState state) {
          return Consumer(
            builder: (BuildContext context, WidgetRef ref, Widget? child) {
              return SignInScreen(
                repository: ref.watch(authRepositoryProvider),
                session: session,
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
              );
            },
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
        path: AppRoutes.credits,
        builder: (BuildContext context, GoRouterState state) {
          return const CreditsScreen();
        },
      ),
      GoRoute(
        path: AppRoutes.billing,
        builder: (BuildContext context, GoRouterState state) {
          return BillingScreen(
            externalCheckoutEnabled: config.externalCheckoutEnabled,
          );
        },
        routes: <RouteBase>[
          GoRoute(
            path: 'return',
            builder: (BuildContext context, GoRouterState state) {
              final String? orderId = state.uri.queryParameters['order_id'];
              if (orderId == null || orderId.trim().isEmpty) {
                return const _RouteErrorScreen();
              }
              return BillingReturnScreen(orderId: orderId);
            },
          ),
        ],
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
              return MainShell(navigationShell: navigationShell);
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
                  GoRoute(
                    path: 'add',
                    builder: (BuildContext context, GoRouterState state) {
                      return const AddChannelScreen();
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
                routes: <RouteBase>[
                  GoRoute(
                    path: ':id',
                    builder: (BuildContext context, GoRouterState state) {
                      return RecordingDetailScreen(
                        recordingId: state.pathParameters['id']!,
                      );
                    },
                  ),
                ],
              ),
            ],
          ),
          StatefulShellBranch(
            restorationScopeId: 'settings_branch',
            routes: <RouteBase>[
              GoRoute(
                path: AppRoutes.settings,
                builder: (BuildContext context, GoRouterState state) {
                  return SettingsScreen(
                    settings: settings,
                    session: session,
                    config: config,
                  );
                },
                routes: <RouteBase>[
                  GoRoute(
                    path: 'profile',
                    builder: (BuildContext context, GoRouterState state) {
                      return const ProfileScreen();
                    },
                  ),
                  GoRoute(
                    path: 'language',
                    builder: (BuildContext context, GoRouterState state) {
                      return LanguageScreen(settings: settings);
                    },
                  ),
                  GoRoute(
                    path: 'theme',
                    builder: (BuildContext context, GoRouterState state) {
                      return ThemeScreen(settings: settings);
                    },
                  ),
                  GoRoute(
                    path: 'notifications',
                    builder: (BuildContext context, GoRouterState state) {
                      return const NotificationSettingsScreen();
                    },
                  ),
                  GoRoute(
                    path: 'privacy',
                    builder: (BuildContext context, GoRouterState state) {
                      return LegalLinkScreen(
                        title: context.l10n.privacyPolicyTitle,
                        url: config.privacyPolicyUrl,
                        openLabel: context.l10n.openLegalDocumentAction,
                      );
                    },
                  ),
                  GoRoute(
                    path: 'terms',
                    builder: (BuildContext context, GoRouterState state) {
                      return LegalLinkScreen(
                        title: context.l10n.termsOfUseTitle,
                        url: config.termsOfUseUrl,
                        openLabel: context.l10n.openLegalDocumentAction,
                      );
                    },
                  ),
                ],
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
