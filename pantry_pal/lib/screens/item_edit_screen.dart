import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../data/database.dart';
import '../models/pantry_item.dart';
import '../services/notifications.dart';
import '../services/product_catalog.dart';

class ItemEditScreen extends StatefulWidget {
  const ItemEditScreen({
    super.key,
    this.existing,
    this.draft,
    this.registerAsUserProduct = false,
  });

  final PantryItem? existing;
  final PantryItem? draft;

  /// When true (OCR-confirmed products), also save the confirmed details to the
  /// user_products table so the same barcode is recognised next time.
  final bool registerAsUserProduct;

  @override
  State<ItemEditScreen> createState() => _ItemEditScreenState();
}

class _ItemEditScreenState extends State<ItemEditScreen> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameCtrl;
  late TextEditingController _brandCtrl;
  late TextEditingController _quantityCtrl;
  late TextEditingController _unitCtrl;
  late TextEditingController _notesCtrl;
  late FoodCategory _category;
  DateTime? _expiry;
  String? _gtin;

  bool get _isEdit => widget.existing != null;

  @override
  void initState() {
    super.initState();
    final source = widget.existing ?? widget.draft;
    _nameCtrl = TextEditingController(text: source?.name ?? '');
    _brandCtrl = TextEditingController(text: source?.brand ?? '');
    _quantityCtrl =
        TextEditingController(text: source?.quantity?.toString() ?? '');
    _unitCtrl = TextEditingController(text: source?.unit ?? '');
    _notesCtrl = TextEditingController(text: source?.notes ?? '');
    _category = source?.category ?? FoodCategory.other;
    _expiry = source?.expiryDate;
    _gtin = source?.gtin;
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _brandCtrl.dispose();
    _quantityCtrl.dispose();
    _unitCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickExpiry() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _expiry ?? now.add(const Duration(days: 7)),
      firstDate: now.subtract(const Duration(days: 365)),
      lastDate: now.add(const Duration(days: 365 * 10)),
    );
    if (picked != null) setState(() => _expiry = picked);
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    final item = (widget.existing ??
            PantryItem(
              name: '',
              category: _category,
              addedDate: DateTime.now(),
            ))
        .copyWith(
      name: _nameCtrl.text.trim(),
      brand: _brandCtrl.text.trim().isEmpty ? null : _brandCtrl.text.trim(),
      gtin: _gtin,
      category: _category,
      quantity: double.tryParse(_quantityCtrl.text.replaceAll(',', '.')),
      unit: _unitCtrl.text.trim().isEmpty ? null : _unitCtrl.text.trim(),
      expiryDate: _expiry,
      notes: _notesCtrl.text.trim().isEmpty ? null : _notesCtrl.text.trim(),
      clearExpiry: _expiry == null,
    );

    int id;
    if (_isEdit) {
      await PantryDatabase.instance.update(item);
      id = item.id!;
    } else {
      id = await PantryDatabase.instance.insert(item);
    }
    final saved = item.copyWith(id: id);
    await NotificationService.instance.scheduleForItem(saved);

    // Remember OCR-confirmed products for future scans of the same barcode.
    if (widget.registerAsUserProduct && saved.gtin != null) {
      await ProductCatalog().saveConfirmed(
        saved.gtin!,
        ProductInfo(
          name: saved.name,
          brand: saved.brand,
          category: saved.category,
          quantity: saved.quantity,
          unit: saved.unit,
        ),
      );
    }

    if (!mounted) return;
    Navigator.of(context).pop(true);
  }

  Future<void> _delete() async {
    if (!_isEdit) return;
    await PantryDatabase.instance.delete(widget.existing!.id!);
    await NotificationService.instance.cancelForItem(widget.existing!.id!);
    if (!mounted) return;
    Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_isEdit ? 'Edit item' : 'Add item'),
        actions: [
          if (_isEdit)
            IconButton(
              icon: const Icon(Icons.delete_outline),
              tooltip: 'Delete',
              onPressed: _delete,
            ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            TextFormField(
              controller: _nameCtrl,
              decoration: const InputDecoration(
                labelText: 'Name',
                border: OutlineInputBorder(),
              ),
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? 'Required' : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _brandCtrl,
              decoration: const InputDecoration(
                labelText: 'Brand',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<FoodCategory>(
              initialValue: _category,
              decoration: const InputDecoration(
                labelText: 'Category',
                border: OutlineInputBorder(),
              ),
              items: FoodCategory.values
                  .map((c) =>
                      DropdownMenuItem(value: c, child: Text(c.label)))
                  .toList(),
              onChanged: (v) => setState(() => _category = v ?? _category),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  flex: 2,
                  child: TextFormField(
                    controller: _quantityCtrl,
                    keyboardType: const TextInputType.numberWithOptions(
                        decimal: true),
                    decoration: const InputDecoration(
                      labelText: 'Quantity',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextFormField(
                    controller: _unitCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Unit',
                      hintText: 'g, ml, ea',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            InkWell(
              onTap: _pickExpiry,
              child: InputDecorator(
                decoration: InputDecoration(
                  labelText: 'Expiry date',
                  border: const OutlineInputBorder(),
                  suffixIcon: _expiry == null
                      ? const Icon(Icons.calendar_today)
                      : IconButton(
                          icon: const Icon(Icons.clear),
                          onPressed: () => setState(() => _expiry = null),
                        ),
                ),
                child: Text(
                  _expiry == null
                      ? 'Not set'
                      : DateFormat.yMMMd().format(_expiry!),
                ),
              ),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _notesCtrl,
              maxLines: 3,
              decoration: const InputDecoration(
                labelText: 'Notes',
                border: OutlineInputBorder(),
              ),
            ),
            if (_gtin != null) ...[
              const SizedBox(height: 16),
              Text(
                'Barcode: $_gtin',
                style: const TextStyle(color: Colors.grey, fontSize: 12),
              ),
            ],
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: _save,
              icon: const Icon(Icons.check),
              label: Text(_isEdit ? 'Save changes' : 'Add to pantry'),
            ),
          ],
        ),
      ),
    );
  }
}
