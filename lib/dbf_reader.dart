import 'dart:typed_data';
import 'package:flutter/services.dart';

class DBFField {
  String name;
  String type;
  int length;
  int decimalCount;
  bool isIndexed;

  DBFField({
    required this.name,
    required this.type,
    required this.length,
    required this.decimalCount,
    required this.isIndexed,
  });

  @override
  String toString() {
    return 'DBFField{name: $name, type: $type, length: $length, decimalCount: $decimalCount, isIndexed: $isIndexed}';
  }

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'type': type,
      'legth': length,
      'decimalCount': decimalCount,
      'isIndexed': isIndexed
    };
  }
}

class DBFHeader {
  int version;
  DateTime lastUpdate;
  int numberOfRecords;
  int headerLength;
  int recordLength;
  bool hasMemoFile;
  List<DBFField> fields;

  DBFHeader({
    required this.version,
    required this.lastUpdate,
    required this.numberOfRecords,
    required this.headerLength,
    required this.recordLength,
    required this.hasMemoFile,
    required this.fields,
  });

  @override
  String toString() {
    return '''DBFHeader{
      version: $version,
      lastUpdate: $lastUpdate,
      numberOfRecords: $numberOfRecords,
      headerLength: $headerLength,
      recordLength: $recordLength,
      hasMemoFile: $hasMemoFile,
      fields: $fields
    }''';
  }
}

class DBFParser {
  Future<DBFHeader> parseHeader(String filePath) async {
    final data = await rootBundle.load(filePath);
    final bytes = data.buffer.asUint8List();
    final buffer = ByteData.sublistView(bytes);

    // Parse version and memo file flag
    final versionByte = buffer.getUint8(0);
    final version = versionByte & 0x07;
    final hasMemoFile = (versionByte & 0x80) != 0;

    // Parse last update date
    final year = buffer.getUint8(1) + 2000; // Assuming year 2000+
    final month = buffer.getUint8(2);
    final day = buffer.getUint8(3);
    final lastUpdate = DateTime(year, month, day);

    // Parse record counts and lengths
    final numberOfRecords = buffer.getUint32(4, Endian.little);
    final headerLength = buffer.getUint16(8, Endian.little);
    final recordLength = buffer.getUint16(10, Endian.little);

    // Parse field descriptors
    final fields = <DBFField>[];
    var offset = 32;

    while (offset < headerLength - 1) {
      // Check for field descriptor terminator
      if (bytes[offset] == 0x0D) break;

      // Parse field name (11 bytes)
      final nameBytes = bytes.sublist(offset, offset + 11);
      final name = String.fromCharCodes(nameBytes)
          .replaceAll(RegExp(r'\x00.*'), ''); // Remove null bytes

      final type = String.fromCharCode(bytes[offset + 11]);
      final length = buffer.getUint8(offset + 16);
      final decimalCount = buffer.getUint8(offset + 17);
      final isIndexed = buffer.getUint8(offset + 31) == 0x01;

      fields.add(DBFField(
        name: name,
        type: type,
        length: length,
        decimalCount: decimalCount,
        isIndexed: isIndexed,
      ));

      offset += 32; // Move to next field descriptor
    }

    return DBFHeader(
      version: version,
      lastUpdate: lastUpdate,
      numberOfRecords: numberOfRecords,
      headerLength: headerLength,
      recordLength: recordLength,
      hasMemoFile: hasMemoFile,
      fields: fields,
    );
  }

  Future<List<Map<String, dynamic>>> parseRecords(
      String filePath, DBFHeader header) async {
    final data = await rootBundle.load(filePath);

    final bytes = data.buffer.asUint8List();
    final records = <Map<String, dynamic>>[];

    var offset = header.headerLength;

    for (var i = 0; i < header.numberOfRecords; i++) {
      final record = <String, dynamic>{};
      final isDeleted = bytes[offset] == 0x2A; // Check if record is deleted

      if (!isDeleted) {
        var fieldOffset = offset + 1;

        for (final field in header.fields) {
          final fieldBytes =
              bytes.sublist(fieldOffset, fieldOffset + field.length);

          final fieldValue = parseFieldValue(fieldBytes, field);
          record[field.name] = fieldValue;

          fieldOffset += field.length;
        }

        records.add(record);
      }

      offset += header.recordLength;
    }

    return records;
  }

  static dynamic parseFieldValue(List<int> bytes, DBFField field) {
    final value = String.fromCharCodes(bytes).trim();

    switch (field.type) {
      case 'N': // Numeric
        if (value.isEmpty) return null;
        return field.decimalCount > 0
            ? double.tryParse(value)
            : int.tryParse(value);

      case 'F': // Float
        return double.tryParse(value);

      case 'D': // Date
        if (value.length != 8) return null;
        try {
          final year = int.parse(value.substring(0, 4));
          final month = int.parse(value.substring(4, 6));
          final day = int.parse(value.substring(6, 8));
          return DateTime(year, month, day);
        } catch (e) {
          return null;
        }

      case 'L': // Logical
        return 'YyTt'.contains(value)
            ? true
            : 'NnFf'.contains(value)
                ? false
                : null;

      case 'M': // Memo
      case 'B': // Binary
      case 'G': // General
        // These types reference .DBT files and require additional handling
        return value.isEmpty ? null : int.tryParse(value);

      case 'C': // Character
      default:
        return value;
    }
  }
}
