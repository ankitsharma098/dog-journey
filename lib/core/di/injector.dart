import 'package:get_it/get_it.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../features/auth/bloc/auth_bloc.dart';
import '../../features/auth/bloc/sign_in_cubit.dart';
import '../../features/auth/bloc/sign_up_cubit.dart';
import '../../features/auth/data/repositories/auth_repository.dart';
import '../../features/auth/data/repositories/user_repository.dart';
import '../../features/billing/bloc/billing_cubit.dart';
import '../../features/breed_scanner/bloc/breed_scan_cubit.dart';
import '../../features/breed_scanner/data/repositories/breed_repository.dart';
import '../../features/breed_scanner/data/repositories/scan_quota_repository.dart';
import '../../features/breed_scanner/data/repositories/scan_repository.dart';
import '../../features/breed_scanner/data/services/breed_vision_service.dart';
import '../../features/breed_scanner/data/services/image_prep_service.dart';
import '../../features/health_passport/data/repositories/health_record_repository.dart';
import '../../features/health_passport/data/repositories/vaccine_type_repository.dart';
import '../../features/nutrition/data/repositories/food_item_repository.dart';
import '../../features/nutrition/data/repositories/nutrition_repositories.dart';
import '../../features/pets/bloc/add_pet_cubit.dart';
import '../../features/pets/bloc/pets_bloc.dart';
import '../../features/pets/data/repositories/pet_repository.dart';
import '../../features/timeline/data/repositories/timeline_repository.dart';
import '../../features/vet_chat/data/repositories/chat_repository.dart';
import '../../features/vet_chat/data/services/triage_service.dart';
import '../../features/vet_chat/data/services/vet_ai_service.dart';
import '../data/app_config_repository.dart';
import '../data/supabase_storage_service.dart';
import '../services/notification_service.dart';

final GetIt getIt = GetIt.instance;

/// Called once from main() after Supabase.initialize(). Feature
/// repositories register themselves here as each feature is built —
/// this only owns the cross-cutting singletons every feature needs.
void setupInjector() {
  getIt.registerLazySingleton<SupabaseClient>(() => Supabase.instance.client);
  getIt.registerLazySingleton<NotificationService>(
    () => NotificationService.instance,
  );
  getIt.registerLazySingleton<AppConfigRepository>(
    () => AppConfigRepository(client: getIt()),
  );
  getIt.registerLazySingleton<SupabaseStorageService>(
    () => SupabaseStorageService(client: getIt()),
  );

  // Auth — one repository pair and one AuthBloc for the whole app
  // session; sign-in/sign-up cubits are screen-scoped, so they're
  // factories (a fresh instance per screen visit).
  getIt.registerLazySingleton<UserRepository>(
    () => UserRepository(client: getIt()),
  );
  getIt.registerLazySingleton<AuthRepository>(
    () => AuthRepository(client: getIt(), userRepository: getIt()),
  );
  getIt.registerLazySingleton<AuthBloc>(
    () => AuthBloc(authRepository: getIt())..add(const AuthSubscriptionRequested()),
  );
  getIt.registerFactory<SignInCubit>(() => SignInCubit(authRepository: getIt()));
  getIt.registerFactory<SignUpCubit>(() => SignUpCubit(authRepository: getIt()));

  // Pets — one repository and one PetsBloc for the whole app session
  // (it tracks its own auth subscription, same pattern as AuthBloc).
  // AddPetCubit is a factory parameterised by the owner's uid.
  getIt.registerLazySingleton<PetRepository>(
    () => PetRepository(client: getIt()),
  );
  getIt.registerLazySingleton<PetsBloc>(
    () => PetsBloc(petRepository: getIt(), authBloc: getIt())
      ..add(const PetsSubscriptionRequested()),
  );
  getIt.registerFactoryParam<AddPetCubit, String, void>(
    (ownerId, _) => AddPetCubit(
      petRepository: getIt(),
      userRepository: getIt(),
      ownerId: ownerId,
    ),
  );

  // Breed scanner — BreedRepository is the bundled `breeds.json`
  // reference table, loaded once and cached; ScanRepository/
  // ScanQuotaRepository are the Postgres side. BreedScanCubit is a
  // screen-scoped factory (see pets_bloc.dart's AddPetCubit comment
  // for the same pattern).
  getIt.registerLazySingleton<BreedRepository>(() => BreedRepository());
  getIt.registerLazySingleton<ScanRepository>(
    () => ScanRepository(client: getIt()),
  );
  getIt.registerLazySingleton<ScanQuotaRepository>(
    () => ScanQuotaRepository(client: getIt()),
  );
  getIt.registerLazySingleton<ImagePrepService>(() => ImagePrepService());
  getIt.registerLazySingleton<BreedVisionService>(
    () => BreedVisionService(appConfigRepository: getIt()),
  );
  getIt.registerFactoryParam<BreedScanCubit, String, void>(
    (ownerId, _) => BreedScanCubit(
      ownerId: ownerId,
      imagePrepService: getIt(),
      scanRepository: getIt(),
      scanQuotaRepository: getIt(),
      breedVisionService: getIt(),
      breedRepository: getIt(),
      appConfigRepository: getIt(),
      petRepository: getIt(),
      storageService: getIt(),
    ),
  );

  // ── Module 2: Health Passport ────────────────────────────────────────────
  getIt.registerLazySingleton<VaccineTypeRepository>(
    () => VaccineTypeRepository(),
  );
  getIt.registerLazySingleton<HealthRecordRepository>(
    () => HealthRecordRepository(client: getIt()),
  );

  // ── Module 3: AI Vet Chat ────────────────────────────────────────────────
  getIt.registerLazySingleton<TriageService>(() => TriageService());
  getIt.registerLazySingleton<VetAiService>(
    () => VetAiService(appConfigRepository: getIt()),
  );
  getIt.registerLazySingleton<ChatRepository>(
    () => ChatRepository(client: getIt()),
  );

  // ── Module 4: Nutrition ──────────────────────────────────────────────────
  getIt.registerLazySingleton<FoodItemRepository>(() => FoodItemRepository());
  getIt.registerLazySingleton<FeedingPlanRepository>(
    () => FeedingPlanRepository(
      client: getIt(),
      appConfigRepository: getIt(),
    ),
  );
  getIt.registerLazySingleton<FoodLogRepository>(
    () => FoodLogRepository(client: getIt()),
  );

  // ── Module 5: Memory Timeline ────────────────────────────────────────────
  getIt.registerLazySingleton<TimelineRepository>(
    () => TimelineRepository(client: getIt()),
  );

  // ── Module 6: Billing ────────────────────────────────────────────────────
  // BillingCubit is app-scoped (RevenueCat subscription listener).
  getIt.registerLazySingleton<BillingCubit>(() => BillingCubit());
}
