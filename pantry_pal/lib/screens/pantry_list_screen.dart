import 'dart:io';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../data/database.dart';
import '../models/pantry_item.dart';
import '../services/notifications.dart';
import '../services/product_image_cache.dart';
import 'item_edit_screen.dart';
import 'recipes_screen.dart';
import 'scanner_screen.dart';

class PantryListScreen extends StatefulWidget {
  const PantryListScreen({super.key});

  @override
  State<PantryListScreen> createState() => _PantryListScreenState();
}

class _PantryListScreenState extends State<PantryListScreen> {
  late Future<List<PantryItem>> _itemsFuture;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  void _reload() {
    setState(() {
      _itemsFuture = PantryDatabase.instance.all();
    });
  }

  Future<void> _openEditor({PantryItem? existing, PantryItem? draft}) async {
    final result = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => ItemEditScreen(existing: existing, draft: draft),
      ),
    );
    if (result == true) _reload();
  }

  Future<void> _openScanner() async {
    final scanned = await Navigator.of(context).push<ScanResult>(
      MaterialPageRoute(builder: (_) => const ScannerScreen()),
    );
    if (scanned == null || !mounted) return;
    await _openEditor(existing: scanned.existing, draft: scanned.draft);
  }

  Future<void> _delete(PantryItem item) async {
    if (item.id == null) return;
    await PantryDatabase.instance.delete(item.id!);
    await NotificationService.instance.cancelForItem(item.id!);
    await ProductImageCache.instance.deleteAt(item.imageUrl);
    _reload();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Pantry Pal'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        actions: [
          IconButton(
            tooltip: 'Recipes',
            icon: const Icon(Icons.restaurant_menu),
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => RecipesScreen()),
            ),
          ),
        ],
      ),
      body: FutureBuilder<List<PantryItem>>(
        future: _itemsFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          final items = snapshot.data ?? const [];
          if (items.isEmpty) {
            return const _EmptyState();
          }
          return RefreshIndicator(
            onRefresh: () async => _reload(),
            child: ListView.separated(
              itemCount: items.length,
              separatorBuilder: (context, index) => const Divider(height: 1),
              itemBuilder: (context, i) {
                final item = items[i];
                return _PantryTile(
                  item: item,
                  onTap: () => _openEditor(existing: item),
                  onDelete: () => _delete(item),
                );
              },
            ),
          );
        },
      ),
      floatingActionButton: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          FloatingActionButton.small(
            heroTag: 'add-manual',
            onPressed: () => _openEditor(),
            tooltip: 'Add manually',
            child: const Icon(Icons.edit),
          ),
          const SizedBox(height: 12),
          FloatingActionButton.extended(
            heroTag: 'scan',
            onPressed: _openScanner,
            icon: const Icon(Icons.qr_code_scanner),
            label: const Text('Scan'),
          ),
        ],
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.kitchen,
                size: 64, color: Theme.of(context).colorScheme.primary),
            const SizedBox(height: 16),
            const Text(
              'Your pantry is empty',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            const Text(
              'Tap Scan to add an item using its barcode or QR code.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey),
            ),
          ],
        ),
      ),
    );
  }
}

class _PantryTile extends StatelessWidget {
  const _PantryTile({
    required this.item,
    required this.onTap,
    required this.onDelete,
  });

  final PantryItem item;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final days = item.daysUntilExpiry;
    final (expiryText, expiryColor) = _expiryDisplay(days, item.expiryDate);

    return Dismissible(
      key: ValueKey(item.id),
      direction: DismissDirection.endToStart,
      background: Container(
        color: Colors.red,
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: const Icon(Icons.delete, color: Colors.white),
      ),
      onDismissed: (_) => onDelete(),
      child: ListTile(
        leading: _LeadingThumbnail(item: item),
        title: Text(item.name, maxLines: 1, overflow: TextOverflow.ellipsis),
        subtitle: Text(
          [
            if (item.brand != null) item.brand!,
            if (item.quantity != null)
              '${_formatQuantity(item.quantity!)}${item.unit ?? ''}',
            item.category.label,
          ].join(' · '),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        trailing: Text(
          expiryText,
          style: TextStyle(
            color: expiryColor,
            fontWeight: FontWeight.w600,
          ),
        ),
        onTap: onTap,
      ),
    );
  }

  static String _formatQuantity(double q) {
    if (q == q.roundToDouble()) return q.toStringAsFixed(0);
    return q.toStringAsFixed(1);
  }

  static (String, Color) _expiryDisplay(int? days, DateTime? date) {
    if (days == null || date == null) return ('—', Colors.grey);
    if (days < 0) return ('Expired', Colors.red.shade700);
    if (days == 0) return ('Today', Colors.red);
    if (days == 1) return ('Tomorrow', Colors.orange.shade800);
    if (days <= 7) return ('${days}d', Colors.orange);
    return (DateFormat.MMMd().format(date), Colors.green.shade700);
  }
}

class _LeadingThumbnail extends StatelessWidget {
  const _LeadingThumbnail({required this.item});

  final PantryItem item;

  @override
  Widget build(BuildContext context) {
    final url = item.imageUrl;
    if (url != null && url.isNotEmpty) {
      final Widget image = ProductImageCache.isRemote(url)
          ? Image.network(
              url,
              fit: BoxFit.cover,
              errorBuilder: (_, _, _) => _fallback(context),
              loadingBuilder: (_, child, progress) {
                if (progress == null) return child;
                return _fallback(context);
              },
            )
          : Image.file(
              File(url),
              fit: BoxFit.cover,
              errorBuilder: (_, _, _) => _fallback(context),
            );
      return ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: SizedBox(width: 48, height: 48, child: image),
      );
    }
    return _fallback(context);
  }

  Widget _fallback(BuildContext context) {
    return CircleAvatar(
      backgroundColor: Theme.of(context).colorScheme.secondaryContainer,
      child: Text(item.category.label.substring(0, 1)),
    );
  }
}
