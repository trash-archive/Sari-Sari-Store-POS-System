import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/utils/currency.dart';
import '../../../app/providers.dart';
import '../../../data/db/app_database.dart';
import '../state/products_provider.dart';

class StockAdjustmentScreen extends ConsumerStatefulWidget {
  final Product product;
  const StockAdjustmentScreen({super.key, required this.product});

  @override
  ConsumerState<StockAdjustmentScreen> createState() =>
      _StockAdjustmentScreenState();
}

class _StockAdjustmentScreenState extends ConsumerState<StockAdjustmentScreen> {
  final _qtyCtrl = TextEditingController();
  final _notesCtrl = TextEditingController();
  String _adjustType = 'restock'; // restock | adjustment
  int _direction = 1; // +1 add, -1 remove (for adjustment)
  bool _saving = false;

  int get _changeQty {
    final val = int.tryParse(_qtyCtrl.text) ?? 0;
    if (_adjustType == 'restock') return val;
    return val * _direction;
  }

  int get _newStock =>
      (widget.product.stockQty + _changeQty).clamp(0, 999999);

  @override
  void dispose() {
    _qtyCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final movementsAsync = ref.watch(stockMovementsProvider(widget.product.id));

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Text('Stock: ${widget.product.name}'),
        elevation: 0,
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          // Current stock
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.primaryContainer,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Current Stock',
                        style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                            color: Theme.of(context)
                                .colorScheme
                                .onPrimaryContainer)),
                    const SizedBox(height: 4),
                    Text(
                      '${widget.product.stockQty} ${widget.product.unit}',
                      style: TextStyle(
                          fontSize: 32,
                          fontWeight: FontWeight.bold,
                          color: Theme.of(context)
                              .colorScheme
                              .onPrimaryContainer),
                    ),
                  ],
                ),
                const Spacer(),
                Text(
                  'Cost: ${widget.product.costCents != null ? formatCurrency(widget.product.costCents!) : 'N/A'}',
                  style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: Theme.of(context).colorScheme.onPrimaryContainer),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // Adjustment type
          const Text('Adjustment Type', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
          const SizedBox(height: 8),
          Row(children: [
            Expanded(
              child: _TypeButton(
                label: 'Restock',
                icon: Icons.add_box_outlined,
                isSelected: _adjustType == 'restock',
                color: Colors.green,
                onTap: () => setState(() { _adjustType = 'restock'; _direction = 1; }),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _TypeButton(
                label: 'Adjustment',
                icon: Icons.tune,
                isSelected: _adjustType == 'adjustment',
                color: Colors.blue,
                onTap: () => setState(() => _adjustType = 'adjustment'),
              ),
            ),
          ]),

          if (_adjustType == 'adjustment') ...[
            const SizedBox(height: 16),
            const Text('Adjust direction', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
            const SizedBox(height: 8),
            Row(children: [
              Expanded(
                child: _TypeButton(
                  label: 'Add',
                  icon: Icons.add,
                  isSelected: _direction == 1,
                  color: Colors.green,
                  onTap: () => setState(() => _direction = 1),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _TypeButton(
                  label: 'Remove',
                  icon: Icons.remove,
                  isSelected: _direction == -1,
                  color: Colors.red,
                  onTap: () => setState(() => _direction = -1),
                ),
              ),
            ]),
          ],
          const SizedBox(height: 20),

          const Text('Quantity', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
          const SizedBox(height: 8),
          TextField(
            controller: _qtyCtrl,
            decoration: InputDecoration(
              hintText: '0',
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              suffixText: widget.product.unit,
            ),
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 16),

          // Preview
          if (_qtyCtrl.text.isNotEmpty && _qtyCtrl.text != '0')
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.grey.shade50,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey.shade200),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('New stock will be:', style: TextStyle(fontSize: 14, color: Colors.grey.shade700)),
                  Text(
                    '$_newStock ${widget.product.unit}',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                      color: _newStock == 0
                          ? Colors.red
                          : _newStock <= widget.product.lowStockThreshold
                              ? Colors.orange
                              : Colors.green,
                    ),
                  ),
                ],
              ),
            ),
          if (_qtyCtrl.text.isNotEmpty && _qtyCtrl.text != '0')
            const SizedBox(height: 16),

          const Text('Notes (optional)', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
          const SizedBox(height: 8),
          TextField(
            controller: _notesCtrl,
            decoration: InputDecoration(
              hintText: 'e.g. Received from supplier, spoilage...',
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            ),
            maxLines: 3,
          ),
          const SizedBox(height: 24),

          ElevatedButton(
            onPressed: (_saving || _qtyCtrl.text.isEmpty || _qtyCtrl.text == '0')
                ? null
                : _save,
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: _saving
                ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : Text(
                    _adjustType == 'restock' ? 'Add Stock' : 'Save Adjustment',
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                  ),
          ),

          const SizedBox(height: 32),
          const Text('Movement History',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          const SizedBox(height: 12),

          movementsAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Text('Error: $e'),
            data: (movements) => movements.isEmpty
                ? Padding(
                    padding: const EdgeInsets.symmetric(vertical: 20),
                    child: Center(
                      child: Text('No movements yet', style: TextStyle(color: Colors.grey.shade500)),
                    ),
                  )
                : Column(
                    children: movements
                        .map((m) => _MovementTile(movement: m))
                        .toList(),
                  ),
          ),
        ],
      ),
    );
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      await ref.read(productsNotifierProvider.notifier).adjustStock(
            widget.product.id,
            widget.product.stockQty,
            _changeQty,
            _adjustType,
            _notesCtrl.text.isEmpty ? null : _notesCtrl.text,
          );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                Icon(Icons.check_circle, color: Colors.white, size: 20),
                const SizedBox(width: 12),
                Text('Stock adjusted successfully'),
              ],
            ),
            backgroundColor: Color(0xFF2E7D32),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          ),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  Icon(Icons.error, color: Colors.white, size: 20),
                  const SizedBox(width: 12),
                  Expanded(child: Text('Error: $e')),
                ],
              ),
              backgroundColor: Color(0xFFC62828),
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }
}

class _TypeButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool isSelected;
  final Color color;
  final VoidCallback onTap;
  const _TypeButton(
      {required this.label,
      required this.icon,
      required this.isSelected,
      required this.color,
      required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: isSelected ? color.withOpacity(0.12) : Colors.grey.shade50,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
              color: isSelected ? color : Colors.grey.shade300, width: 2),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: isSelected ? color : Colors.grey.shade600, size: 20),
            const SizedBox(width: 8),
            Text(label,
                style: TextStyle(
                    fontSize: 15,
                    color: isSelected ? color : Colors.grey.shade600,
                    fontWeight: FontWeight.w600)),
          ],
        ),
      ),
    );
  }
}

class _MovementTile extends StatelessWidget {
  final StockMovement movement;
  const _MovementTile({required this.movement});

  @override
  Widget build(BuildContext context) {
    final isPositive = movement.changeQty > 0;
    final reasonLabel = {
      'sale': 'Sale',
      'restock': 'Restock',
      'adjustment': 'Adjustment',
      'void': 'Void / Return',
    }[movement.reason] ??
        movement.reason;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: (isPositive ? Colors.green : Colors.red).withOpacity(0.12),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              isPositive ? Icons.arrow_upward : Icons.arrow_downward,
              size: 18,
              color: isPositive ? Colors.green : Colors.red,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(reasonLabel, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                if (movement.notes != null)
                  Text(movement.notes!,
                      style: TextStyle(color: Colors.grey.shade600, fontSize: 13)),
                const SizedBox(height: 2),
                Text(
                  _fmtDate(movement.createdAt),
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
                ),
              ],
            ),
          ),
          Text(
            '${isPositive ? '+' : ''}${movement.changeQty}',
            style: TextStyle(
                fontWeight: FontWeight.bold,
                color: isPositive ? Colors.green : Colors.red,
                fontSize: 18),
          ),
        ],
      ),
    );
  }

  String _fmtDate(DateTime dt) {
    final months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return '${months[dt.month - 1]} ${dt.day}, ${dt.year} at ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  }
}