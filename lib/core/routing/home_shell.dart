import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:get_it/get_it.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../../features/auth/bloc/auth_bloc.dart';
import '../../features/billing/bloc/billing_cubit.dart';
import '../../features/billing/presentation/screens/paywall_sheet.dart';
import '../../features/breed_scanner/presentation/screens/breed_scanner_screen.dart';
import '../../features/health_passport/bloc/health_passport_cubit.dart';
import '../../features/health_passport/data/repositories/health_record_repository.dart';
import '../../features/health_passport/data/repositories/vaccine_type_repository.dart';
import '../../features/health_passport/presentation/screens/add_health_record_sheet.dart';
import '../../features/health_passport/presentation/screens/care_calendar_screen.dart';
import '../../features/health_passport/presentation/screens/health_passport_screen.dart';
import '../../features/home/presentation/screens/home_screen.dart';
import '../../features/nutrition/data/repositories/food_item_repository.dart';
import '../../features/nutrition/data/repositories/nutrition_repositories.dart';
import '../../features/nutrition/presentation/screens/nutrition_screen.dart';
import '../../features/pets/bloc/pets_bloc.dart';
import '../../features/settings/presentation/screens/settings_screen.dart';
import '../../features/timeline/bloc/timeline_cubit.dart';
import '../../features/timeline/data/repositories/timeline_repository.dart';
import '../../features/timeline/presentation/screens/add_timeline_entry_sheet.dart';
import '../../features/timeline/presentation/screens/timeline_screen.dart';
import '../../features/vet_chat/data/repositories/chat_repository.dart';
import '../../features/vet_chat/data/services/triage_service.dart';
import '../../features/vet_chat/data/services/vet_ai_service.dart';
import '../../features/vet_chat/presentation/screens/vet_chat_screen.dart';
import '../data/supabase_storage_service.dart';
import '../widgets/nav/pill_bottom_nav.dart';
import '../widgets/royal/action_sheet.dart';

/// Bottom-nav shell — four tabs plus a centre FAB (Home · Passport ·
/// ＋ · Nutrition · Chat). The FAB opens an action sheet; Breed
/// Scanner is a pushed route from there, not a tab. See
/// design-ref/design_handoff_royal_redesign/README.md § Navigation.
class HomeShell extends StatefulWidget {
  const HomeShell({super.key});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int _index = 0;

  static const _items = [
    PillNavItem(
      icon: PhosphorIconsRegular.house,
      activeIcon: PhosphorIconsFill.house,
      label: 'Home',
    ),
    PillNavItem(
      icon: PhosphorIconsRegular.identificationCard,
      activeIcon: PhosphorIconsFill.identificationCard,
      label: 'Passport',
    ),
    PillNavItem(
      icon: PhosphorIconsRegular.forkKnife,
      activeIcon: PhosphorIconsFill.forkKnife,
      label: 'Nutrition',
    ),
    PillNavItem(
      icon: PhosphorIconsRegular.chatTeardropDots,
      activeIcon: PhosphorIconsFill.chatTeardropDots,
      label: 'Chat',
    ),
  ];

  void _setIndex(int i) => setState(() => _index = i);

  void _push(BuildContext context, Widget screen) {
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => screen));
  }

  void _openPaywall(BuildContext context) {
    // Read before opening, not inside `builder` — that closure can
    // re-run against a deactivated context (see nutrition_screen.dart's
    // _GeneratePlanCta for the crash this caused there).
    final billingCubit = context.read<BillingCubit>();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) =>
          BlocProvider.value(value: billingCubit, child: const PaywallSheet()),
    );
  }

  void _openActionSheet(BuildContext context) {
    showRoyalActionSheet(
      context,
      items: [
        RoyalActionSheetItem(
          icon: PhosphorIconsFill.camera,
          title: 'Scan a breed',
          subtitle: 'Point the camera at your dog',
          onTap: () => _push(context, const BreedScannerScreen()),
        ),
        RoyalActionSheetItem(
          icon: PhosphorIconsFill.syringe,
          title: 'Add a health record',
          subtitle: 'Vaccine, vet visit, medication or weight',
          onTap: () => _openAddHealthRecordSheet(context),
        ),
        RoyalActionSheetItem(
          icon: PhosphorIconsFill.bowlFood,
          title: 'Log food',
          subtitle: 'Track a meal or a treat',
          onTap: () => _setIndex(2),
        ),
        RoyalActionSheetItem(
          icon: PhosphorIconsFill.images,
          title: 'Add a memory',
          subtitle: 'A photo for the story',
          onTap: () => _openAddMemorySheet(context),
        ),
      ],
    );
  }

  void _openAddHealthRecordSheet(BuildContext context) {
    final pet = context.read<PetsBloc>().state.activePet;
    if (pet == null) return;
    final authState = context.read<AuthBloc>().state;
    final userId = authState is AuthAuthenticated ? authState.profile.uid : '';
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => BlocProvider(
        create: (_) => HealthPassportCubit(
          petId: pet.id,
          currentUserId: userId,
          healthRecordRepository: context.read<HealthRecordRepository>(),
          vaccineTypeRepository: context.read<VaccineTypeRepository>(),
        ),
        child: const AddHealthRecordSheet(),
      ),
    );
  }

  void _openAddMemorySheet(BuildContext context) {
    final pet = context.read<PetsBloc>().state.activePet;
    if (pet == null) return;
    final authState = context.read<AuthBloc>().state;
    final userId = authState is AuthAuthenticated ? authState.profile.uid : '';
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => BlocProvider(
        create: (_) => TimelineCubit(
          petId: pet.id,
          currentUserId: userId,
          timelineRepository: context.read<TimelineRepository>(),
          storageService: GetIt.I<SupabaseStorageService>(),
        ),
        child: const AddTimelineEntrySheet(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // HealthRecordRepository, VaccineTypeRepository, TimelineRepository,
    // BreedRepository and BillingCubit are provided at the app root
    // (see PawJourneyApp) rather than here — screens reachable via
    // Navigator.push from this shell (Settings, Care calendar, Story)
    // land as sibling pages, not descendants of this build method, so
    // a provider scoped only to this subtree would be invisible to them.
    return MultiRepositoryProvider(
      providers: [
        RepositoryProvider<ChatRepository>.value(
          value: GetIt.I<ChatRepository>(),
        ),
        RepositoryProvider<TriageService>.value(
          value: GetIt.I<TriageService>(),
        ),
        RepositoryProvider<VetAiService>.value(value: GetIt.I<VetAiService>()),
        RepositoryProvider<FeedingPlanRepository>.value(
          value: GetIt.I<FeedingPlanRepository>(),
        ),
        RepositoryProvider<FoodLogRepository>.value(
          value: GetIt.I<FoodLogRepository>(),
        ),
        RepositoryProvider<FoodItemRepository>.value(
          value: GetIt.I<FoodItemRepository>(),
        ),
      ],
      child: Builder(
        builder: (context) => Scaffold(
          backgroundColor: Colors.transparent,
          extendBody: true,
          body: IndexedStack(
            index: _index,
            children: [
              HomeScreen(
                onOpenPassport: () => _setIndex(1),
                onOpenNutrition: () => _setIndex(2),
                onOpenChat: () => _setIndex(3),
                onOpenSettings: () => _push(context, const SettingsScreen()),
                onOpenCareCalendar: () =>
                    _push(context, const CareCalendarScreen()),
                onOpenStory: () => _push(context, const TimelineScreen()),
                onOpenPaywall: () => _openPaywall(context),
              ),
              const HealthPassportScreen(),
              const NutritionScreen(),
              const VetChatScreen(),
            ],
          ),
          bottomNavigationBar: PillBottomNav(
            items: _items,
            currentIndex: _index,
            onTap: _setIndex,
            onFabTap: () => _openActionSheet(context),
          ),
        ),
      ),
    );
  }
}
