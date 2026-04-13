import 'dart:io';

import 'package:intl/intl.dart';

final _dtFmt = DateFormat('dd/MM/yyyy HH:mm');

const double kProductImageAspect = 4 / 5;

File? resolveLocalProductImageFile(String imagePath) {
  final raw = imagePath.trim();
  if (!raw.startsWith('assets/images/')) return null;
  final relative = raw.replaceAll('/', Platform.pathSeparator);
  final candidates = <String>[];
  try {
    candidates.add(Directory.current.path);
  } catch (_) {}
  try {
    final exeDir = File(Platform.resolvedExecutable).parent.path;
    candidates.add(exeDir);
    var cursor = Directory(exeDir);
    for (var i = 0; i < 6; i++) {
      final parent = cursor.parent;
      if (parent.path == cursor.path) break;
      candidates.add(parent.path);
      cursor = parent;
    }
  } catch (_) {}

  for (final base in candidates.toSet()) {
    final path = '$base${Platform.pathSeparator}$relative';
    final file = File(path);
    if (file.existsSync()) return file;
  }
  return null;
}

File? resolveLocalDeliveryProofFile(String pathOrUrl) {
  final raw = pathOrUrl.trim();
  if (raw.isEmpty) return null;

  String relative;
  if (raw.startsWith('local://')) {
    relative = raw.substring('local://'.length);
  } else if (raw.startsWith('delivery_proofs/')) {
    relative = raw;
  } else {
    return null;
  }

  final rel = relative.replaceAll('/', Platform.pathSeparator);
  final candidates = <String>[];
  try {
    candidates.add(Directory.current.path);
  } catch (_) {}
  try {
    final exeDir = File(Platform.resolvedExecutable).parent.path;
    candidates.add(exeDir);
    var cursor = Directory(exeDir);
    for (var i = 0; i < 6; i++) {
      final parent = cursor.parent;
      if (parent.path == cursor.path) break;
      candidates.add(parent.path);
      cursor = parent;
    }
  } catch (_) {}

  for (final base in candidates.toSet()) {
    final f = File('$base${Platform.pathSeparator}$rel');
    if (f.existsSync()) return f;
  }
  return null;
}

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
