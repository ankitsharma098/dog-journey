import '../../../../core/constants/supabase_tables.dart';
import '../../../../core/data/supabase_repository.dart';
import '../../../../core/error/result.dart';
import '../models/pet.dart';

class PetRepository extends SupabaseRepository<Pet> {
  PetRepository({required super.client})
    : super(
        table: SupabaseTables.pets,
        fromJson: Pet.fromJson,
        toJson: (pet) => pet.toJson(),
      );

  /// Every pet the given user owns — HP-9's tier caps read the length
  /// of this list (1 pet free, up to 5 Premium).
  Stream<Result<List<Pet>>> watchOwnedBy(String ownerId) {
    return watchQuery(
      (stream) => stream.eq('owner_id', ownerId).order('created_at', ascending: true),
    );
  }
}
