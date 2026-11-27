import 'dart:convert';
import 'dart:typed_data';
import 'package:excel/excel.dart' as xl;
import 'package:file_picker/file_picker.dart';

class ExcelImportRow {
  final String name;
  final String phone;
  final String address;
  final String productName;
  final String packLabel;
  final int quantity;
  final double amount;
  final String status;
  final String notes;

  const ExcelImportRow({
    required this.name,
    required this.phone,
    this.address = '',
    this.productName = '',
    this.packLabel = '',
    this.quantity = 1,
    this.amount = 0,
    this.status = '',
    this.notes = '',
  });
}

class ExcelImportResult {
  final String fileName;
  final List<ExcelImportRow> rows;

  const ExcelImportResult({
    required this.fileName,
    required this.rows,
  });
}

class ExcelImportService {
  static Future<ExcelImportResult?> pickAndParseFile() async {
    final files = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['xlsx', 'csv'],
    );
    if (files.isEmpty) return null;

    final file = files.first;
    final bytes = await file.readAsBytes();
    if (bytes.isEmpty) return null;

    final name = file.name;
    final lower = name.toLowerCase();
    final List<List<String>> table;
    if (lower.endsWith('.csv')) {
      table = _parseCsvBytes(bytes);
    } else {
      table = _parseXlsxBytes(bytes);
    }

    final rows = _mapTableToRows(table);
    return ExcelImportResult(fileName: name, rows: rows);
  }

  static List<List<String>> _parseXlsxBytes(Uint8List bytes) {
    final workbook = xl.Excel.decodeBytes(bytes);
    if (workbook.tables.isEmpty) return [];
    final sheetName = workbook.tables.keys.first;
    final sheet = workbook.tables[sheetName];
    if (sheet == null) return [];

    final table = <List<String>>[];
    for (final row in sheet.rows) {
      final parsedRow = row.map((cell) {
        final v = cell?.value;
        if (v == null) return '';
        return v.toString().trim();
      }).toList();
      if (parsedRow.any((c) => c.isNotEmpty)) {
        table.add(parsedRow);
      }
    }
    return table;
  }

  static List<List<String>> _parseCsvBytes(Uint8List bytes) {
    var content = utf8.decode(bytes, allowMalformed: true);
    if (content.startsWith('\uFEFF')) {
      content = content.substring(1);
    }
    final rows = <List<String>>[];
    final currentRow = <String>[];
    final currentCell = StringBuffer();
    bool inQuotes = false;

    for (int i = 0; i < content.length; i++) {
      final ch = content[i];
      if (inQuotes) {
        if (ch == '"') {
          if (i + 1 < content.length && content[i + 1] == '"') {
            currentCell.write('"');
            i++;
          } else {
            inQuotes = false;
          }
        } else {
          currentCell.write(ch);
        }
      } else {
        if (ch == '"') {
          inQuotes = true;
        } else if (ch == ',') {
          currentRow.add(currentCell.toString().trim());
          currentCell.clear();
        } else if (ch == '\r' || ch == '\n') {
          if (ch == '\r' && i + 1 < content.length && content[i + 1] == '\n') {
            i++;
          }
          currentRow.add(currentCell.toString().trim());
          currentCell.clear();
          if (currentRow.any((c) => c.isNotEmpty)) {
            rows.add(List<String>.from(currentRow));
          }
          currentRow.clear();
        } else {
          currentCell.write(ch);
        }
      }
    }
    currentRow.add(currentCell.toString().trim());
    if (currentRow.any((c) => c.isNotEmpty)) {
      rows.add(List<String>.from(currentRow));
    }
    return rows;
  }

  static String _normHeader(String h) =>
      h.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');

  static int _findCol(List<String> headers, List<String> candidates) {
    for (int i = 0; i < headers.length; i++) {
      final h = _normHeader(headers[i]);
      if (h.isEmpty) continue;
      for (final c in candidates) {
        if (h == c || h.contains(c)) return i;
      }
    }
    return -1;
  }

  static List<ExcelImportRow> _mapTableToRows(List<List<String>> table) {
    if (table.isEmpty) return [];

    final firstRow = table.first;
    final nameCol = _findCol(firstRow, ['customername', 'fullname', 'name']);
    final phoneCol = _findCol(
        firstRow, ['whatsapp', 'phone', 'mobile', 'contact', 'number', 'mob']);
    final addrCol = _findCol(
        firstRow, ['deliveryaddress', 'address', 'location', 'place']);
    final pinCol = _findCol(firstRow, ['pincode', 'pin', 'zipcode']);
    final prodCol = _findCol(firstRow, ['product', 'item', 'productname']);
    final packCol = _findCol(firstRow, ['pack', 'variant', 'size', 'weight']);
    final qtyCol = _findCol(firstRow, ['qty', 'quantity', 'count', 'nos']);
    final amtCol =
        _findCol(firstRow, ['total', 'amount', 'price', 'rate', 'paid']);
    final statusCol = _findCol(firstRow, ['status', 'stage', 'orderstatus']);
    final notesCol = _findCol(firstRow, ['notes', 'note', 'remark', 'comment']);

    final hasHeader = nameCol != -1 || phoneCol != -1 || addrCol != -1;
    final startIdx = hasHeader ? 1 : 0;

    final rows = <ExcelImportRow>[];
    for (int r = startIdx; r < table.length; r++) {
      final row = table[r];
      String at(int idx) => (idx >= 0 && idx < row.length) ? row[idx].trim() : '';

      String name;
      String phone;
      String address;

      if (hasHeader) {
        name = at(nameCol);
        phone = at(phoneCol);
        address = at(addrCol);
        final pin = at(pinCol);
        if (pin.isNotEmpty && !address.contains(pin)) {
          address = address.isEmpty ? pin : '$address - $pin';
        }
      } else {
        // Fallback positional order: Name, Phone, Address
        name = at(0);
        phone = at(1);
        address = at(2);
      }

      if (name.isEmpty && phone.isEmpty) continue;
      if (name.isEmpty) name = 'Customer';

      final qty = int.tryParse(at(qtyCol).replaceAll(RegExp(r'[^0-9]'), '')) ?? 1;
      final amt = double.tryParse(
              at(amtCol).replaceAll(RegExp(r'[^0-9.]'), '')) ??
          0;

      rows.add(ExcelImportRow(
        name: name,
        phone: phone,
        address: address,
        productName: at(prodCol),
        packLabel: at(packCol),
        quantity: qty > 0 ? qty : 1,
        amount: amt,
        status: at(statusCol),
        notes: at(notesCol),
      ));
    }
    return rows;
  }
}
