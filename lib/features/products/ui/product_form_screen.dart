import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:drift/drift.dart' hide Column;
import 'dart:io';
import 'package:image_picker/image_picker.dart';
import 'package:crop_your_image/crop_your_image.dart';
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
  String? _imagePath; // kept for legacy/file reference only
  Uint8List? _imageBytes;
  String? _imageUrl; // existing remote URL (from Supabase)
  String _selectedUnit = 'piece';


  final Map<String, String> _units = {
    'piece': 'Piece (pc)',
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
    'kg': 'Kilogram (kg)',
    'g': 'Gram (g)',
    'L': 'Liter (L)',
    'mL': 'Milliliter (mL)',
    'gal': 'Gallon (gal)',
  };

  String _getUnitDisplay(String key) => _units[key] ?? key;


  @override
  void initState() {
    super.initState();
    if (widget.product != null) {
      final p = widget.product!;
      _nameCtrl.text = p.name;
      _descCtrl.text = p.description ?? '';
      _selectedUnit = _units.containsKey(p.unit) ? p.unit : 'piece';
      _priceCtrl.text = (p.priceCents / 100).toStringAsFixed(2);
      _costCtrl.text = p.costCents != null ? (p.costCents! / 100).toStringAsFixed(2) : '';
      _stockCtrl.text = p.stockQty.toString();
      _thresholdCtrl.text = p.lowStockThreshold.toString();
      _selectedCategoryId = p.categoryId;
      _imagePath = p.imagePath;
      _imageBytes = p.imageData;
      _imageUrl = p.imageUrl;
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
        actions: widget.product != null ? [
          IconButton(
            icon: const Icon(Icons.delete_sweep_rounded),
            onPressed: _confirmDelete,
            tooltip: 'Delete Product',
            color: Colors.red.shade600,
          ),
        ] : null,
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
    final hasImage = _imageBytes != null || _imagePath != null || _imageUrl != null;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildLabel('Product Image'),
        const SizedBox(height: 8),
        if (hasImage)
          Center(
            child: SizedBox(
              width: 280,
              height: 280,
              child: Stack(
                children: [
                  Container(
                    width: 280,
                    height: 280,
                    decoration: BoxDecoration(
                      color: Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: AppTheme.primary, width: 2),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(14),
                      child: _imageBytes != null
                          ? Image.memory(_imageBytes!, fit: BoxFit.cover)
                          : _imagePath != null
                              ? Image.file(File(_imagePath!), fit: BoxFit.cover)
                              : Image.network(_imageUrl!, fit: BoxFit.cover),
                    ),
                  ),
                  Positioned(
                    top: 8,
                    right: 8,
                    child: _imageActionButton(
                      icon: Icons.close,
                      onTap: () => setState(() {
                        _imagePath = null;
                        _imageBytes = null;
                        _imageUrl = null;
                      }),
                    ),
                  ),
                  Positioned(
                    top: 8,
                    left: 8,
                    child: _imageActionButton(
                      icon: Icons.crop,
                      onTap: _recropImage,
                    ),
                  ),
                ],
              ),
            ),
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

  Widget _imageActionButton({required IconData icon, required VoidCallback onTap}) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        shape: BoxShape.circle,
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.2), blurRadius: 8, offset: const Offset(0, 2))],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(20),
          child: Padding(
            padding: const EdgeInsets.all(8),
            child: Icon(icon, color: Colors.black, size: 20),
          ),
        ),
      ),
    );
  }

  Future<void> _pickImage(ImageSource source) async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: source);
    if (pickedFile == null) return;
    final rawBytes = await pickedFile.readAsBytes();
    await _openCropper(rawBytes);
  }

  Future<void> _recropImage() async {
    Uint8List? bytes;
    if (_imageBytes != null) {
      bytes = _imageBytes;
    } else if (_imagePath != null) {
      bytes = await File(_imagePath!).readAsBytes();
    }
    if (bytes == null) return;
    await _openCropper(bytes);
  }

  Future<void> _openCropper(Uint8List imageBytes) async {
    final cropped = await Navigator.push<Uint8List>(
      context,
      MaterialPageRoute(builder: (_) => _CropImageScreen(imageBytes: imageBytes)),
    );
    if (cropped == null) return;
    final savedPath = await ImageStorageService.saveImageBytes(cropped);
    setState(() {
      _imagePath = savedPath;
      _imageBytes = cropped;
      _imageUrl = null;
    });
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

    final String? finalImagePath = _imagePath;
    final Uint8List? finalImageBytes = _imageBytes;

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
        imagePath: finalImagePath,
        imageData: finalImageBytes,
        imageUrl: _imageUrl,
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
        imagePath: finalImagePath,
        imageData: finalImageBytes,
        imageUrl: _imageUrl,
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

  void _confirmDelete() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Product'),
        content: Text('Are you sure you want to delete "${widget.product!.name}"? This action cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              await ref.read(databaseProvider).productsDao.softDeleteProduct(widget.product!.id);
              if (ctx.mounted) Navigator.pop(ctx);
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('${widget.product!.name} deleted'), backgroundColor: Colors.green),
                );
                Navigator.pop(context);
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
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

class _CropImageScreen extends StatefulWidget {
  final Uint8List imageBytes;
  const _CropImageScreen({required this.imageBytes});

  @override
  State<_CropImageScreen> createState() => _CropImageScreenState();
}

class _CropImageScreenState extends State<_CropImageScreen> {
  final _cropController = CropController();
  bool _isCropping = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: const Text('Crop Image'),
        actions: [
          TextButton(
            onPressed: _isCropping ? null : _crop,
            child: const Text('Done', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600)),
          ),
        ],
      ),
      body: _isCropping
          ? const Center(child: CircularProgressIndicator(color: Colors.white))
          : Crop(
              image: widget.imageBytes,
              controller: _cropController,
              aspectRatio: 1,
              withCircleUi: false,
              onCropped: (croppedBytes) {
                Navigator.pop(context, croppedBytes);
              },
            ),
    );
  }

  void _crop() {
    setState(() => _isCropping = true);
    _cropController.crop();
  }
}
