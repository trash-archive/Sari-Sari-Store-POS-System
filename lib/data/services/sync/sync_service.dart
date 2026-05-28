import 'dart:typed_data';
import 'package:drift/drift.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';
import '../../db/app_database.dart';

const _uuid = Uuid();

/// Clamps a DateTime to a valid Postgres range and returns ISO8601 string.
/// Drift stores DateTimes as microseconds; if the DB was backfilled with
/// milliseconds by mistake the value ends up ~1000x too large.
String _toIso(DateTime dt) {
  // If year is unreasonably far in the future, the value was stored as
  // milliseconds instead of microseconds — reinterpret it.
  if (dt.year > 9999) {
    dt = DateTime.fromMillisecondsSinceEpoch(
      dt.microsecondsSinceEpoch ~/ 1000,
      isUtc: true,
    );
  }
  return dt.toUtc().toIso8601String();
}

/// Result returned after a sync operation.
class SyncResult {
  final int pushed;
  final int pulled;
  final String? error;

  const SyncResult({this.pushed = 0, this.pulled = 0, this.error});

  bool get success => error == null;
}

class SyncService {
  final AppDatabase _db;
  final SupabaseClient _client;

  SyncService(this._db, this._client);

  String get _userId => _client.auth.currentUser!.id;

  // ── Public entry point ───────────────────────────────────────

  Future<SyncResult> sync() async {
    try {
      int pushed = 0;
      int pulled = 0;

      await _deduplicateLocal();

      final r1 = await _syncCategories();
      final r2 = await _syncProducts();
      final r3 = await _syncCustomers();
      final r4 = await _syncInvoices();
      final r5 = await _syncInvoiceItems();
      final r6 = await _syncCustomerPayments();
      final r7 = await _syncStockMovements();

      pushed = r1.$1 + r2.$1 + r3.$1 + r4.$1 + r5.$1 + r6.$1 + r7.$1;
      pulled = r1.$2 + r2.$2 + r3.$2 + r4.$2 + r5.$2 + r6.$2 + r7.$2;

      return SyncResult(pushed: pushed, pulled: pulled);
    } catch (e) {
      return SyncResult(error: e.toString());
    }
  }

  // ── Deduplicate existing local rows ────────────────────────

  Future<void> _deduplicateLocal() async {
    // Remove duplicate products (same syncId, keep the one with lowest rowid)
    await _db.customStatement(
      'DELETE FROM products WHERE rowid NOT IN '
      '(SELECT MIN(rowid) FROM products GROUP BY sync_id) '
      'AND sync_id IS NOT NULL',
    );
    await _db.customStatement(
      'DELETE FROM categories WHERE rowid NOT IN '
      '(SELECT MIN(rowid) FROM categories GROUP BY sync_id) '
      'AND sync_id IS NOT NULL',
    );
    await _db.customStatement(
      'DELETE FROM customers WHERE rowid NOT IN '
      '(SELECT MIN(rowid) FROM customers GROUP BY sync_id) '
      'AND sync_id IS NOT NULL',
    );
    await _db.customStatement(
      'DELETE FROM invoices WHERE rowid NOT IN '
      '(SELECT MIN(rowid) FROM invoices GROUP BY sync_id) '
      'AND sync_id IS NOT NULL',
    );
    await _db.customStatement(
      'DELETE FROM invoice_items WHERE rowid NOT IN '
      '(SELECT MIN(rowid) FROM invoice_items GROUP BY sync_id) '
      'AND sync_id IS NOT NULL',
    );
    await _db.customStatement(
      'DELETE FROM customer_payments WHERE rowid NOT IN '
      '(SELECT MIN(rowid) FROM customer_payments GROUP BY sync_id) '
      'AND sync_id IS NOT NULL',
    );
    await _db.customStatement(
      'DELETE FROM stock_movements WHERE rowid NOT IN '
      '(SELECT MIN(rowid) FROM stock_movements GROUP BY sync_id) '
      'AND sync_id IS NOT NULL',
    );
  }

  // ── Categories ───────────────────────────────────────────────

  Future<(int, int)> _syncCategories() async {
    int pushed = 0;
    int pulled = 0;

    // 1. Assign syncIds to any local records that don't have one yet
    final allLocal = await _db.select(_db.categories).get();
    for (final row in allLocal) {
      if (row.syncId == null) {
        await (_db.update(_db.categories)..where((t) => t.id.equals(row.id)))
            .write(CategoriesCompanion(syncId: Value(_uuid.v4())));
      }
    }

    // 2. Push unsynced local records
    // Fetch server categories once for name-match merging
    final List<Map<String, dynamic>> serverCategories = await _client
        .from('categories')
        .select('sync_id, name, updated_at')
        .eq('user_id', _userId);
    final serverCatByName = {
      for (final s in serverCategories)
        (s['name'] as String).toLowerCase(): s,
    };

    final unsynced = await (_db.select(_db.categories)
          ..where((t) => t.isSynced.equals(false)))
        .get();

    for (var row in unsynced) {
      // Name-match merge: adopt server syncId if same category name exists on server
      final serverMatch = serverCatByName[row.name.toLowerCase()];
      if (serverMatch != null) {
        final serverSyncId = serverMatch['sync_id'] as String;
        final serverUpdatedAt = DateTime.parse(serverMatch['updated_at'] as String);
        if (row.syncId != serverSyncId) {
          await (_db.update(_db.categories)..where((t) => t.id.equals(row.id)))
              .write(CategoriesCompanion(syncId: Value(serverSyncId)));
          row = (await (_db.select(_db.categories)
                ..where((t) => t.id.equals(row.id)))
              .getSingleOrNull()) ?? row;
          if (serverUpdatedAt.isAfter(row.updatedAt)) {
            await (_db.update(_db.categories)..where((t) => t.id.equals(row.id)))
                .write(const CategoriesCompanion(isSynced: Value(true)));
            continue;
          }
        }
      }

      final syncId = row.syncId!;
      await _client.from('categories').upsert({
        'sync_id': syncId,
        'user_id': _userId,
        'name': row.name,
        'created_at': _toIso(row.createdAt),
        'updated_at': _toIso(row.updatedAt),
        'deleted_at': row.deletedAt != null ? _toIso(row.deletedAt!) : null,
      });
      await (_db.update(_db.categories)..where((t) => t.id.equals(row.id)))
          .write(const CategoriesCompanion(isSynced: Value(true)));
      pushed++;
    }

    // 3. Pull server records
    final serverRows = await _client
        .from('categories')
        .select()
        .eq('user_id', _userId);

    for (final s in serverRows) {
      final syncId = s['sync_id'] as String;
      final serverUpdatedAt = DateTime.parse(s['updated_at'] as String);

      // Find matching local record by syncId
      final localMatch = await (_db.select(_db.categories)
            ..where((t) => t.syncId.equals(syncId)))
          .getSingleOrNull();

      if (localMatch == null) {
        // Check if a local category with the same name exists (different id, no syncId yet)
        final nameMatch = await (_db.select(_db.categories)
              ..where((t) => t.name.equals(s['name'] as String)))
            .getSingleOrNull();

        if (nameMatch != null) {
          // Merge: assign the server syncId to the existing local record
          await (_db.update(_db.categories)..where((t) => t.id.equals(nameMatch.id)))
              .write(CategoriesCompanion(
            syncId: Value(syncId),
            updatedAt: Value(serverUpdatedAt),
            deletedAt: s['deleted_at'] != null
                ? Value(DateTime.parse(s['deleted_at'] as String))
                : const Value(null),
            isSynced: const Value(true),
          ));
          pulled++;
        } else {
          // New from server — insert locally
          await _db.into(_db.categories).insert(
            CategoriesCompanion(
              id: Value(_uuid.v4()),
              name: Value(s['name'] as String),
              syncId: Value(syncId),
              createdAt: Value(DateTime.parse(s['created_at'] as String)),
              updatedAt: Value(serverUpdatedAt),
              deletedAt: s['deleted_at'] != null
                  ? Value(DateTime.parse(s['deleted_at'] as String))
                  : const Value(null),
              isSynced: const Value(true),
            ),
            mode: InsertMode.insertOrIgnore,
          );
          pulled++;
        }
      } else if (serverUpdatedAt.isAfter(localMatch.updatedAt)) {
        // Server is newer — update local
        await (_db.update(_db.categories)
              ..where((t) => t.id.equals(localMatch.id)))
            .write(CategoriesCompanion(
          name: Value(s['name'] as String),
          updatedAt: Value(serverUpdatedAt),
          deletedAt: s['deleted_at'] != null
              ? Value(DateTime.parse(s['deleted_at'] as String))
              : const Value(null),
          isSynced: const Value(true),
        ));
        pulled++;
      }
    }

    return (pushed, pulled);
  }

  // ── Products ─────────────────────────────────────────────────

  Future<(int, int)> _syncProducts() async {
    int pushed = 0;
    int pulled = 0;

    // Assign missing syncIds
    final allLocal = await (_db.select(_db.products)
          ..where((p) => p.isActive.equals(true)))
        .get();
    for (final row in allLocal) {
      if (row.syncId == null) {
        await (_db.update(_db.products)..where((p) => p.id.equals(row.id)))
            .write(ProductsCompanion(syncId: Value(_uuid.v4())));
      }
    }

    // Fetch all server products once for name-match merging
    final List<Map<String, dynamic>> serverProducts = await _client
        .from('products')
        .select('sync_id, name, updated_at')
        .eq('user_id', _userId);
    final serverByName = {
      for (final s in serverProducts)
        (s['name'] as String).toLowerCase(): s,
    };

    // Push unsynced
    final unsynced = await (_db.select(_db.products)
          ..where((p) => p.isSynced.equals(false)))
        .get();

    // Also re-push any synced products that have imageData but no imageUrl yet
    final needsImageUpload = await (_db.select(_db.products)
          ..where((p) =>
              p.isActive.equals(true) &
              p.isSynced.equals(true) &
              p.imageUrl.isNull() &
              p.imageData.isNotNull()))
        .get();

    final toPush = {
      for (final p in [...unsynced, ...needsImageUpload]) p.id: p,
    }.values.toList();

    for (var row in toPush) {
      // ── Name-match merge: if server already has this product name, adopt its syncId
      if (row.syncId == null || unsynced.any((u) => u.id == row.id)) {
        final serverMatch = serverByName[row.name.toLowerCase()];
        if (serverMatch != null) {
          final serverSyncId = serverMatch['sync_id'] as String;
          final serverUpdatedAt = DateTime.parse(serverMatch['updated_at'] as String);
          // Only adopt server syncId if local record doesn't already have one
          if (row.syncId == null || row.syncId != serverSyncId) {
            await (_db.update(_db.products)..where((p) => p.id.equals(row.id)))
                .write(ProductsCompanion(syncId: Value(serverSyncId)));
            // Re-fetch updated row
            row = (await (_db.select(_db.products)
                  ..where((p) => p.id.equals(row.id)))
                .getSingleOrNull()) ?? row;
            // If server is newer, skip pushing — pull phase will update local
            if (serverUpdatedAt.isAfter(row.updatedAt)) {
              await (_db.update(_db.products)..where((p) => p.id.equals(row.id)))
                  .write(const ProductsCompanion(isSynced: Value(true)));
              continue;
            }
          }
        }
      }

      // Resolve category syncId
      final cat = await (_db.select(_db.categories)
            ..where((c) => c.id.equals(row.categoryId)))
          .getSingleOrNull();

      // Upload image to Supabase Storage if we have local bytes and no URL yet
      String? imageUrl = row.imageUrl;
      if (row.imageData != null && imageUrl == null) {
        imageUrl = await _uploadProductImage(row.syncId!, row.imageData!);
        if (imageUrl != null) {
          await (_db.update(_db.products)..where((p) => p.id.equals(row.id)))
              .write(ProductsCompanion(imageUrl: Value(imageUrl)));
        }
      }

      await _client.from('products').upsert({
        'sync_id': row.syncId!,
        'user_id': _userId,
        'category_sync_id': cat?.syncId,
        'name': row.name,
        'description': row.description,
        'unit': row.unit,
        'barcode': row.barcode,
        'price_cents': row.priceCents,
        'cost_cents': row.costCents,
        'stock_qty': row.stockQty,
        'low_stock_threshold': row.lowStockThreshold,
        'image_url': imageUrl,
        'is_active': row.isActive,
        'created_at': _toIso(row.createdAt),
        'updated_at': _toIso(row.updatedAt),
        'deleted_at': row.deletedAt != null ? _toIso(row.deletedAt!) : null,
      });
      await (_db.update(_db.products)..where((p) => p.id.equals(row.id)))
          .write(const ProductsCompanion(isSynced: Value(true)));
      pushed++;
    }

    // Pull from server
    final serverRows = await _client
        .from('products')
        .select()
        .eq('user_id', _userId);

    for (final s in serverRows) {
      final syncId = s['sync_id'] as String;
      final serverUpdatedAt = DateTime.parse(s['updated_at'] as String);
      final serverImageUrl = s['image_url'] as String?;

      // Resolve local category id from category syncId
      String? localCategoryId;
      if (s['category_sync_id'] != null) {
        final cat = await (_db.select(_db.categories)
              ..where((c) => c.syncId.equals(s['category_sync_id'] as String)))
            .getSingleOrNull();
        localCategoryId = cat?.id;
      }
      if (localCategoryId == null) continue;

      final localMatch = await (_db.select(_db.products)
            ..where((p) => p.syncId.equals(syncId)))
          .getSingleOrNull();

      if (localMatch == null) {
        // Check if a local product with the same name exists (no syncId yet)
        final nameMatch = await (_db.select(_db.products)
              ..where((p) =>
                  p.name.equals(s['name'] as String) &
                  p.syncId.isNull()))
            .getSingleOrNull();

        if (nameMatch != null) {
          // Merge: assign server syncId to existing local record
          final useServerData = serverUpdatedAt.isAfter(nameMatch.updatedAt);
          await (_db.update(_db.products)..where((p) => p.id.equals(nameMatch.id)))
              .write(ProductsCompanion(
            syncId: Value(syncId),
            categoryId: useServerData ? Value(localCategoryId) : Value(nameMatch.categoryId),
            name: useServerData ? Value(s['name'] as String) : Value(nameMatch.name),
            priceCents: useServerData ? Value(s['price_cents'] as int) : Value(nameMatch.priceCents),
            costCents: useServerData ? Value(s['cost_cents'] as int?) : Value(nameMatch.costCents),
            stockQty: useServerData ? Value(s['stock_qty'] as int) : Value(nameMatch.stockQty),
            updatedAt: useServerData ? Value(serverUpdatedAt) : Value(nameMatch.updatedAt),
            isSynced: const Value(true),
          ));
          pulled++;
        } else {
          // Download image bytes from Storage URL if available
          Uint8List? imageBytes;
          if (serverImageUrl != null) {
            imageBytes = await _downloadImageBytes(serverImageUrl);
          }

          await _db.into(_db.products).insert(
            ProductsCompanion(
              id: Value(_uuid.v4()),
              syncId: Value(syncId),
              categoryId: Value(localCategoryId),
              name: Value(s['name'] as String),
              description: Value(s['description'] as String?),
              unit: Value(s['unit'] as String),
              barcode: Value(s['barcode'] as String?),
              priceCents: Value(s['price_cents'] as int),
              costCents: Value(s['cost_cents'] as int?),
              stockQty: Value(s['stock_qty'] as int),
              lowStockThreshold: Value(s['low_stock_threshold'] as int),
              imageUrl: Value(serverImageUrl),
              imageData: Value(imageBytes),
              isActive: Value(s['is_active'] as bool),
              createdAt: Value(DateTime.parse(s['created_at'] as String)),
              updatedAt: Value(serverUpdatedAt),
              deletedAt: s['deleted_at'] != null
                  ? Value(DateTime.parse(s['deleted_at'] as String))
                  : const Value(null),
              isSynced: const Value(true),
            ),
            mode: InsertMode.insertOrIgnore,
          );
          pulled++;
        }
      } else if (serverUpdatedAt.isAfter(localMatch.updatedAt)) {
        // Download image bytes if URL changed
        Uint8List? imageBytes = localMatch.imageData;
        if (serverImageUrl != null && serverImageUrl != localMatch.imageUrl) {
          imageBytes = await _downloadImageBytes(serverImageUrl);
        }

        await (_db.update(_db.products)
              ..where((p) => p.id.equals(localMatch.id)))
            .write(ProductsCompanion(
          categoryId: Value(localCategoryId),
          name: Value(s['name'] as String),
          description: Value(s['description'] as String?),
          unit: Value(s['unit'] as String),
          barcode: Value(s['barcode'] as String?),
          priceCents: Value(s['price_cents'] as int),
          costCents: Value(s['cost_cents'] as int?),
          stockQty: Value(s['stock_qty'] as int),
          lowStockThreshold: Value(s['low_stock_threshold'] as int),
          imageUrl: Value(serverImageUrl),
          imageData: Value(imageBytes),
          isActive: Value(s['is_active'] as bool),
          updatedAt: Value(serverUpdatedAt),
          deletedAt: s['deleted_at'] != null
              ? Value(DateTime.parse(s['deleted_at'] as String))
              : const Value(null),
          isSynced: const Value(true),
        ));
        pulled++;
      }
    }

    return (pushed, pulled);
  }

  Future<String?> _uploadProductImage(String syncId, Uint8List bytes) async {
    final path = '$_userId/$syncId.jpg';
    await _client.storage.from('product-images').uploadBinary(
      path,
      bytes,
      fileOptions: const FileOptions(upsert: true, contentType: 'image/jpeg'),
    );
    return _client.storage.from('product-images').getPublicUrl(path);
  }

  Future<Uint8List?> _downloadImageBytes(String url) async {
    try {
      // Extract the storage path from the public URL
      final uri = Uri.parse(url);
      final pathSegments = uri.pathSegments;
      // Path format: /storage/v1/object/public/product-images/<user_id>/<file>
      final bucketIndex = pathSegments.indexOf('product-images');
      if (bucketIndex == -1) return null;
      final storagePath = pathSegments.sublist(bucketIndex + 1).join('/');
      return await _client.storage.from('product-images').download(storagePath);
    } catch (_) {
      return null;
    }
  }

  // ── Customers ────────────────────────────────────────────────

  Future<(int, int)> _syncCustomers() async {
    int pushed = 0;
    int pulled = 0;

    final allLocal = await _db.select(_db.customers).get();
    for (final row in allLocal) {
      if (row.syncId == null) {
        await (_db.update(_db.customers)..where((c) => c.id.equals(row.id)))
            .write(CustomersCompanion(syncId: Value(_uuid.v4())));
      }
    }

    final unsynced = await (_db.select(_db.customers)
          ..where((c) => c.isSynced.equals(false)))
        .get();

    for (final row in unsynced) {
      await _client.from('customers').upsert({
        'sync_id': row.syncId!,
        'user_id': _userId,
        'name': row.name,
        'phone': row.phone,
        'address': row.address,
        'notes': row.notes,
        'balance_cents': row.balanceCents,
        'created_at': _toIso(row.createdAt),
        'updated_at': _toIso(row.updatedAt),
        'deleted_at': row.deletedAt != null ? _toIso(row.deletedAt!) : null,
      });
      await (_db.update(_db.customers)..where((c) => c.id.equals(row.id)))
          .write(const CustomersCompanion(isSynced: Value(true)));
      pushed++;
    }

    final serverRows = await _client
        .from('customers')
        .select()
        .eq('user_id', _userId);

    for (final s in serverRows) {
      final syncId = s['sync_id'] as String;
      final serverUpdatedAt = DateTime.parse(s['updated_at'] as String);

      final localMatch = await (_db.select(_db.customers)
            ..where((c) => c.syncId.equals(syncId)))
          .getSingleOrNull();

      if (localMatch == null) {
        await _db.into(_db.customers).insert(
          CustomersCompanion(
            id: Value(_uuid.v4()),
            syncId: Value(syncId),
            name: Value(s['name'] as String),
            phone: Value(s['phone'] as String?),
            address: Value(s['address'] as String?),
            notes: Value(s['notes'] as String?),
            balanceCents: Value(s['balance_cents'] as int),
            createdAt: Value(DateTime.parse(s['created_at'] as String)),
            updatedAt: Value(serverUpdatedAt),
            deletedAt: s['deleted_at'] != null
                ? Value(DateTime.parse(s['deleted_at'] as String))
                : const Value(null),
            isSynced: const Value(true),
          ),
          mode: InsertMode.insertOrIgnore,
        );
        pulled++;
      } else if (serverUpdatedAt.isAfter(localMatch.updatedAt)) {
        await (_db.update(_db.customers)
              ..where((c) => c.id.equals(localMatch.id)))
            .write(CustomersCompanion(
          name: Value(s['name'] as String),
          phone: Value(s['phone'] as String?),
          address: Value(s['address'] as String?),
          notes: Value(s['notes'] as String?),
          balanceCents: Value(s['balance_cents'] as int),
          updatedAt: Value(serverUpdatedAt),
          deletedAt: s['deleted_at'] != null
              ? Value(DateTime.parse(s['deleted_at'] as String))
              : const Value(null),
          isSynced: const Value(true),
        ));
        pulled++;
      }
    }

    return (pushed, pulled);
  }

  // ── Invoices ─────────────────────────────────────────────────

  Future<(int, int)> _syncInvoices() async {
    int pushed = 0;
    int pulled = 0;

    final allLocal = await _db.select(_db.invoices).get();
    for (final row in allLocal) {
      if (row.syncId == null) {
        await (_db.update(_db.invoices)..where((i) => i.id.equals(row.id)))
            .write(InvoicesCompanion(syncId: Value(_uuid.v4())));
      }
    }

    final unsynced = await (_db.select(_db.invoices)
          ..where((i) => i.isSynced.equals(false)))
        .get();

    for (final row in unsynced) {
      String? customerSyncId;
      if (row.customerId != null) {
        final cust = await (_db.select(_db.customers)
              ..where((c) => c.id.equals(row.customerId!)))
            .getSingleOrNull();
        customerSyncId = cust?.syncId;
      }

      await _client.from('invoices').upsert({
        'sync_id': row.syncId!,
        'user_id': _userId,
        'customer_sync_id': customerSyncId,
        'invoice_no': row.invoiceNo,
        'type': row.type,
        'status': row.status,
        'subtotal_cents': row.subtotalCents,
        'discount_cents': row.discountCents,
        'total_cents': row.totalCents,
        'cash_received_cents': row.cashReceivedCents,
        'change_cents': row.changeCents,
        'balance_before_cents': row.balanceBeforeCents,
        'balance_after_cents': row.balanceAfterCents,
        'notes': row.notes,
        'created_at': _toIso(row.createdAt),
        'updated_at': _toIso(row.updatedAt),
        'deleted_at': row.deletedAt != null ? _toIso(row.deletedAt!) : null,
      });
      await (_db.update(_db.invoices)..where((i) => i.id.equals(row.id)))
          .write(const InvoicesCompanion(isSynced: Value(true)));
      pushed++;
    }

    final serverRows = await _client
        .from('invoices')
        .select()
        .eq('user_id', _userId);

    for (final s in serverRows) {
      final syncId = s['sync_id'] as String;
      final serverUpdatedAt = DateTime.parse(s['updated_at'] as String);

      String? localCustomerId;
      if (s['customer_sync_id'] != null) {
        final cust = await (_db.select(_db.customers)
              ..where((c) => c.syncId.equals(s['customer_sync_id'] as String)))
            .getSingleOrNull();
        localCustomerId = cust?.id;
      }

      final localMatch = await (_db.select(_db.invoices)
            ..where((i) => i.syncId.equals(syncId)))
          .getSingleOrNull();

      if (localMatch == null) {
        await _db.into(_db.invoices).insert(
          InvoicesCompanion(
            id: Value(_uuid.v4()),
            syncId: Value(syncId),
            customerId: Value(localCustomerId),
            invoiceNo: Value(s['invoice_no'] as String),
            type: Value(s['type'] as String),
            status: Value(s['status'] as String),
            subtotalCents: Value(s['subtotal_cents'] as int),
            discountCents: Value(s['discount_cents'] as int),
            totalCents: Value(s['total_cents'] as int),
            cashReceivedCents: Value(s['cash_received_cents'] as int?),
            changeCents: Value(s['change_cents'] as int?),
            balanceBeforeCents: Value(s['balance_before_cents'] as int?),
            balanceAfterCents: Value(s['balance_after_cents'] as int?),
            notes: Value(s['notes'] as String?),
            createdAt: Value(DateTime.parse(s['created_at'] as String)),
            updatedAt: Value(serverUpdatedAt),
            deletedAt: s['deleted_at'] != null
                ? Value(DateTime.parse(s['deleted_at'] as String))
                : const Value(null),
            isSynced: const Value(true),
          ),
          mode: InsertMode.insertOrIgnore,
        );
        pulled++;
      } else if (serverUpdatedAt.isAfter(localMatch.updatedAt)) {
        await (_db.update(_db.invoices)
              ..where((i) => i.id.equals(localMatch.id)))
            .write(InvoicesCompanion(
          customerId: Value(localCustomerId),
          status: Value(s['status'] as String),
          updatedAt: Value(serverUpdatedAt),
          deletedAt: s['deleted_at'] != null
              ? Value(DateTime.parse(s['deleted_at'] as String))
              : const Value(null),
          isSynced: const Value(true),
        ));
        pulled++;
      }
    }

    return (pushed, pulled);
  }

  // ── Invoice Items ────────────────────────────────────────────

  Future<(int, int)> _syncInvoiceItems() async {
    int pushed = 0;
    int pulled = 0;

    final allLocal = await _db.select(_db.invoiceItems).get();
    for (final row in allLocal) {
      if (row.syncId == null) {
        await (_db.update(_db.invoiceItems)
              ..where((i) => i.id.equals(row.id)))
            .write(InvoiceItemsCompanion(syncId: Value(_uuid.v4())));
      }
    }

    final unsynced = await (_db.select(_db.invoiceItems)
          ..where((i) => i.isSynced.equals(false)))
        .get();

    for (final row in unsynced) {
      final invoice = await (_db.select(_db.invoices)
            ..where((i) => i.id.equals(row.invoiceId)))
          .getSingleOrNull();
      if (invoice?.syncId == null) continue; // invoice not synced yet

      final product = await (_db.select(_db.products)
            ..where((p) => p.id.equals(row.productId)))
          .getSingleOrNull();

      await _client.from('invoice_items').upsert({
        'sync_id': row.syncId!,
        'user_id': _userId,
        'invoice_sync_id': invoice!.syncId,
        'product_sync_id': product?.syncId,
        'product_name_snapshot': row.productNameSnapshot,
        'unit_snapshot': row.unitSnapshot,
        'price_snapshot_cents': row.priceSnapshotCents,
        'qty': row.qty,
        'line_total_cents': row.lineTotalCents,
      });
      await (_db.update(_db.invoiceItems)..where((i) => i.id.equals(row.id)))
          .write(const InvoiceItemsCompanion(isSynced: Value(true)));
      pushed++;
    }

    final serverRows = await _client
        .from('invoice_items')
        .select()
        .eq('user_id', _userId);

    for (final s in serverRows) {
      final syncId = s['sync_id'] as String;
      final localMatch = await (_db.select(_db.invoiceItems)
            ..where((i) => i.syncId.equals(syncId)))
          .getSingleOrNull();
      if (localMatch != null) continue; // already exists, items are immutable

      final invoice = await (_db.select(_db.invoices)
            ..where((i) => i.syncId.equals(s['invoice_sync_id'] as String)))
          .getSingleOrNull();
      if (invoice == null) continue;

      String? localProductId;
      if (s['product_sync_id'] != null) {
        final product = await (_db.select(_db.products)
              ..where((p) => p.syncId.equals(s['product_sync_id'] as String)))
            .getSingleOrNull();
        localProductId = product?.id ?? s['product_sync_id'] as String;
      }

      await _db.into(_db.invoiceItems).insert(
        InvoiceItemsCompanion(
          id: Value(_uuid.v4()),
          syncId: Value(syncId),
          invoiceId: Value(invoice.id),
          productId: Value(localProductId ?? ''),
          productNameSnapshot: Value(s['product_name_snapshot'] as String),
          unitSnapshot: Value(s['unit_snapshot'] as String),
          priceSnapshotCents: Value(s['price_snapshot_cents'] as int),
          qty: Value(s['qty'] as int),
          lineTotalCents: Value(s['line_total_cents'] as int),
          isSynced: const Value(true),
        ),
        mode: InsertMode.insertOrIgnore,
      );
      pulled++;
    }

    return (pushed, pulled);
  }

  // ── Customer Payments ────────────────────────────────────────

  Future<(int, int)> _syncCustomerPayments() async {
    int pushed = 0;
    int pulled = 0;

    final allLocal = await _db.select(_db.customerPayments).get();
    for (final row in allLocal) {
      if (row.syncId == null) {
        await (_db.update(_db.customerPayments)
              ..where((p) => p.id.equals(row.id)))
            .write(CustomerPaymentsCompanion(syncId: Value(_uuid.v4())));
      }
    }

    final unsynced = await (_db.select(_db.customerPayments)
          ..where((p) => p.isSynced.equals(false)))
        .get();

    for (final row in unsynced) {
      final customer = await (_db.select(_db.customers)
            ..where((c) => c.id.equals(row.customerId)))
          .getSingleOrNull();
      if (customer?.syncId == null) continue;

      String? invoiceSyncId;
      if (row.invoiceId != null) {
        final inv = await (_db.select(_db.invoices)
              ..where((i) => i.id.equals(row.invoiceId!)))
            .getSingleOrNull();
        invoiceSyncId = inv?.syncId;
      }

      await _client.from('customer_payments').upsert({
        'sync_id': row.syncId!,
        'user_id': _userId,
        'customer_sync_id': customer!.syncId,
        'invoice_sync_id': invoiceSyncId,
        'amount_cents': row.amountCents,
        'notes': row.notes,
        'created_at': _toIso(row.createdAt),
      });
      await (_db.update(_db.customerPayments)
            ..where((p) => p.id.equals(row.id)))
          .write(const CustomerPaymentsCompanion(isSynced: Value(true)));
      pushed++;
    }

    final serverRows = await _client
        .from('customer_payments')
        .select()
        .eq('user_id', _userId);

    for (final s in serverRows) {
      final syncId = s['sync_id'] as String;
      final localMatch = await (_db.select(_db.customerPayments)
            ..where((p) => p.syncId.equals(syncId)))
          .getSingleOrNull();
      if (localMatch != null) continue;

      final customer = await (_db.select(_db.customers)
            ..where((c) => c.syncId.equals(s['customer_sync_id'] as String)))
          .getSingleOrNull();
      if (customer == null) continue;

      String? localInvoiceId;
      if (s['invoice_sync_id'] != null) {
        final inv = await (_db.select(_db.invoices)
              ..where((i) => i.syncId.equals(s['invoice_sync_id'] as String)))
            .getSingleOrNull();
        localInvoiceId = inv?.id;
      }

      await _db.into(_db.customerPayments).insert(
        CustomerPaymentsCompanion(
          id: Value(_uuid.v4()),
          syncId: Value(syncId),
          customerId: Value(customer.id),
          invoiceId: Value(localInvoiceId),
          amountCents: Value(s['amount_cents'] as int),
          notes: Value(s['notes'] as String?),
          createdAt: Value(DateTime.parse(s['created_at'] as String)),
          isSynced: const Value(true),
        ),
        mode: InsertMode.insertOrIgnore,
      );
      pulled++;
    }

    return (pushed, pulled);
  }

  // ── Stock Movements ──────────────────────────────────────────

  Future<(int, int)> _syncStockMovements() async {
    int pushed = 0;
    int pulled = 0;

    final allLocal = await _db.select(_db.stockMovements).get();
    for (final row in allLocal) {
      if (row.syncId == null) {
        await (_db.update(_db.stockMovements)
              ..where((s) => s.id.equals(row.id)))
            .write(StockMovementsCompanion(syncId: Value(_uuid.v4())));
      }
    }

    final unsynced = await (_db.select(_db.stockMovements)
          ..where((s) => s.isSynced.equals(false)))
        .get();

    for (final row in unsynced) {
      final product = await (_db.select(_db.products)
            ..where((p) => p.id.equals(row.productId)))
          .getSingleOrNull();
      if (product?.syncId == null) continue;

      await _client.from('stock_movements').upsert({
        'sync_id': row.syncId!,
        'user_id': _userId,
        'product_sync_id': product!.syncId,
        'change_qty': row.changeQty,
        'reason': row.reason,
        'reference_sync_id': row.referenceId,
        'notes': row.notes,
        'created_at': _toIso(row.createdAt),
      });
      await (_db.update(_db.stockMovements)
            ..where((s) => s.id.equals(row.id)))
          .write(const StockMovementsCompanion(isSynced: Value(true)));
      pushed++;
    }

    final serverRows = await _client
        .from('stock_movements')
        .select()
        .eq('user_id', _userId);

    for (final s in serverRows) {
      final syncId = s['sync_id'] as String;
      final localMatch = await (_db.select(_db.stockMovements)
            ..where((m) => m.syncId.equals(syncId)))
          .getSingleOrNull();
      if (localMatch != null) continue;

      final product = await (_db.select(_db.products)
            ..where((p) => p.syncId.equals(s['product_sync_id'] as String)))
          .getSingleOrNull();
      if (product == null) continue;

      await _db.into(_db.stockMovements).insert(
        StockMovementsCompanion(
          id: Value(_uuid.v4()),
          syncId: Value(syncId),
          productId: Value(product.id),
          changeQty: Value(s['change_qty'] as int),
          reason: Value(s['reason'] as String),
          referenceId: Value(s['reference_sync_id'] as String?),
          notes: Value(s['notes'] as String?),
          createdAt: Value(DateTime.parse(s['created_at'] as String)),
          isSynced: const Value(true),
        ),
        mode: InsertMode.insertOrIgnore,
      );
      pulled++;
    }

    return (pushed, pulled);
  }
}
