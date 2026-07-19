# Bundled assets

All product/recipe data ships **inside the app** — Pantry Pal makes no network
calls at runtime. These files are copied out of the bundle into the app's
databases directory on first launch (see `lib/services/asset_db_installer.dart`).

| File | Status | Produced by |
|------|--------|-------------|
| `products.db` | **placeholder** — 7 sample UK rows | Offline Python script dumping the Open Food Facts UK subset |
| `recipes.db` | **placeholder** — schema only, no rows | Offline Python script that also writes the MiniLM embeddings |
| `miniLmL6V2.onnx` | **missing** — drop the real model here | Export of `sentence-transformers/all-MiniLM-L6-v2` |

## Schemas the app expects

`products.db`:

```sql
products(gtin TEXT PRIMARY KEY, name, brand, quantity, category,
         shelf_life_days INTEGER)   -- NULL shelf_life = long-life / ambient
```

`category` values must match the `FoodCategory` enum names in
`lib/models/pantry_item.dart` (e.g. `dairy`, `bakery`, `pantryStaple`).

`recipes.db`:

```sql
recipes(id, title, meal_type, diet_category, ingredients, steps,
        time_minutes, calories, embedding BLOB)  -- 384 x float32, L2-normalised
```

## Regenerating the placeholders

`tools/make_placeholder_dbs.sh` recreates the two placeholder DBs from scratch.
Replace them with your real Python-generated dumps when ready — keep the same
filenames and schemas and no app code needs to change.
