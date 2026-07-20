#!/usr/bin/env bash
# Regenerates the placeholder bundled databases in assets/.
# Replace the output with the real Python-generated dumps when ready.
set -euo pipefail
cd "$(dirname "$0")/.."

rm -f assets/products.db assets/recipes.db

sqlite3 assets/products.db <<'SQL'
CREATE TABLE products (
  gtin            TEXT PRIMARY KEY,
  name            TEXT NOT NULL,
  brand           TEXT,
  quantity        TEXT,
  category        TEXT,
  shelf_life_days INTEGER      -- NULL = long-life / ambient shelf-stable
);
INSERT INTO products (gtin, name, brand, quantity, category, shelf_life_days) VALUES
  ('5000169005095','Semi Skimmed Milk','Tesco','2.272L','dairy',7),
  ('5000436589195','Mature Cheddar','Cathedral City','350g','dairy',30),
  ('5449000000996','Coca-Cola Original','Coca-Cola','330ml','beverage',NULL),
  ('5010477348678','Baked Beans','Heinz','415g','pantryStaple',NULL),
  ('5000108000135','Free Range Eggs','Happy Egg Co','6 eggs','dairy',21),
  ('5018374000000','Wholemeal Bread','Hovis','800g','bakery',5),
  ('5000232000000','Fusilli Pasta','Napolina','500g','grain',NULL);
SQL

sqlite3 assets/recipes.db <<'SQL'
CREATE TABLE recipes (
  id            INTEGER PRIMARY KEY,
  title         TEXT NOT NULL,
  summary       TEXT,
  meal_type     TEXT,            -- lunch | dinner
  diet_category TEXT,            -- healthy | normal | indulgent
  ingredients   TEXT,            -- JSON array
  steps         TEXT,            -- JSON array
  time_minutes  INTEGER,
  calories      INTEGER,
  embedding     BLOB             -- 384 x float32, L2-normalised (NULL in placeholder)
);
-- Placeholder recipes so the screen works before the real Python-generated
-- dump (with embeddings) lands. At least one per meal_type x diet_category.
INSERT INTO recipes (title, summary, meal_type, diet_category, ingredients, steps, time_minutes, calories) VALUES
  ('Chicken & Veg Traybake','A lean one-tray dinner.','dinner','healthy',
   '["chicken breast","courgette","pepper","olive oil"]',
   '["Heat oven to 200C.","Chop the veg and toss with oil.","Add chicken, roast 25 min."]',35,420),
  ('Spaghetti Bolognese','Weeknight family classic.','dinner','normal',
   '["spaghetti","beef mince","tinned tomatoes","onion"]',
   '["Brown the mince and onion.","Add tomatoes, simmer 20 min.","Serve over spaghetti."]',40,650),
  ('Mac & Cheese','Extra cheesy comfort food.','dinner','indulgent',
   '["macaroni","cheddar","butter","milk"]',
   '["Cook the macaroni.","Make a cheese sauce with butter, milk and cheddar.","Combine and bake."]',30,820),
  ('Chicken Salad Bowl','Fresh, protein-packed lunch.','lunch','healthy',
   '["chicken breast","salad leaves","tomato","cucumber"]',
   '["Slice the chicken and veg.","Toss together.","Dress lightly and serve."]',15,320),
  ('Cheese & Ham Toastie','Quick grilled sandwich.','lunch','normal',
   '["bread","cheddar","ham","butter"]',
   '["Butter the bread.","Fill with cheese and ham.","Griddle until golden."]',10,480),
  ('Loaded Nachos','Sharing-plate indulgence.','lunch','indulgent',
   '["tortilla chips","cheddar","soured cream","jalapenos"]',
   '["Layer chips and cheese.","Grill until melted.","Top with cream and jalapenos."]',15,700);
SQL

echo "Wrote assets/products.db ($(sqlite3 assets/products.db 'SELECT count(*) FROM products;') rows) and assets/recipes.db ($(sqlite3 assets/recipes.db 'SELECT count(*) FROM recipes;') rows)"
