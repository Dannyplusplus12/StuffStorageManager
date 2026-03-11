import 'package:intl/intl.dart';

final _dtFmt = DateFormat('dd/MM/yyyy HH:mm');

String formatCurrency(num value) {
  final isNeg = value < 0;
  final str = value.abs().toInt().toString();
  final buf = StringBuffer();
  for (int i = 0; i < str.length; i++) {
    if (i > 0 && (str.length - i) % 3 == 0) buf.write('.');
    buf.write(str[i]);
  }
  return isNeg ? '-${buf.toString()}' : buf.toString();
}

String formatSignedCurrency(num value) {
  final s = formatCurrency(value);
  return value > 0 ? '+$s' : s;
}

String formatDate(String raw) {
  try {
    return _dtFmt.format(DateTime.parse(raw.replaceAll(' ', 'T')));
  } catch (_) {
    return raw;
  }
}
