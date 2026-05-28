import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/utils/currency.dart';
import '../../../app/providers.dart';
import '../../../data/db/app_database.dart';
import '../../../app/theme.dart';
import '../../settings/ui/settings_screen.dart';
import '../state/customers_provider.dart';
import 'customer_detail_screen.dart';

class UtangScreen extends ConsumerStatefulWidget {
  const UtangScreen({super.key});

  @override
  ConsumerState<UtangScreen> createState() => _UtangScreenState();
}

class _UtangScreenState extends ConsumerState<UtangScreen> {
  final _searchCtrl = TextEditingController();
  final _scrollController = ScrollController();
  String _search = '';

  @override
  void dispose() {
    _searchCtrl.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final customersAsync = ref.watch(customersProvider);

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('Utang', style: TextStyle(fontWeight: FontWeight.w600, color: AppTheme.textPrimary)),
        backgroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            icon: Icon(Icons.settings_outlined, color: Colors.grey.shade600),
            onPressed: () => Navigator.push(context,
                MaterialPageRoute(builder: (_) => const SettingsScreen())),
          ),
        ],
      ),
      body: Column(
        children: [
          Container(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: Colors.grey.shade300),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.08),
                    blurRadius: 4,
                    offset: const Offset(0, 1),
                  ),
                ],
              ),
              child: TextField(
                controller: _searchCtrl,
                decoration: InputDecoration(
                  hintText: 'Search customers...',
                  hintStyle: TextStyle(color: Colors.grey.shade500),
                  prefixIcon: Icon(Icons.search, color: Colors.grey.shade500),
                  suffixIcon: _search.isNotEmpty
                      ? IconButton(
                          icon: Icon(Icons.close, color: Colors.grey.shade500, size: 20),
                          onPressed: () {
                            _searchCtrl.clear();
                            setState(() => _search = '');
                          },
                        )
                      : null,
                  border: InputBorder.none,
                  enabledBorder: InputBorder.none,
                  focusedBorder: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                  filled: false,
                ),
                onChanged: (v) => setState(() => _search = v),
              ),
            ),
          ),
          customersAsync.when(
            loading: () => const SizedBox(),
            error: (_, __) => const SizedBox(),
            data: (customers) {
              final total = customers.fold(0, (s, c) => s + c.balanceCents);
              return Container(
                width: double.infinity,
                margin: const EdgeInsets.fromLTRB(20, 0, 20, 8),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.grey.shade50,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey.shade200),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Total Customers',
                            style: TextStyle(
                              color: Colors.grey.shade600,
                              fontSize: 12,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '${customers.length}',
                            style: const TextStyle(
                              color: Color(0xFF1A1A1A),
                              fontWeight: FontWeight.bold,
                              fontSize: 20,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      width: 1,
                      height: 40,
                      color: Colors.grey.shade300,
                    ),
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.only(left: 16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Total Utang',
                              style: TextStyle(
                                color: Colors.grey.shade600,
                                fontSize: 12,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              formatCurrency(total),
                              style: const TextStyle(
                                color: Color(0xFF2D5F3F),
                                fontWeight: FontWeight.bold,
                                fontSize: 20,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
          Expanded(
            child: customersAsync.when(
              loading: () =>
                  const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(child: Text('Error: $e')),
              data: (customers) {
                final filtered = _search.isEmpty
                    ? customers
                    : customers
                        .where((c) => c.name
                            .toLowerCase()
                            .contains(_search.toLowerCase()))
                        .toList();

                filtered.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));

                if (filtered.isEmpty && customers.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.people_outline,
                            size: 80, color: Colors.grey.shade300),
                        const SizedBox(height: 16),
                        Text(
                          'No customers yet',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w500,
                            color: Colors.grey.shade600,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Add your first customer to start tracking utang',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey.shade500,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  );
                }

                if (filtered.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.search_off, size: 64, color: Colors.grey.shade400),
                        const SizedBox(height: 16),
                        Text(
                          'No results found',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                            color: Colors.grey.shade600,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'No customers match "$_search"',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey.shade500,
                          ),
                        ),
                      ],
                    ),
                  );
                }

                return Stack(
                  children: [
                    Scrollbar(
                      controller: _scrollController,
                      thumbVisibility: true,
                      thickness: 6,
                      radius: const Radius.circular(3),
                      child: ListView.builder(
                        controller: _scrollController,
                        padding: const EdgeInsets.fromLTRB(20, 8, 20, 100),
                        itemCount: filtered.length,
                        itemBuilder: (context, i) {
                          final c = filtered[i];
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
                            child: Material(
                              color: Colors.transparent,
                              child: InkWell(
                                borderRadius: BorderRadius.circular(16),
                                onTap: () => Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                      builder: (_) =>
                                          CustomerDetailScreen(customer: c)),
                                ),
                                child: Padding(
                                  padding: const EdgeInsets.all(18),
                                  child: Row(
                                    children: [
                                      Expanded(
                                        child: Row(
                                          children: [
                                            Expanded(
                                              child: Column(
                                                crossAxisAlignment: CrossAxisAlignment.start,
                                                children: [
                                                  Text(
                                                    c.name,
                                                    style: const TextStyle(
                                                      fontWeight: FontWeight.w600,
                                                      fontSize: 16,
                                                      color: AppTheme.textPrimary,
                                                    ),
                                                    maxLines: 1,
                                                    overflow: TextOverflow.ellipsis,
                                                  ),
                                                  if (c.phone != null)
                                                    Padding(
                                                      padding: const EdgeInsets.only(top: 4),
                                                      child: Text(
                                                        c.phone!,
                                                        style: TextStyle(
                                                          fontSize: 14,
                                                          color: Colors.grey.shade600,
                                                        ),
                                                      ),
                                                    ),
                                                ],
                                              ),
                                            ),
                                            if (c.balanceCents > 0) ...[
                                              const SizedBox(width: 16),
                                              Text(
                                                formatCurrency(c.balanceCents),
                                                style: const TextStyle(
                                                  color: Colors.red,
                                                  fontWeight: FontWeight.bold,
                                                  fontSize: 16,
                                                ),
                                              ),
                                            ] else ...[
                                              const SizedBox(width: 16),
                                              Container(
                                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                                decoration: BoxDecoration(
                                                  color: Colors.grey.shade100,
                                                  borderRadius: BorderRadius.circular(12),
                                                ),
                                                child: Text(
                                                  'Clear',
                                                  style: TextStyle(
                                                    color: Colors.grey.shade600,
                                                    fontSize: 12,
                                                    fontWeight: FontWeight.w500,
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ],
                                        ),
                                      ),

                                    ],
                                  ),
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                    if (filtered.length > 5)
                      _AlphabetScrollBar(
                        customers: filtered,
                        scrollController: _scrollController,
                      ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _addCustomerDialog(context),
        tooltip: 'Add Customer',
        child: const Icon(Icons.person_add),
      ),
    );
  }

  void _addCustomerDialog(BuildContext context) async {
    final nameCtrl = TextEditingController();
    final phoneCtrl = TextEditingController();
    final formKey = GlobalKey<FormState>();
    
    // Fetch all customers for duplicate validation
    final allCustomers = await ref.read(databaseProvider).customersDao.searchCustomers('');
    
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
                    const Text('Add Customer', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
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
                          const Text('Customer Name', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Color(0xFF1A1A1A))),
                          const Text(' *', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Colors.red)),
                        ],
                      ),
                      const SizedBox(height: 8),
                      TextFormField(
                        controller: nameCtrl,
                        autofocus: true,
                        decoration: InputDecoration(
                          hintText: 'Enter customer name',
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                          errorMaxLines: 2,
                        ),
                        autovalidateMode: AutovalidateMode.onUserInteraction,
                        validator: (v) {
                          if (v?.trim().isEmpty ?? true) return 'Customer name is required';
                          if (v!.trim().length > 30) return 'Name must be 30 characters or less';
                          // Check for duplicate
                          final exists = allCustomers.any((c) => c.name.toLowerCase() == v.trim().toLowerCase());
                          if (exists) return 'Customer with this name already exists';
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),
                      const Text('Phone (optional)', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Color(0xFF1A1A1A))),
                      const SizedBox(height: 8),
                      TextField(
                        controller: phoneCtrl,
                        decoration: InputDecoration(
                          hintText: 'Enter phone number',
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                        ),
                        keyboardType: TextInputType.phone,
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
                                    await ref.read(customersNotifierProvider.notifier).addCustomer(
                                      name: nameCtrl.text.trim(),
                                      phone: phoneCtrl.text.isEmpty ? null : phoneCtrl.text.trim(),
                                    );
                                    if (ctx.mounted) {
                                      Navigator.pop(ctx);
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        SnackBar(
                                          content: Row(
                                            children: [
                                              Icon(Icons.check_circle, color: Colors.white, size: 20),
                                              const SizedBox(width: 12),
                                              Text('Customer added'),
                                            ],
                                          ),
                                          backgroundColor: Color(0xFF2E7D32),
                                          behavior: SnackBarBehavior.floating,
                                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                        ),
                                      );
                                    }
                                  } catch (e) {
                                    // This shouldn't happen since we validate inline, but just in case
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

class _AlphabetScrollBar extends StatelessWidget {
  final List<Customer> customers;
  final ScrollController scrollController;

  const _AlphabetScrollBar({
    required this.customers,
    required this.scrollController,
  });

  @override
  Widget build(BuildContext context) {
    final letters = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ'.split('');
    
    return Positioned(
      right: 4,
      top: 0,
      bottom: 100,
      child: Container(
        width: 20,
        alignment: Alignment.center,
        child: ListView.builder(
          shrinkWrap: true,
          itemCount: letters.length,
          itemBuilder: (context, index) {
            final letter = letters[index];
            final hasCustomer = customers.any((c) => 
              c.name.isNotEmpty && c.name[0].toUpperCase() == letter
            );
            
            return GestureDetector(
              onTap: hasCustomer ? () => _scrollToLetter(letter) : null,
              child: Container(
                height: 14,
                alignment: Alignment.center,
                child: Text(
                  letter,
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: hasCustomer ? AppTheme.primary : Colors.grey.shade300,
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  void _scrollToLetter(String letter) {
    final index = customers.indexWhere((c) => 
      c.name.isNotEmpty && c.name[0].toUpperCase() == letter
    );
    
    if (index != -1 && scrollController.hasClients) {
      final itemHeight = 88.0;
      final position = index * itemHeight;
      scrollController.animateTo(
        position,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }
}