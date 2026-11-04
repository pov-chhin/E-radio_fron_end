import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../data/repositories/media_content_repository.dart';
import '../../views/screens/category/category_view.dart';
import '../../views/screens/explore/all_stations_view.dart';
import '../../views/screens/explore/explore_view.dart';
import '../../views/screens/explore/jump_back_in_view.dart';
import '../../views/screens/explore/media_feed_view.dart';
import '../../views/screens/favorites/favorites_view.dart';
import '../../views/screens/notifications/notifications_inbox_view.dart';
import '../../views/screens/onboarding/onboarding_view.dart';
import '../../views/screens/password_reset/enter_code_view.dart';
import '../../views/screens/password_reset/forgot_password_view.dart';
import '../../data/models/password_reset_args.dart';
import '../../views/screens/password_reset/reset_password_view.dart';
import '../../views/screens/player/now_playing_view.dart';
import '../../views/screens/player/play_queue_view.dart';
import '../../views/screens/music/ambient_music_view.dart';
import '../../views/screens/music/music_view.dart';
import '../../views/screens/podcasts/podcast_show_view.dart';
import '../../views/screens/podcasts/podcasts_view.dart';
import '../../providers/auth_controller.dart';
import '../../views/screens/profile/change_password_view.dart';
import '../../views/screens/profile/edit_profile_view.dart';
import '../../views/screens/profile/language_view.dart';
import '../../views/screens/profile/login_view.dart';
import '../../views/screens/profile/notifications_view.dart';
import '../../views/screens/profile/privacy_policy_view.dart';
import '../../views/screens/profile/profile_view.dart';
import '../../views/screens/profile/signup_view.dart';
import '../../views/screens/search/search_view.dart';
import '../../views/screens/welcome/welcome_view.dart';
import '../../l10n/gen/app_localizations.dart';
import '../../views/widgets/shared/app_shell.dart';
import '../../providers/has_seen_onboarding_provider.dart';
import 'category_pages.dart';

final appRouterProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    initialLocation: '/onboarding',
    redirect: (context, state) {
      final isSignedIn = ref.read(authControllerProvider) != null;
      if (state.matchedLocation == '/onboarding') {
        final hasSeenOnboarding = ref.read(hasSeenOnboardingProvider);
        if (hasSeenOnboarding || isSignedIn) return '/explore';
      }
      // The optional sign-up is pointless once you're signed in.
      if (state.matchedLocation == '/welcome' && isSignedIn) return '/explore';
      return null;
    },
    routes: [
      GoRoute(
        path: '/onboarding',
        builder: (context, state) => const OnboardingView(),
      ),
      GoRoute(
        path: '/welcome',
        builder: (context, state) => const WelcomeView(),
      ),
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) =>
            AppShell(navigationShell: navigationShell),
        branches: [
          // Discover and every page that opens from it (See All, Search,
          // Notifications, On Air Now) share one branch, so the tab bar and
          // player stay under them and Discover stays the lit tab.
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/explore',
                builder: (context, state) => const ExploreView(),
              ),
              GoRoute(
                path: '/search',
                builder: (context, state) => const Scaffold(body: SearchView()),
              ),
              // Jump Back In's See All.
              GoRoute(
                path: '/library',
                builder: (context, state) => const JumpBackInView(),
              ),
              GoRoute(
                path: '/notifications',
                builder: (context, state) => const NotificationsInboxView(),
              ),
              GoRoute(
                path: '/stations',
                builder: (context, state) => const AllStationsView(),
              ),
              GoRoute(
                path: '/trending',
                builder: (context, state) => MediaFeedView(
                  title: AppLocalizations.of(context)!.trendingProgram,
                  provider: trendingProgramMediaContentsProvider,
                ),
              ),
              GoRoute(
                path: '/new-release',
                builder: (context, state) => MediaFeedView(
                  title: AppLocalizations.of(context)!.newRelease,
                  provider: newReleaseMediaContentsProvider,
                ),
              ),
              GoRoute(
                path: '/category/:slug',
                redirect: (context, state) =>
                    categoryPages[state.pathParameters['slug']],
                builder: (context, state) =>
                    CategoryView(categorySlug: state.pathParameters['slug']!),
              ),
            ],
          ),
          // Podcasts and Music keep their own pages (a show, Ambient Music)
          // inside the tab, so the bar stays under them.
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/podcasts',
                builder: (context, state) => const PodcastsView(),
                routes: [
                  GoRoute(
                    path: ':id',
                    builder: (context, state) =>
                        PodcastShowView(programId: state.pathParameters['id']!),
                  ),
                ],
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/music',
                builder: (context, state) => const MusicView(),
                routes: [
                  GoRoute(
                    path: 'ambient',
                    builder: (context, state) => AmbientMusicView(
                      initialTagSlug: state.uri.queryParameters['tag'],
                    ),
                  ),
                ],
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/favorites',
                builder: (context, state) => const FavoritesView(),
              ),
            ],
          ),
        ],
      ),
      // Slides up over the page when opened and back down when the ⌄ (or back)
      // closes it, like a player sheet.
      GoRoute(
        path: '/now-playing',
        pageBuilder: (context, state) => CustomTransitionPage(
          key: state.pageKey,
          child: const NowPlayingView(),
          transitionDuration: const Duration(milliseconds: 350),
          reverseTransitionDuration: const Duration(milliseconds: 300),
          transitionsBuilder: (context, animation, secondaryAnimation, child) =>
              SlideTransition(
                position: Tween(begin: const Offset(0, 1), end: Offset.zero)
                    .animate(
                      CurvedAnimation(
                        parent: animation,
                        curve: Curves.easeOutCubic,
                        reverseCurve: Curves.easeInCubic,
                      ),
                    ),
                child: child,
              ),
        ),
      ),
      // Now Playing's ⋮: the list of what is playing.
      GoRoute(
        path: '/play-list',
        builder: (context, state) => const PlayQueueView(),
      ),
      GoRoute(
        path: '/profile',
        builder: (context, state) => const ProfileView(),
        routes: [
          GoRoute(
            path: 'login',
            builder: (context, state) => const LoginView(),
          ),
          GoRoute(
            path: 'signup',
            builder: (context, state) => const SignUpView(),
          ),
          GoRoute(
            path: 'edit',
            builder: (context, state) => const EditProfileView(),
          ),
          GoRoute(
            path: 'change-password',
            builder: (context, state) => const ChangePasswordView(),
          ),
          GoRoute(
            path: 'language',
            builder: (context, state) => const LanguageView(),
          ),
          GoRoute(
            path: 'notifications',
            builder: (context, state) => const NotificationsView(),
          ),
          GoRoute(
            path: 'privacy-policy',
            builder: (context, state) => const PrivacyPolicyView(),
          ),
          GoRoute(
            path: 'forgot-password',
            builder: (context, state) => ForgotPasswordView(
              initialEmail: state.extra is String
                  ? state.extra as String
                  : null,
            ),
            routes: [
              // Each step needs what the one before it produced; reached any
              // other way (a stale link, a restored session) they start over.
              GoRoute(
                path: 'code',
                builder: (context, state) {
                  final args = state.extra;
                  return args is ResetCodeArgs
                      ? EnterCodeView(args: args)
                      : const ForgotPasswordView();
                },
              ),
              GoRoute(
                path: 'reset',
                builder: (context, state) {
                  final args = state.extra;
                  return args is ResetPasswordArgs
                      ? ResetPasswordView(args: args)
                      : const ForgotPasswordView();
                },
              ),
            ],
          ),
        ],
      ),
    ],
  );
});
