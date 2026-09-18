import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'core/di/injector.dart';
import 'core/routing/app_router.dart';
import 'core/theme/app_theme.dart';
import 'core/theme/theme_cubit.dart';
import 'features/auth/bloc/auth_bloc.dart';
import 'features/billing/bloc/billing_cubit.dart';
import 'features/breed_scanner/data/repositories/breed_repository.dart';
import 'features/health_passport/data/repositories/health_record_repository.dart';
import 'features/health_passport/data/repositories/vaccine_type_repository.dart';
import 'features/pets/bloc/pets_bloc.dart';
import 'features/timeline/data/repositories/timeline_repository.dart';

/// Repositories and cubits that a screen pushed with `Navigator.push`
/// (Settings, Care calendar, Story — see [HomeShell]) can rely on, since
/// a pushed route lands as a *sibling* of the current page's widget
/// tree, not a descendant of it: anything only provided inside
/// [HomeShell]'s own build method would be invisible to it. Repos used
/// exclusively by tabs that stay nested inside `HomeShell`'s
/// `IndexedStack` (chat, nutrition) don't need to live here.
class PawJourneyApp extends StatelessWidget {
  const PawJourneyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiRepositoryProvider(
      providers: [
        RepositoryProvider<HealthRecordRepository>.value(
          value: getIt<HealthRecordRepository>(),
        ),
        RepositoryProvider<VaccineTypeRepository>.value(
          value: getIt<VaccineTypeRepository>(),
        ),
        RepositoryProvider<TimelineRepository>.value(
          value: getIt<TimelineRepository>(),
        ),
        RepositoryProvider<BreedRepository>.value(
          value: getIt<BreedRepository>(),
        ),
      ],
      child: MultiBlocProvider(
        providers: [
          BlocProvider<AuthBloc>.value(value: getIt<AuthBloc>()),
          BlocProvider<PetsBloc>.value(value: getIt<PetsBloc>()),
          BlocProvider<BillingCubit>.value(value: getIt<BillingCubit>()),
          BlocProvider<ThemeCubit>.value(value: getIt<ThemeCubit>()),
        ],
        child: BlocListener<AuthBloc, AuthState>(
          // Links RevenueCat's entitlement lookup to our own user id
          // instead of its device-local anonymous id, so "already
          // Pro" is recognized consistently across reinstalls/devices
          // for the same account. See BillingCubit.identify/.reset.
          listener: (context, state) {
            final billing = context.read<BillingCubit>();
            if (state is AuthAuthenticated) {
              billing.identify(state.profile.uid);
            } else if (state is AuthUnauthenticated) {
              billing.reset();
            }
          },
          child: BlocBuilder<ThemeCubit, ThemeMode>(
            builder: (context, themeMode) => MaterialApp.router(
              title: 'PawJourney',
              debugShowCheckedModeBanner: false,
              theme: AppTheme.light,
              darkTheme: AppTheme.dark,
              themeMode: themeMode,
              routerConfig: appRouter,
            ),
          ),
        ),
      ),
    );
  }
}
