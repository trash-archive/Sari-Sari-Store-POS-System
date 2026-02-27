import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:drift/drift.dart' hide Column;
import 'dart:io';
import 'package:image_picker/image_picker.dart';
import '../../../data/db/app_database.dart';
import '../../../core/utils/currency.dart';
import '../../../data/services/image_storage_service.dart';
import '../state/products_provider.dart';

class ProductFormScreen extends ConsumerStatefulWidget {
  final Product? product;
  const ProductFormScreen({super.key, this.product});

  @override
  ConsumerState<ProductFormScreen> createState() => _ProductFormScreenState();
}

class _ProductFormScreenState extends ConsumerState<ProductFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  final _unitCtrl = TextEditingController(text: 'pc');
  final _barcodeCtrl = TextEditingController();
  final _priceCtrl = TextEditingController();
  final _costCtrl = TextEditingController();
  final _stockCtrl = TextEditingController(text: '0');
  final _thresholdCtrl = TextEditingController(text: '5');
  String? _selectedCategoryId;
  String? _imagePath;

  @override
  void initState() {
    super.initState();
    if (widget.product != null) {
      final p = widget.product!;
      _nameCtrl.text = p.name;
      _descCtrl.text = p.description ?? '';
      _unitCtrl.text = p.unit;
      _barcodeCtrl.text = p.barcode ?? '';
      _priceCtrl.text = (p.priceCents / 100).toStringAsFixed(2);
      _costCtrl.text = p.costCents != null ? (p.costCents! / 100).toStringAsFixed(2) : '';
      _stockCtrl.text = p.stockQty.toString();
      _thresholdCtrl.text = p.lowStockThreshold.toString();
      _selectedCategoryId = p.categoryId;
      _imagePath = p.imagePath;
    }
  }

  @override
  Widget build(BuildContext context) {
    final categoriesAsync = ref.watch(categoriesProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.product == null ? 'Add Product' : 'Edit Product'),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            TextFormField(
              controller: _nameCtrl,
              decoration: const InputDecoration(labelText: 'Product Name *'),
              validator: (v) => v?.trim().isEmpty ?? true ? 'Required' : null,
            ),
            const SizedBox(height: 12),
            categoriesAsync.when(
              data: (cats) => DropdownButtonFormField<String>(
                value: _selectedCategoryId,
                decoration: const InputDecoration(labelText: 'Category *'),
                items: cats.map((c) => DropdownMenuItem(value: c.id, child: Text(c.name))).toList(),
                onChanged: (v) => setState(() => _selectedCategoryId = v),
                validator: (v) => v == null ? 'Required' : null,
              ),
              loading: () => const LinearProgressIndicator(),
              error: (e, _) => Text('Error: $e'),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _descCtrl,
              decoration: const InputDecoration(labelText: 'Description'),
              maxLines: 2,
            ),
            const SizedBox(height: 12),
            Row(children: [
              Expanded(
                child: TextFormField(
                  controller: _priceCtrl,
                  decoration: const InputDecoration(labelText: 'Price (₱) *'),
                  keyboardType: TextInputType.number,
                  validator: (v) => v?.trim().isEmpty ?? true ? 'Required' : null,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextFormField(
                  controller: _costCtrl,
                  decoration: const InputDecoration(labelText: 'Cost (₱)'),
                  keyboardType: TextInputType.number,
                ),
              ),
            ]),
            const SizedBox(height: 12),
            Row(children: [
              Expanded(
                child: TextFormField(
                  controller: _stockCtrl,
                  decoration: const InputDecoration(labelText: 'Stock Qty *'),
                  keyboardType: TextInputType.number,
                  validator: (v) => v?.trim().isEmpty ?? true ? 'Required' : null,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextFormField(
                  controller: _unitCtrl,
                  decoration: const InputDecoration(labelText: 'Unit *'),
                  validator: (v) => v?.trim().isEmpty ?? true ? 'Required' : null,
                ),
              ),
            ]),
            const SizedBox(height: 12),
            TextFormField(
              controller: _thresholdCtrl,
              decoration: const InputDecoration(labelText: 'Low Stock Threshold *'),
              keyboardType: TextInputType.number,
              validator: (v) => v?.trim().isEmpty ?? true ? 'Required' : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _barcodeCtrl,
              decoration: const InputDecoration(labelText: 'Barcode'),
            ),
            const SizedBox(height: 16),
            _buildImagePicker(),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: _save,
              child: Text(widget.product == null ? 'Add Product' : 'Update Product'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate() || _selectedCategoryId == null) return;

    final priceCents = parseToCents(_priceCtrl.text);
    final costCents = _costCtrl.text.isEmpty ? null : parseToCents(_costCtrl.text);
    final stockQty = int.tryParse(_stockCtrl.text) ?? 0;
    final threshold = int.tryParse(_thresholdCtrl.text) ?? 5;

    if (widget.product == null) {
      await ref.read(productsNotifierProvider.notifier).addProduct(
        name: _nameCtrl.text.trim(),
        categoryId: _selectedCategoryId!,
        priceCents: priceCents,
        description: _descCtrl.text.isEmpty ? null : _descCtrl.text,
        unit: _unitCtrl.text.trim(),
        barcode: _barcodeCtrl.text.isEmpty ? null : _barcodeCtrl.text,
        costCents: costCents,
        stockQty: stockQty,
        lowStockThreshold: threshold,
        imagePath: _imagePath,
      );
    } else {
      await ref.read(productsNotifierProvider.notifier).updateProduct(
        id: widget.product!.id,
        name: _nameCtrl.text.trim(),
        categoryId: _selectedCategoryId!,
        priceCents: priceCents,
        description: _descCtrl.text.isEmpty ? null : _descCtrl.text,
        unit: _unitCtrl.text.trim(),
        barcode: _barcodeCtrl.text.isEmpty ? null : _barcodeCtrl.text,
        costCents: costCents,
        stockQty: stockQty,
        lowStockThreshold: threshold,
        imagePath: _imagePath,
      );
    }

    if (mounted) Navigator.pop(context);
  }

  Widget _buildImagePicker() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Product Image', style: TextStyle(fontSize: 12, color: Colors.grey)),
        const SizedBox(height: 8),
        Row(
          children: [
            if (_imagePath != null)
              Stack(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.file(File(_imagePath!), width: 100, height: 100, fit: BoxFit.cover),
                  ),
                  Positioned(
                    top: 0,
                    right: 0,
                    child: IconButton(
                      icon: const Icon(Icons.close, color: Colors.red, size: 20),
                      onPressed: () => setState(() => _imagePath = null),
                      style: IconButton.styleFrom(backgroundColor: Colors.white),
                    ),
                  ),
                ],
              )
            else
              Container(
                width: 100,
                height: 100,
                decoration: BoxDecoration(
                  color: Colors.grey[200],
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(Icons.image, size: 40, color: Colors.grey[400]),
              ),
            const SizedBox(width: 12),
            Column(
              children: [
                ElevatedButton.icon(
                  onPressed: () => _pickImage(ImageSource.gallery),
                  icon: const Icon(Icons.photo_library, size: 18),
                  label: const Text('Gallery'),
                ),
                const SizedBox(height: 8),
                OutlinedButton.icon(
                  onPressed: () => _pickImage(ImageSource.camera),
                  icon: const Icon(Icons.camera_alt, size: 18),
                  label: const Text('Camera'),
                ),
              ],
            ),
          ],
        ),
      ],
    );
  }

  Future<void> _pickImage(ImageSource source) async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: source, maxWidth: 800, maxHeight: 800);
    if (pickedFile != null) {
      final savedPath = await ImageStorageService.saveProductImage(File(pickedFile.path));
      setState(() => _imagePath = savedPath);
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _descCtrl.dispose();
    _unitCtrl.dispose();
    _barcodeCtrl.dispose();
    _priceCtrl.dispose();
    _costCtrl.dispose();
    _stockCtrl.dispose();
    _thresholdCtrl.dispose();
    super.dispose();
  }
}
