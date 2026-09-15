import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';

import '../../features/auth/bloc/auth_bloc.dart';
import '../../features/auth/presentation/screens/sign_in_screen.dart';
import '../../features/auth/presentation/screens/sign_up_screen.dart';
import '../../features/pets/bloc/pets_bloc.dart';
import '../../features/pets/presentation/screens/add_pet_screen.dart';
import '../di/injector.dart';
import 'go_router_refresh_stream.dart';
import 'home_shell.dart';
import 'splash_screen.dart';

abstract final class AppRoutes {
  static const String splash = '/';
  static const String signIn = '/sign-in';
  static const String signUp = '/sign-up';
  static const String addPet = '/add-pet';
  static const String home = '/home';
}

final GoRouter appRouter = GoRouter(
  initialLocation: AppRoutes.splash,
  refreshListenable: Listenable.merge([
    GoRouterRefreshStream(getIt<AuthBloc>().stream),
    GoRouterRefreshStream(getIt<PetsBloc>().stream),
  ]),
  redirect: (context, state) {
    final authState = getIt<AuthBloc>().state;
    final path = state.matchedLocation;
    final onAuthRoute = path == AppRoutes.signIn || path == AppRoutes.signUp;

    if (authState is AuthInitial) {
      return path == AppRoutes.splash ? null : AppRoutes.splash;
    }
    if (authState is AuthUnauthenticated) {
      return onAuthRoute ? null : AppRoutes.signIn;
    }

    // AuthAuthenticated from here — onboarding gate: no pets yet means
    // add-pet, same way "no session" means sign-in above.
    final petsState = getIt<PetsBloc>().state;
    if (petsState.status == PetsStatus.unknown) {
      return path == AppRoutes.splash ? null : AppRoutes.splash;
    }
    if (!petsState.hasPets) {
      return path == AppRoutes.addPet ? null : AppRoutes.addPet;
    }
    final onEntryRoute = path == AppRoutes.splash || onAuthRoute || path == AppRoutes.addPet;
    return onEntryRoute ? AppRoutes.home : null;
  },
  routes: [
    GoRoute(
      path: AppRoutes.splash,
      builder: (context, state) => const SplashScreen(),
    ),
    GoRoute(
      path: AppRoutes.signIn,
      builder: (context, state) => const SignInScreen(),
    ),
    GoRoute(
      path: AppRoutes.signUp,
      builder: (context, state) => const SignUpScreen(),
    ),
    GoRoute(
      path: AppRoutes.addPet,
      builder: (context, state) => const AddPetScreen(),
    ),
    GoRoute(
      path: AppRoutes.home,
      builder: (context, state) => const HomeShell(),
    ),
  ],
);
