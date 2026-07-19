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
  final String? barcode;
  final FoodCategory category;
  final double? quantity;
  final String? unit;
  final DateTime? expiryDate;
  final DateTime addedAt;
  final String? notes;
  final String? imageUrl;

  const PantryItem({
    this.id,
    required this.name,
    this.brand,
    this.barcode,
    required this.category,
    this.quantity,
    this.unit,
    this.expiryDate,
    required this.addedAt,
    this.notes,
    this.imageUrl,
  });

  PantryItem copyWith({
    int? id,
    String? name,
    String? brand,
    String? barcode,
    FoodCategory? category,
    double? quantity,
    String? unit,
    DateTime? expiryDate,
    DateTime? addedAt,
    String? notes,
    String? imageUrl,
    bool clearExpiry = false,
  }) {
    return PantryItem(
      id: id ?? this.id,
      name: name ?? this.name,
      brand: brand ?? this.brand,
      barcode: barcode ?? this.barcode,
      category: category ?? this.category,
      quantity: quantity ?? this.quantity,
      unit: unit ?? this.unit,
      expiryDate: clearExpiry ? null : (expiryDate ?? this.expiryDate),
      addedAt: addedAt ?? this.addedAt,
      notes: notes ?? this.notes,
      imageUrl: imageUrl ?? this.imageUrl,
    );
  }

  Map<String, Object?> toMap() => {
        'id': id,
        'name': name,
        'brand': brand,
        'barcode': barcode,
        'category': category.name,
        'quantity': quantity,
        'unit': unit,
        'expiry_date': expiryDate?.toIso8601String(),
        'added_at': addedAt.toIso8601String(),
        'notes': notes,
        'image_url': imageUrl,
      };

  factory PantryItem.fromMap(Map<String, Object?> map) => PantryItem(
        id: map['id'] as int?,
        name: map['name'] as String,
        brand: map['brand'] as String?,
        barcode: map['barcode'] as String?,
        category: FoodCategory.fromName(map['category'] as String?),
        quantity: (map['quantity'] as num?)?.toDouble(),
        unit: map['unit'] as String?,
        expiryDate: map['expiry_date'] == null
            ? null
            : DateTime.parse(map['expiry_date'] as String),
        addedAt: DateTime.parse(map['added_at'] as String),
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
