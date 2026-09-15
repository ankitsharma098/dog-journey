import '../../../../core/constants/supabase_tables.dart';
import '../../../../core/data/supabase_repository.dart';
import '../models/app_user.dart';

/// The `users` half of a signed-in identity — see [AuthRepository] for
/// the Supabase Auth half.
class UserRepository extends SupabaseRepository<AppUser> {
  UserRepository({required super.client})
    : super(
        table: SupabaseTables.users,
        fromJson: AppUser.fromJson,
        toJson: (user) => user.toJson(),
      );
}
