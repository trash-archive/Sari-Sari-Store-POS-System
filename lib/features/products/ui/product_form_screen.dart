import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:drift/drift.dart' hide Column;
import 'dart:io';
import 'package:image_picker/image_picker.dart';
import '../../../data/db/app_database.dart';
import '../../../core/utils/currency.dart';
import '../../../data/services/image_storage_service.dart';
import '../state/products_provider.dart';
import '../../../app/providers.dart';
import '../../../app/theme.dart';

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
  final _priceCtrl = TextEditingController();
  final _costCtrl = TextEditingController();
  final _stockCtrl = TextEditingController();
  final _thresholdCtrl = TextEditingController();
  String? _selectedCategoryId;
  String? _imagePath;
  String _selectedUnit = 'pc';

  final Map<String, String> _units = {
    'pc': 'Piece',
    'pack': 'Pack',
    'sachet': 'Sachet',
    'box': 'Box',
    'bottle': 'Bottle',
    'can': 'Can',
    'jar': 'Jar',
    'tube': 'Tube',
    'bar': 'Bar',
    'roll': 'Roll',
    'loaf': 'Loaf',
    'bundle': 'Bundle',
    'tray': 'Tray',
    'sack': 'Sack',
    'kg': 'Kilogram',
    'g': 'Gram',
    'L': 'Liter',
    'mL': 'Milliliter',
    'gal': 'Gallon',
  };

  String _getUnitDisplay(String key) {
    final name = _units[key] ?? key;
    if (key == 'kg' || key == 'g' || key == 'L' || key == 'mL' || key == 'gal') {
      return '$name ($key)';
    }
    return name;
  }

  @override
  void initState() {
    super.initState();
    if (widget.product != null) {
      final p = widget.product!;
      _nameCtrl.text = p.name;
      _descCtrl.text = p.description ?? '';
      _selectedUnit = p.unit;
      _priceCtrl.text = (p.priceCents / 100).toStringAsFixed(2);
      _costCtrl.text = p.costCents != null ? (p.costCents! / 100).toStringAsFixed(2) : '';
      _stockCtrl.text = p.stockQty.toString();
      _thresholdCtrl.text = p.lowStockThreshold.toString();
      _selectedCategoryId = p.categoryId;
      _imagePath = p.imagePath;
    } else {
      _stockCtrl.text = '0';
      _thresholdCtrl.text = '5';
    }
  }

  @override
  Widget build(BuildContext context) {
    final categoriesAsync = ref.watch(categoriesProvider);

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Text(widget.product == null ? 'Add Product' : 'Edit Product'),
        elevation: 0,
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            _buildImageSection(),
            const SizedBox(height: 24),
            _buildLabel('Product Name', required: true),
            const SizedBox(height: 8),
            TextFormField(
              controller: _nameCtrl,
              decoration: InputDecoration(
                hintText: 'Enter product name',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              ),
              autovalidateMode: AutovalidateMode.onUserInteraction,
              validator: (v) => v?.trim().isEmpty ?? true ? 'Product name is required' : null,
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  flex: 2,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildLabel('Category', required: true),
                      const SizedBox(height: 8),
                      categoriesAsync.when(
                        data: (cats) => DropdownButtonFormField<String>(
                          value: _selectedCategoryId,
                          decoration: InputDecoration(
                            hintText: 'Select category',
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide(color: Colors.grey.shade300),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide(color: Colors.grey.shade300),
                            ),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                            errorStyle: const TextStyle(fontSize: 12),
                          ),
                          icon: Icon(Icons.keyboard_arrow_down, color: Colors.grey.shade600),
                          menuMaxHeight: 300,
                          items: cats.map((c) => DropdownMenuItem(
                            value: c.id,
                            child: Text(
                              c.name,
                              style: const TextStyle(fontSize: 15),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          )).toList(),
                          onChanged: (v) {
                            setState(() => _selectedCategoryId = v);
                          },
                          autovalidateMode: AutovalidateMode.onUserInteraction,
                          validator: (v) => v == null ? 'Required' : null,
                        ),
                        loading: () => const LinearProgressIndicator(),
                        error: (e, _) => Text('Error: $e'),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildLabel('Unit', required: true),
                      const SizedBox(height: 8),
                      DropdownButtonFormField<String>(
                        value: _selectedUnit,
                        decoration: InputDecoration(
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(color: Colors.grey.shade300),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(color: Colors.grey.shade300),
                          ),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                        ),
                        icon: Icon(Icons.keyboard_arrow_down, color: Colors.grey.shade600),
                        menuMaxHeight: 300,
                        isExpanded: true,
                        items: _units.keys.map((key) => DropdownMenuItem(
                          value: key,
                          child: Text(_getUnitDisplay(key), style: const TextStyle(fontSize: 15)),
                        )).toList(),
                        onChanged: (v) => setState(() => _selectedUnit = v!),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildLabel('Selling Price', required: true),
                      const SizedBox(height: 8),
                      TextFormField(
                        controller: _priceCtrl,
                        decoration: InputDecoration(
                          hintText: '0.00',
                          prefixIcon: Padding(
                            padding: const EdgeInsets.only(left: 16, right: 8),
                            child: Center(
                              widthFactor: 0,
                              child: Text('₱', style: TextStyle(color: Color(0xFF1A1A1A), fontWeight: FontWeight.w500, fontSize: 16)),
                            ),
                          ),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                        ),
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        autovalidateMode: AutovalidateMode.onUserInteraction,
                        validator: (v) {
                          if (v?.trim().isEmpty ?? true) return 'Required';
                          if (double.tryParse(v!) == null) return 'Invalid price';
                          return null;
                        },
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildLabel('Cost Price'),
                      const SizedBox(height: 8),
                      TextFormField(
                        controller: _costCtrl,
                        decoration: InputDecoration(
                          hintText: '0.00',
                          prefixIcon: Padding(
                            padding: const EdgeInsets.only(left: 16, right: 8),
                            child: Center(
                              widthFactor: 0,
                              child: Text('₱', style: TextStyle(color: Color(0xFF1A1A1A), fontWeight: FontWeight.w500, fontSize: 16)),
                            ),
                          ),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                        ),
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        autovalidateMode: AutovalidateMode.onUserInteraction,
                        validator: (v) {
                          if (v != null && v.isNotEmpty && double.tryParse(v) == null) {
                            return 'Invalid';
                          }
                          return null;
                        },
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildLabel('Stock Quantity', required: true),
                      const SizedBox(height: 8),
                      TextFormField(
                        controller: _stockCtrl,
                        decoration: InputDecoration(
                          hintText: '0',
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                        ),
                        keyboardType: TextInputType.number,
                        autovalidateMode: AutovalidateMode.onUserInteraction,
                        validator: (v) {
                          if (v?.trim().isEmpty ?? true) return 'Required';
                          if (int.tryParse(v!) == null) return 'Invalid';
                          return null;
                        },
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildLabel('Low Stock Alert', required: true),
                      const SizedBox(height: 8),
                      TextFormField(
                        controller: _thresholdCtrl,
                        decoration: InputDecoration(
                          hintText: '0',
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                        ),
                        keyboardType: TextInputType.number,
                        autovalidateMode: AutovalidateMode.onUserInteraction,
                        validator: (v) {
                          if (v?.trim().isEmpty ?? true) return 'Required';
                          if (int.tryParse(v!) == null) return 'Invalid';
                          return null;
                        },
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            _buildLabel('Description'),
            const SizedBox(height: 8),
            TextFormField(
              controller: _descCtrl,
              decoration: InputDecoration(
                hintText: 'Add product description (optional)',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              ),
              maxLines: 3,
            ),
            if (widget.product != null)
              const SizedBox(height: 24),
            if (widget.product != null)
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.grey.shade50,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey.shade200),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.access_time, size: 16, color: Colors.grey.shade600),
                        const SizedBox(width: 8),
                        Text(
                          'Added: ${_formatDate(widget.product!.createdAt)}',
                          style: TextStyle(fontSize: 13, color: Colors.grey.shade700),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Icon(Icons.edit_calendar, size: 16, color: Colors.grey.shade600),
                        const SizedBox(width: 8),
                        Text(
                          'Last edited: ${_formatDate(widget.product!.updatedAt)}',
                          style: TextStyle(fontSize: 13, color: Colors.grey.shade700),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            const SizedBox(height: 32),
            ElevatedButton(
              onPressed: _save,
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: Text(
                widget.product == null ? 'Add Product' : 'Update Product',
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
              ),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildLabel(String text, {bool required = false}) {
    return Row(
      children: [
        Text(
          text,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: AppTheme.textPrimary,
          ),
        ),
        if (required)
          const Text(
            ' *',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: Colors.red,
            ),
          ),
      ],
    );
  }

  Widget _buildImageSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildLabel('Product Image'),
        const SizedBox(height: 8),
        if (_imagePath != null)
          Stack(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: Image.file(
                  File(_imagePath!),
                  width: double.infinity,
                  height: 280,
                  fit: BoxFit.cover,
                ),
              ),
              Positioned(
                top: 12,
                right: 12,
                child: Material(
                  color: Colors.red,
                  borderRadius: BorderRadius.circular(20),
                  child: InkWell(
                    onTap: () => setState(() => _imagePath = null),
                    borderRadius: BorderRadius.circular(20),
                    child: const Padding(
                      padding: EdgeInsets.all(8),
                      child: Icon(Icons.close, color: Colors.white, size: 20),
                    ),
                  ),
                ),
              ),
            ],
          )
        else
          Container(
            width: double.infinity,
            height: 280,
            decoration: BoxDecoration(
              color: AppTheme.surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.grey.shade300, width: 2),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.add_photo_alternate_outlined, size: 64, color: Colors.grey.shade400),
                const SizedBox(height: 16),
                Text(
                  'Add Product Photo',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey.shade600,
                  ),
                ),
                const SizedBox(height: 24),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 40),
                  child: Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () => _pickImage(ImageSource.camera),
                          icon: const Icon(Icons.camera_alt, size: 18),
                          label: const Text('Camera'),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () => _pickImage(ImageSource.gallery),
                          icon: const Icon(Icons.photo_library, size: 18),
                          label: const Text('Gallery'),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
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

  Future<void> _save() async {
    if (!_formKey.currentState!.validate() || _selectedCategoryId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please fill in all required fields'),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

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
        unit: _selectedUnit,
        barcode: null,
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
        unit: _selectedUnit,
        barcode: widget.product!.barcode,
        costCents: costCents,
        stockQty: stockQty,
        lowStockThreshold: threshold,
        imagePath: _imagePath,
      );
    }

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(widget.product == null ? 'Product added successfully' : 'Product updated successfully'),
          backgroundColor: Colors.green,
          behavior: SnackBarBehavior.floating,
        ),
      );
      Navigator.pop(context);
    }
  }

  String _formatDate(DateTime date) {
    final months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return '${months[date.month - 1]} ${date.day}, ${date.year} at ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _descCtrl.dispose();
    _priceCtrl.dispose();
    _costCtrl.dispose();
    _stockCtrl.dispose();
    _thresholdCtrl.dispose();
    super.dispose();
  }
}
