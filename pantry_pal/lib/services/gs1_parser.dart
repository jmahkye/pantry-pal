class Gs1Data {
  final String? gtin;
  final DateTime? expiryDate;
  final DateTime? bestBeforeDate;
  final String? batch;
  final String? serial;

  const Gs1Data({
    this.gtin,
    this.expiryDate,
    this.bestBeforeDate,
    this.batch,
    this.serial,
  });

  bool get isEmpty =>
      gtin == null &&
      expiryDate == null &&
      bestBeforeDate == null &&
      batch == null &&
      serial == null;

  DateTime? get effectiveExpiry => expiryDate ?? bestBeforeDate;
}

class Gs1Parser {
  // FNC1 group separator (ASCII 0x1D) — terminates variable-length AI values.
  static final String _fnc1 = String.fromCharCode(0x1D);

  // Fixed-length AIs (length excludes the AI itself).
  static const Map<String, int> _fixedLengths = {
    '00': 18,
    '01': 14,
    '02': 14,
    '11': 6,
    '13': 6,
    '15': 6,
    '16': 6,
    '17': 6,
    '20': 2,
  };

  static Gs1Data parse(String raw) {
    // GS1 Digital Link QR codes encode the data as a URL, e.g.
    // https://example.com/01/05000000000056/17/261015/10/ABC123
    // Detect and parse those separately from concatenated element strings.
    if (raw.startsWith('http://') || raw.startsWith('https://')) {
      return _parseDigitalLink(raw);
    }

    var input = raw;
    if (input.startsWith(']d2') || input.startsWith(']D2')) {
      input = input.substring(3);
    }
    if (input.startsWith(_fnc1)) {
      input = input.substring(1);
    }

    String? gtin;
    DateTime? expiry;
    DateTime? bestBefore;
    String? batch;
    String? serial;

    var i = 0;
    while (i < input.length) {
      if (i + 2 > input.length) break;
      final ai = input.substring(i, i + 2);
      i += 2;

      final fixedLen = _fixedLengths[ai];
      String value;
      if (fixedLen != null) {
        if (i + fixedLen > input.length) break;
        value = input.substring(i, i + fixedLen);
        i += fixedLen;
      } else {
        final sepIdx = input.indexOf(_fnc1, i);
        if (sepIdx == -1) {
          value = input.substring(i);
          i = input.length;
        } else {
          value = input.substring(i, sepIdx);
          i = sepIdx + 1;
        }
      }

      switch (ai) {
        case '01':
          gtin = value;
          break;
        case '17':
          expiry = _parseDate(value);
          break;
        case '15':
          bestBefore = _parseDate(value);
          break;
        case '10':
          batch = value;
          break;
        case '21':
          serial = value;
          break;
      }
    }

    return Gs1Data(
      gtin: gtin,
      expiryDate: expiry,
      bestBeforeDate: bestBefore,
      batch: batch,
      serial: serial,
    );
  }

  /// Parses a GS1 Digital Link URL. AIs appear as `/ai/value` pairs in the path
  /// (GTIN in AI 01 is the "primary key"), and any of the same AIs may also
  /// appear as query parameters (e.g. `?17=261015`). Path pairs win.
  static Gs1Data _parseDigitalLink(String raw) {
    final uri = Uri.tryParse(raw);
    if (uri == null) return const Gs1Data();

    final values = <String, String>{};

    // Path segments walked in AI/value pairs.
    final segs = uri.pathSegments;
    for (var i = 0; i + 1 < segs.length; i += 2) {
      values[segs[i]] = Uri.decodeComponent(segs[i + 1]);
    }
    // Query parameters as a fallback (don't overwrite path values).
    uri.queryParameters.forEach((k, v) => values.putIfAbsent(k, () => v));

    return Gs1Data(
      gtin: values['01'],
      expiryDate: _parseDate(values['17']),
      bestBeforeDate: _parseDate(values['15']),
      batch: values['10'],
      serial: values['21'],
    );
  }

  static DateTime? _parseDate(String? yymmdd) {
    if (yymmdd == null) return null;
    if (yymmdd.length != 6) return null;
    final yy = int.tryParse(yymmdd.substring(0, 2));
    final mm = int.tryParse(yymmdd.substring(2, 4));
    var dd = int.tryParse(yymmdd.substring(4, 6));
    if (yy == null || mm == null || dd == null) return null;
    if (mm < 1 || mm > 12) return null;

    // GS1 spec: year is current century if yy <= currentYear + 49, else previous.
    final nowYear = DateTime.now().year;
    final century = (nowYear ~/ 100) * 100;
    var year = century + yy;
    if (year - nowYear > 49) year -= 100;
    if (nowYear - year > 49) year += 100;

    // GS1 allows dd=00 to mean "last day of month" — normalise to 28 for safety.
    if (dd == 0) dd = 28;
    try {
      return DateTime(year, mm, dd);
    } catch (_) {
      return null;
    }
  }
}
