import 'package:bloc_test/bloc_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:pawjourney/core/data/app_config_repository.dart';
import 'package:pawjourney/core/data/supabase_storage_service.dart';
import 'package:pawjourney/core/di/injector.dart';
import 'package:pawjourney/core/error/result.dart';
import 'package:pawjourney/core/routing/home_shell.dart';
import 'package:pawjourney/core/theme/app_theme.dart';
import 'package:pawjourney/features/auth/bloc/auth_bloc.dart';
import 'package:pawjourney/features/auth/data/models/app_user.dart';
import 'package:pawjourney/features/billing/bloc/billing_cubit.dart';
import 'package:pawjourney/features/breed_scanner/bloc/breed_scan_cubit.dart';
import 'package:pawjourney/features/breed_scanner/data/repositories/breed_repository.dart';
import 'package:pawjourney/features/breed_scanner/data/repositories/scan_quota_repository.dart';
import 'package:pawjourney/features/breed_scanner/data/repositories/scan_repository.dart';
import 'package:pawjourney/features/breed_scanner/data/services/breed_vision_service.dart';
import 'package:pawjourney/features/breed_scanner/data/services/image_prep_service.dart';
import 'package:pawjourney/features/health_passport/data/repositories/health_record_repository.dart';
import 'package:pawjourney/features/health_passport/data/repositories/vaccine_type_repository.dart';
import 'package:pawjourney/features/nutrition/data/repositories/food_item_repository.dart';
import 'package:pawjourney/features/nutrition/data/repositories/nutrition_repositories.dart';
import 'package:pawjourney/features/pets/bloc/pets_bloc.dart';
import 'package:pawjourney/features/pets/data/repositories/pet_repository.dart';
import 'package:pawjourney/features/timeline/data/repositories/timeline_repository.dart';
import 'package:pawjourney/features/vet_chat/data/repositories/chat_repository.dart';
import 'package:pawjourney/features/vet_chat/data/services/triage_service.dart';
import 'package:pawjourney/features/vet_chat/data/services/vet_ai_service.dart';

class MockAuthBloc extends MockBloc<AuthEvent, AuthState> implements AuthBloc {}
class MockPetsBloc extends MockBloc<PetsEvent, PetsState> implements PetsBloc {}
class MockBillingCubit extends MockCubit<BillingState> implements BillingCubit {}

class MockImagePrepService extends Mock implements ImagePrepService {}
class MockScanRepository extends Mock implements ScanRepository {}
class MockScanQuotaRepository extends Mock implements ScanQuotaRepository {}
class MockBreedVisionService extends Mock implements BreedVisionService {}
class MockBreedRepository extends Mock implements BreedRepository {}
class MockAppConfigRepository extends Mock implements AppConfigRepository {}
class MockPetRepository extends Mock implements PetRepository {}
class MockSupabaseStorageService extends Mock implements SupabaseStorageService {}

class MockHealthRecordRepository extends Mock implements HealthRecordRepository {}
class MockVaccineTypeRepository extends Mock implements VaccineTypeRepository {}
class MockChatRepository extends Mock implements ChatRepository {}
class MockTriageService extends Mock implements TriageService {}
class MockVetAiService extends Mock implements VetAiService {}
class MockFeedingPlanRepository extends Mock implements FeedingPlanRepository {}
class MockFoodLogRepository extends Mock implements FoodLogRepository {}
class MockFoodItemRepository extends Mock implements FoodItemRepository {}
class MockTimelineRepository extends Mock implements TimelineRepository {}

void main() {
  late MockAuthBloc authBloc;
  late MockPetsBloc petsBloc;
  late MockBillingCubit billingCubit;

  setUp(() {
    authBloc = MockAuthBloc();
    petsBloc = MockPetsBloc();
    billingCubit = MockBillingCubit();

    final mockTriage = MockTriageService();
    when(() => mockTriage.preload()).thenAnswer((_) async {});

    final mockChatRepo = MockChatRepository();
    when(() => mockChatRepo.getThreads())
        .thenAnswer((_) async => const Result.ok([]));

    final mockFoodRepo = MockFoodItemRepository();
    when(() => mockFoodRepo.all()).thenAnswer((_) async => []);

    final mockFeedingRepo = MockFeedingPlanRepository();
    final mockFoodLogRepo = MockFoodLogRepository();
    final mockTimelineRepo = MockTimelineRepository();

    when(() => authBloc.state).thenReturn(
      const AuthAuthenticated(AppUser(uid: 'test-uid', email: 'test@example.com')),
    );
    when(() => petsBloc.state).thenReturn(
      const PetsState(status: PetsStatus.loaded, pets: []),
    );
    when(() => billingCubit.state).thenReturn(
      const BillingState(status: BillingStatus.free),
    );

    getIt.registerLazySingleton<HealthRecordRepository>(() => MockHealthRecordRepository());
    getIt.registerLazySingleton<VaccineTypeRepository>(() => MockVaccineTypeRepository());
    getIt.registerLazySingleton<ChatRepository>(() => mockChatRepo);
    getIt.registerLazySingleton<TriageService>(() => mockTriage);
    getIt.registerLazySingleton<VetAiService>(() => MockVetAiService());
    getIt.registerLazySingleton<FeedingPlanRepository>(() => mockFeedingRepo);
    getIt.registerLazySingleton<FoodLogRepository>(() => mockFoodLogRepo);
    getIt.registerLazySingleton<FoodItemRepository>(() => mockFoodRepo);
    getIt.registerLazySingleton<TimelineRepository>(() => mockTimelineRepo);
    getIt.registerLazySingleton<BillingCubit>(() => billingCubit);

    getIt.registerFactoryParam<BreedScanCubit, String, void>(
      (ownerId, _) => BreedScanCubit(
        ownerId: ownerId,
        imagePrepService: MockImagePrepService(),
        scanRepository: MockScanRepository(),
        scanQuotaRepository: MockScanQuotaRepository(),
        breedVisionService: MockBreedVisionService(),
        breedRepository: MockBreedRepository(),
        appConfigRepository: MockAppConfigRepository(),
        petRepository: MockPetRepository(),
        storageService: MockSupabaseStorageService(),
      ),
    );
  });

  tearDown(getIt.reset);

  testWidgets('Home shell renders all tabs and switches between them', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: MultiBlocProvider(
          providers: [
            BlocProvider<AuthBloc>.value(value: authBloc),
            BlocProvider<PetsBloc>.value(value: petsBloc),
          ],
          child: const HomeShell(),
        ),
      ),
    );

    expect(find.text('Health Passport'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.camera_alt_rounded));
    await tester.pumpAndSettle();
    expect(find.text('Breed Scanner'), findsOneWidget);
  });
}
