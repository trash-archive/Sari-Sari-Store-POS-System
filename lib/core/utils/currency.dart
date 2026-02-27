import '../constants/app_constants.dart';

String formatCurrency(int cents) {
  final amount = cents / 100.0;
  return '${AppConstants.currencySymbol}${amount.toStringAsFixed(2)}';
}

int parseToCents(String value) {
  final cleaned = value.replaceAll(',', '').trim();
  final parsed = double.tryParse(cleaned) ?? 0.0;
  return (parsed * 100).round();
}

double centsToDouble(int cents) => cents / 100.0;