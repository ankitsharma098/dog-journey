import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:get_it/get_it.dart';

import '../../features/billing/bloc/billing_cubit.dart';
import '../../features/breed_scanner/presentation/screens/breed_scanner_screen.dart';
import '../../features/health_passport/data/repositories/health_record_repository.dart';
import '../../features/health_passport/data/repositories/vaccine_type_repository.dart';
import '../../features/nutrition/data/repositories/food_item_repository.dart';
import '../../features/nutrition/data/repositories/nutrition_repositories.dart';
import '../../features/nutrition/presentation/screens/nutrition_screen.dart';
import '../../features/health_passport/presentation/screens/health_passport_screen.dart';
import '../../features/timeline/data/repositories/timeline_repository.dart';
import '../../features/timeline/presentation/screens/timeline_screen.dart';
import '../../features/vet_chat/data/repositories/chat_repository.dart';
import '../../features/vet_chat/data/services/triage_service.dart';
import '../../features/vet_chat/data/services/vet_ai_service.dart';
import '../../features/vet_chat/presentation/screens/vet_chat_screen.dart';
import '../widgets/nav/pill_bottom_nav.dart';

/// Bottom-nav shell for all v1.0 tabs (PRD modules 1-6).
/// Provides all module repositories via [MultiRepositoryProvider]
/// and the app-scoped [BillingCubit] via [BlocProvider].
class HomeShell extends StatefulWidget {
  const HomeShell({super.key});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int _index = 0;

  static const _screens = [
    HealthPassportScreen(),
    BreedScannerScreen(),
    VetChatScreen(),
    NutritionScreen(),
    TimelineScreen(),
  ];

  static const _items = [
    PillNavItem(icon: Icons.folder_shared_rounded, label: 'Passport'),
    PillNavItem(icon: Icons.camera_alt_rounded, label: 'Scanner'),
    PillNavItem(icon: Icons.chat_bubble_rounded, label: 'Chat'),
    PillNavItem(icon: Icons.restaurant_rounded, label: 'Nutrition'),
    PillNavItem(icon: Icons.photo_library_rounded, label: 'Timeline'),
  ];

  @override
  Widget build(BuildContext context) {
    return MultiRepositoryProvider(
      providers: [
        RepositoryProvider<HealthRecordRepository>.value(
          value: GetIt.I<HealthRecordRepository>(),
        ),
        RepositoryProvider<VaccineTypeRepository>.value(
          value: GetIt.I<VaccineTypeRepository>(),
        ),
        RepositoryProvider<ChatRepository>.value(
          value: GetIt.I<ChatRepository>(),
        ),
        RepositoryProvider<TriageService>.value(
          value: GetIt.I<TriageService>(),
        ),
        RepositoryProvider<VetAiService>.value(
          value: GetIt.I<VetAiService>(),
        ),
        RepositoryProvider<FeedingPlanRepository>.value(
          value: GetIt.I<FeedingPlanRepository>(),
        ),
        RepositoryProvider<FoodLogRepository>.value(
          value: GetIt.I<FoodLogRepository>(),
        ),
        RepositoryProvider<FoodItemRepository>.value(
          value: GetIt.I<FoodItemRepository>(),
        ),
        RepositoryProvider<TimelineRepository>.value(
          value: GetIt.I<TimelineRepository>(),
        ),
      ],
      child: BlocProvider<BillingCubit>.value(
        value: GetIt.I<BillingCubit>(),
        child: _NavScaffold(
          index: _index,
          onTap: (i) => setState(() => _index = i),
        ),
      ),
    );
  }
}

class _NavScaffold extends StatelessWidget {
  const _NavScaffold({required this.index, required this.onTap});
  final int index;
  final ValueChanged<int> onTap;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      extendBody: true,
      body: IndexedStack(
        index: index,
        children: _HomeShellState._screens,
      ),
      bottomNavigationBar: PillBottomNav(
        items: _HomeShellState._items,
        currentIndex: index,
        onTap: onTap,
      ),
    );
  }
}
