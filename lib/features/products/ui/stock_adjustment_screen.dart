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
      appBar: AppBar(
        title: Text('Stock: ${widget.product.name}'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Current stock
          Card(
            color: Theme.of(context).colorScheme.primaryContainer,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Current Stock',
                          style: TextStyle(
                              color: Theme.of(context)
                                  .colorScheme
                                  .onPrimaryContainer)),
                      Text(
                        '${widget.product.stockQty} ${widget.product.unit}',
                        style: TextStyle(
                            fontSize: 28,
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
                        color: Theme.of(context).colorScheme.onPrimaryContainer),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),

          // Adjustment type
          const Text('Adjustment Type', style: TextStyle(fontWeight: FontWeight.w600)),
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
            const SizedBox(width: 8),
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
            const SizedBox(height: 12),
            const Text('Adjust direction', style: TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            Row(children: [
              Expanded(
                child: _TypeButton(
                  label: '+ Add',
                  icon: Icons.add,
                  isSelected: _direction == 1,
                  color: Colors.green,
                  onTap: () => setState(() => _direction = 1),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _TypeButton(
                  label: '- Remove',
                  icon: Icons.remove,
                  isSelected: _direction == -1,
                  color: Colors.orange,
                  onTap: () => setState(() => _direction = -1),
                ),
              ),
            ]),
          ],
          const SizedBox(height: 16),

          TextField(
            controller: _qtyCtrl,
            decoration: InputDecoration(
              labelText: 'Quantity',
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
              suffixText: widget.product.unit,
            ),
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 12),

          // Preview
          if (_qtyCtrl.text.isNotEmpty && _qtyCtrl.text != '0')
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('New stock will be:'),
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
          const SizedBox(height: 12),

          TextField(
            controller: _notesCtrl,
            decoration: InputDecoration(
              labelText: 'Notes (optional)',
              hintText: 'e.g. Received from supplier, spoilage...',
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
            ),
            maxLines: 2,
          ),
          const SizedBox(height: 20),

          ElevatedButton(
            onPressed: (_saving || _qtyCtrl.text.isEmpty || _qtyCtrl.text == '0')
                ? null
                : _save,
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 14),
              backgroundColor: Theme.of(context).colorScheme.primary,
              foregroundColor: Colors.white,
            ),
            child: _saving
                ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : Text(_adjustType == 'restock' ? 'Add Stock' : 'Save Adjustment'),
          ),

          const SizedBox(height: 24),
          const Text('Movement History',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          const Divider(),

          movementsAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Text('Error: $e'),
            data: (movements) => movements.isEmpty
                ? const Text('No movements yet', style: TextStyle(color: Colors.grey))
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
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red));
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
      borderRadius: BorderRadius.circular(10),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: isSelected ? color.withOpacity(0.12) : Colors.grey[100],
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
              color: isSelected ? color : Colors.grey[300]!, width: 1.5),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: isSelected ? color : Colors.grey, size: 20),
            const SizedBox(width: 6),
            Text(label,
                style: TextStyle(
                    color: isSelected ? color : Colors.grey,
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

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          CircleAvatar(
            radius: 16,
            backgroundColor:
                (isPositive ? Colors.green : Colors.red).withOpacity(0.12),
            child: Icon(
              isPositive ? Icons.arrow_upward : Icons.arrow_downward,
              size: 16,
              color: isPositive ? Colors.green : Colors.red,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(reasonLabel, style: const TextStyle(fontWeight: FontWeight.w500)),
                if (movement.notes != null)
                  Text(movement.notes!,
                      style: TextStyle(color: Colors.grey[600], fontSize: 12)),
              ],
            ),
          ),
          Text(
            '${isPositive ? '+' : ''}${movement.changeQty}',
            style: TextStyle(
                fontWeight: FontWeight.bold,
                color: isPositive ? Colors.green : Colors.red,
                fontSize: 16),
          ),
          const SizedBox(width: 8),
          Text(
            _fmtDate(movement.createdAt),
            style: TextStyle(fontSize: 11, color: Colors.grey[500]),
          ),
        ],
      ),
    );
  }

  String _fmtDate(DateTime dt) {
    final now = DateTime.now();
    if (dt.year == now.year && dt.month == now.month && dt.day == now.day) {
      return '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
    }
    return '${dt.month}/${dt.day}/${dt.year}';
  }
}