import 'package:uuid/uuid.dart';
import 'package:intl/intl.dart';

const _uuid = Uuid();

String generateId() => _uuid.v4();

String generateInvoiceNo() {
  final now = DateTime.now();
  final datePart = DateFormat('yyyyMMdd').format(now);
  final timePart = DateFormat('HHmmss').format(now);
  return 'INV-$datePart-$timePart';
}