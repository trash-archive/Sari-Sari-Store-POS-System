import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../app/theme.dart';
import '../../../app/providers.dart';
import '../state/products_provider.dart';

class CategoriesScreen extends ConsumerWidget {
  const CategoriesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final categoriesAsync = ref.watch(categoriesProvider);

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('Categories', style: TextStyle(fontWeight: FontWeight.w600)),
      ),
      body: categoriesAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (cats) => cats.isEmpty
            ? Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.category_outlined, size: 64, color: Colors.grey.shade300),
                    const SizedBox(height: 16),
                    const Text(
                      'No categories yet',
                      style: TextStyle(color: AppTheme.textSecondary, fontSize: 16),
                    ),
                  ],
                ),
              )
            : ListView.builder(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
                itemCount: cats.length,
                itemBuilder: (context, i) {
                  final cat = cats[i];
                  return Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.grey.shade200),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.04),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        children: [
                          Container(
                            width: 48,
                            height: 48,
                            decoration: BoxDecoration(
                              color: AppTheme.primary.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Icon(
                              Icons.category_outlined,
                              color: AppTheme.primary,
                              size: 24,
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  cat.name,
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                    color: AppTheme.textPrimary,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const SizedBox(height: 4),
                                Consumer(
                                  builder: (context, ref, child) {
                                    final countAsync = ref.watch(categoryProductCountProvider(cat.id));
                                    return countAsync.when(
                                      data: (count) => Text(
                                        '$count product${count != 1 ? 's' : ''}',
                                        style: TextStyle(
                                          fontSize: 13,
                                          color: Colors.grey.shade600,
                                        ),
                                      ),
                                      loading: () => Text(
                                        'Loading...',
                                        style: TextStyle(
                                          fontSize: 13,
                                          color: Colors.grey.shade600,
                                        ),
                                      ),
                                      error: (_, __) => Text(
                                        '0 products',
                                        style: TextStyle(
                                          fontSize: 13,
                                          color: Colors.grey.shade600,
                                        ),
                                      ),
                                    );
                                  },
                                ),
                              ],
                            ),
                          ),
                          PopupMenuButton<String>(
                            onSelected: (value) {
                              if (value == 'edit') {
                                _editCategoryDialog(context, ref, cat);
                              } else if (value == 'delete') {
                                _deleteCategory(context, ref, cat);
                              }
                            },
                            itemBuilder: (context) => [
                              const PopupMenuItem(
                                value: 'edit',
                                child: Row(
                                  children: [
                                    Icon(Icons.edit_outlined, size: 18),
                                    SizedBox(width: 12),
                                    Text('Edit'),
                                  ],
                                ),
                              ),
                              const PopupMenuItem(
                                value: 'delete',
                                child: Row(
                                  children: [
                                    Icon(Icons.delete_outline, size: 18, color: Colors.red),
                                    SizedBox(width: 12),
                                    Text('Delete', style: TextStyle(color: Colors.red)),
                                  ],
                                ),
                              ),
                            ],
                            child: Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: Colors.grey.shade100,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Icon(
                                Icons.more_vert,
                                color: Colors.grey.shade600,
                                size: 20,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _addCategoryDialog(context, ref),
        tooltip: 'Add Category',
        backgroundColor: AppTheme.primary,
        foregroundColor: Colors.white,
        child: const Icon(Icons.add),
      ),
    );
  }

  Future<void> _deleteCategory(BuildContext context, WidgetRef ref, category) async {
    try {
      final productCount = await ref.read(categoryProductCountProvider(category.id).future);
      
      if (productCount > 0) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  Icon(Icons.warning, color: Colors.white, size: 20),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text('Cannot delete category with $productCount product${productCount > 1 ? 's' : ''}'),
                  ),
                ],
              ),
              backgroundColor: Colors.orange.shade600,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
          );
        }
        return;
      }

      final confirmed = await showDialog<bool>(
        context: context,
        barrierColor: Colors.black54,
        builder: (_) => Dialog(
          backgroundColor: Colors.white,
          surfaceTintColor: Colors.transparent,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          child: Container(
            color: Colors.white,
            constraints: const BoxConstraints(maxWidth: 400),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 16, 12, 12),
                  child: Row(
                    children: [
                      const Text('Delete Category?', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
                      const Spacer(),
                      IconButton(
                        icon: const Icon(Icons.close, size: 20),
                        onPressed: () => Navigator.pop(context, false),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                      ),
                    ],
                  ),
                ),
                Divider(height: 1, color: Colors.grey.shade200),
                Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Delete "${category.name}"? This action cannot be undone.',
                        style: const TextStyle(fontSize: 14, color: AppTheme.textSecondary),
                      ),
                      const SizedBox(height: 20),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton(
                              onPressed: () => Navigator.pop(context, false),
                              style: OutlinedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(vertical: 14),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              ),
                              child: const Text('Cancel'),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: ElevatedButton(
                              onPressed: () => Navigator.pop(context, true),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.red,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(vertical: 14),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              ),
                              child: const Text('Delete'),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      );
      
      if (confirmed == true) {
        await ref.read(productsNotifierProvider.notifier).deleteCategory(category.id);
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  Icon(Icons.check_circle, color: Colors.white, size: 20),
                  const SizedBox(width: 12),
                  Text('Category deleted'),
                ],
              ),
              backgroundColor: Color(0xFF2E7D32),
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
          );
        }
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                Icon(Icons.error, color: Colors.white, size: 20),
                const SizedBox(width: 12),
                Expanded(child: Text(e.toString().replaceFirst('Exception: ', ''))),
              ],
            ),
            backgroundColor: Colors.red.shade600,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          ),
        );
      }
    }
  }

  void _editCategoryDialog(BuildContext context, WidgetRef ref, category) async {
    final ctrl = TextEditingController(text: category.name);
    final formKey = GlobalKey<FormState>();
    
    // Fetch all categories for duplicate validation
    final allCategories = await ref.read(databaseProvider).productsDao.getAllCategories();
    
    if (!context.mounted) return;
    
    showDialog(
      context: context,
      barrierColor: Colors.black54,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Container(
          color: Colors.white,
          constraints: const BoxConstraints(maxWidth: 400),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 12, 12),
                child: Row(
                  children: [
                    const Text('Edit Category', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
                    const Spacer(),
                    IconButton(
                      icon: const Icon(Icons.close, size: 20),
                      onPressed: () => Navigator.pop(ctx),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                    ),
                  ],
                ),
              ),
              Divider(height: 1, color: Colors.grey.shade200),
              Padding(
                padding: const EdgeInsets.all(20),
                child: Form(
                  key: formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Text('Category Name', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppTheme.textPrimary)),
                          const Text(' *', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Colors.red)),
                        ],
                      ),
                      const SizedBox(height: 8),
                      TextFormField(
                        controller: ctrl,
                        autofocus: true,
                        decoration: InputDecoration(
                          hintText: 'Enter category name',
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                          errorMaxLines: 2,
                        ),
                        autovalidateMode: AutovalidateMode.onUserInteraction,
                        validator: (v) {
                          if (v?.trim().isEmpty ?? true) return 'Category name is required';
                          if (v!.trim().length > 30) return 'Category name must be 30 characters or less';
                          // Check for duplicate (excluding current category)
                          final exists = allCategories.any((c) => c.name.toLowerCase() == v.trim().toLowerCase() && c.id != category.id);
                          if (exists) return 'Category with this name already exists';
                          return null;
                        },
                      ),
                      const SizedBox(height: 20),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton(
                              onPressed: () => Navigator.pop(ctx),
                              style: OutlinedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(vertical: 14),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              ),
                              child: const Text('Cancel'),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: ElevatedButton(
                              onPressed: () async {
                                if (formKey.currentState!.validate()) {
                                  try {
                                    await ref.read(productsNotifierProvider.notifier).updateCategory(category.id, ctrl.text.trim());
                                    if (ctx.mounted) {
                                      Navigator.pop(ctx);
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        SnackBar(
                                          content: Row(
                                            children: [
                                              Icon(Icons.check_circle, color: Colors.white, size: 20),
                                              const SizedBox(width: 12),
                                              Text('Category updated'),
                                            ],
                                          ),
                                          backgroundColor: Color(0xFF2E7D32),
                                          behavior: SnackBarBehavior.floating,
                                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                        ),
                                      );
                                    }
                                  } catch (e) {
                                    if (ctx.mounted) {
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        SnackBar(
                                          content: Text(e.toString().replaceAll('Exception: ', '')),
                                          backgroundColor: Colors.red,
                                        ),
                                      );
                                    }
                                  }
                                }
                              },
                              style: ElevatedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(vertical: 14),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              ),
                              child: const Text('Save'),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _addCategoryDialog(BuildContext context, WidgetRef ref) async {
    final ctrl = TextEditingController();
    final formKey = GlobalKey<FormState>();
    
    // Fetch all categories for duplicate validation
    final allCategories = await ref.read(databaseProvider).productsDao.getAllCategories();
    
    if (!context.mounted) return;
    
    showDialog(
      context: context,
      barrierColor: Colors.black54,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Container(
          color: Colors.white,
          constraints: const BoxConstraints(maxWidth: 400),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 12, 12),
                child: Row(
                  children: [
                    const Text('Add Category', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
                    const Spacer(),
                    IconButton(
                      icon: const Icon(Icons.close, size: 20),
                      onPressed: () => Navigator.pop(ctx),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                    ),
                  ],
                ),
              ),
              Divider(height: 1, color: Colors.grey.shade200),
              Padding(
                padding: const EdgeInsets.all(20),
                child: Form(
                  key: formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Text('Category Name', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppTheme.textPrimary)),
                          const Text(' *', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Colors.red)),
                        ],
                      ),
                      const SizedBox(height: 8),
                      TextFormField(
                        controller: ctrl,
                        autofocus: true,
                        decoration: InputDecoration(
                          hintText: 'Enter category name',
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                          errorMaxLines: 2,
                        ),
                        autovalidateMode: AutovalidateMode.onUserInteraction,
                        validator: (v) {
                          if (v?.trim().isEmpty ?? true) return 'Category name is required';
                          if (v!.trim().length > 30) return 'Category name must be 30 characters or less';
                          // Check for duplicate
                          final exists = allCategories.any((c) => c.name.toLowerCase() == v.trim().toLowerCase());
                          if (exists) return 'Category with this name already exists';
                          return null;
                        },
                        onFieldSubmitted: (v) async {
                          if (formKey.currentState!.validate()) {
                            try {
                              await ref.read(productsNotifierProvider.notifier).addCategory(v.trim());
                              if (ctx.mounted) {
                                Navigator.pop(ctx);
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Row(
                                      children: [
                                        Icon(Icons.check_circle, color: Colors.white, size: 20),
                                        const SizedBox(width: 12),
                                        Text('Category added'),
                                      ],
                                    ),
                                    backgroundColor: Color(0xFF2E7D32),
                                    behavior: SnackBarBehavior.floating,
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                  ),
                                );
                              }
                            } catch (e) {
                              if (ctx.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(e.toString().replaceAll('Exception: ', '')),
                                    backgroundColor: Colors.red,
                                  ),
                                );
                              }
                            }
                          }
                        },
                      ),
                      const SizedBox(height: 20),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton(
                              onPressed: () => Navigator.pop(ctx),
                              style: OutlinedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(vertical: 14),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              ),
                              child: const Text('Cancel'),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: ElevatedButton(
                              onPressed: () async {
                                if (formKey.currentState!.validate()) {
                                  try {
                                    await ref.read(productsNotifierProvider.notifier).addCategory(ctrl.text.trim());
                                    if (ctx.mounted) {
                                      Navigator.pop(ctx);
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        SnackBar(
                                          content: Row(
                                            children: [
                                              Icon(Icons.check_circle, color: Colors.white, size: 20),
                                              const SizedBox(width: 12),
                                              Text('Category added'),
                                            ],
                                          ),
                                          backgroundColor: Color(0xFF2E7D32),
                                          behavior: SnackBarBehavior.floating,
                                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                        ),
                                      );
                                    }
                                  } catch (e) {
                                    if (ctx.mounted) {
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        SnackBar(
                                          content: Text(e.toString().replaceAll('Exception: ', '')),
                                          backgroundColor: Colors.red,
                                        ),
                                      );
                                    }
                                  }
                                }
                              },
                              style: ElevatedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(vertical: 14),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              ),
                              child: const Text('Add'),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}