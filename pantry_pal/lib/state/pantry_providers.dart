import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/database.dart';
import '../models/pantry_item.dart';

/// The single pantry database instance, injected so widgets/tests can override
/// it. Wraps the runtime `pantry.db` (user data — never bundled).
final pantryDatabaseProvider = Provider<PantryDatabase>((ref) {
  return PantryDatabase.instance;
});

/// Active pantry items (not consumed), sorted by soonest expiry.
///
/// This is the single source of truth for the list UI. Mutations go through the
/// methods here, each of which refreshes the state so every screen stays in
/// sync without manual reloads.
final pantryItemsProvider =
    AsyncNotifierProvider<PantryItemsNotifier, List<PantryItem>>(
  PantryItemsNotifier.new,
);

class PantryItemsNotifier extends AsyncNotifier<List<PantryItem>> {
  PantryDatabase get _db => ref.read(pantryDatabaseProvider);

  @override
  Future<List<PantryItem>> build() => _db.all();

  Future<void> refresh() async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(_db.all);
  }

  Future<int> add(PantryItem item) async {
    final id = await _db.insert(item);
    await refresh();
    return id;
  }

  Future<void> updateItem(PantryItem item) async {
    await _db.update(item);
    await refresh();
  }

  Future<void> delete(int id) async {
    await _db.delete(id);
    await refresh();
  }

  Future<void> setConsumed(int id, bool consumed) async {
    await _db.setConsumed(id, consumed);
    await refresh();
  }
}
