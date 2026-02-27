import 'package:intl/intl.dart';

String formatDate(DateTime dt) => DateFormat('MMM d, yyyy').format(dt);
String formatDateTime(DateTime dt) => DateFormat('MMM d, yyyy h:mm a').format(dt);
String formatTime(DateTime dt) => DateFormat('h:mm a').format(dt);
String invoiceDate(DateTime dt) => DateFormat('yyyyMMdd').format(dt);