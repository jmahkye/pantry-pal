enum FoodCategory {
  produce,
  dairy,
  meat,
  seafood,
  grain,
  bakery,
  pantryStaple,
  condiment,
  frozen,
  beverage,
  snack,
  other;

  String get label => switch (this) {
        FoodCategory.produce => 'Produce',
        FoodCategory.dairy => 'Dairy',
        FoodCategory.meat => 'Meat',
        FoodCategory.seafood => 'Seafood',
        FoodCategory.grain => 'Grain',
        FoodCategory.bakery => 'Bakery',
        FoodCategory.pantryStaple => 'Pantry Staple',
        FoodCategory.condiment => 'Condiment',
        FoodCategory.frozen => 'Frozen',
        FoodCategory.beverage => 'Beverage',
        FoodCategory.snack => 'Snack',
        FoodCategory.other => 'Other',
      };

  static FoodCategory fromName(String? name) {
    if (name == null) return FoodCategory.other;
    return FoodCategory.values.firstWhere(
      (c) => c.name == name,
      orElse: () => FoodCategory.other,
    );
  }
}

class PantryItem {
  final int? id;
  final String name;
  final String? brand;
  final String? gtin;
  final FoodCategory category;
  final double? quantity;
  final String? unit;
  final DateTime? expiryDate;

  /// True when the expiry came from an authoritative source (GS1 AI 17 or the
  /// user typing it in); false when it was estimated from shelf_life_days.
  /// Estimated dates are surfaced as editable in the UI.
  final bool expiryIsExact;
  final DateTime addedDate;

  /// Marked used-up. Consumed items stay in the DB (for history) but are hidden
  /// from the active pantry list rather than deleted.
  final bool consumed;
  final String? notes;
  final String? imageUrl;

  const PantryItem({
    this.id,
    required this.name,
    this.brand,
    this.gtin,
    required this.category,
    this.quantity,
    this.unit,
    this.expiryDate,
    this.expiryIsExact = true,
    required this.addedDate,
    this.consumed = false,
    this.notes,
    this.imageUrl,
  });

  PantryItem copyWith({
    int? id,
    String? name,
    String? brand,
    String? gtin,
    FoodCategory? category,
    double? quantity,
    String? unit,
    DateTime? expiryDate,
    bool? expiryIsExact,
    DateTime? addedDate,
    bool? consumed,
    String? notes,
    String? imageUrl,
    bool clearExpiry = false,
  }) {
    return PantryItem(
      id: id ?? this.id,
      name: name ?? this.name,
      brand: brand ?? this.brand,
      gtin: gtin ?? this.gtin,
      category: category ?? this.category,
      quantity: quantity ?? this.quantity,
      unit: unit ?? this.unit,
      expiryDate: clearExpiry ? null : (expiryDate ?? this.expiryDate),
      expiryIsExact: expiryIsExact ?? this.expiryIsExact,
      addedDate: addedDate ?? this.addedDate,
      consumed: consumed ?? this.consumed,
      notes: notes ?? this.notes,
      imageUrl: imageUrl ?? this.imageUrl,
    );
  }

  Map<String, Object?> toMap() => {
        'id': id,
        'name': name,
        'brand': brand,
        'gtin': gtin,
        'category': category.name,
        'quantity': quantity,
        'unit': unit,
        'expiry_date': expiryDate?.toIso8601String(),
        'expiry_is_exact': expiryIsExact ? 1 : 0,
        'added_date': addedDate.toIso8601String(),
        'consumed': consumed ? 1 : 0,
        'notes': notes,
        'image_url': imageUrl,
      };

  factory PantryItem.fromMap(Map<String, Object?> map) => PantryItem(
        id: map['id'] as int?,
        name: map['name'] as String,
        brand: map['brand'] as String?,
        gtin: map['gtin'] as String?,
        category: FoodCategory.fromName(map['category'] as String?),
        quantity: (map['quantity'] as num?)?.toDouble(),
        unit: map['unit'] as String?,
        expiryDate: map['expiry_date'] == null
            ? null
            : DateTime.parse(map['expiry_date'] as String),
        expiryIsExact: (map['expiry_is_exact'] as int? ?? 1) == 1,
        addedDate: DateTime.parse(map['added_date'] as String),
        consumed: (map['consumed'] as int? ?? 0) == 1,
        notes: map['notes'] as String?,
        imageUrl: map['image_url'] as String?,
      );

  int? get daysUntilExpiry {
    if (expiryDate == null) return null;
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final exp = DateTime(expiryDate!.year, expiryDate!.month, expiryDate!.day);
    return exp.difference(today).inDays;
  }
}
