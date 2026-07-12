import 'dart:convert';
import 'package:flutter/foundation.dart';

class Base64ImageCache {
  static final Map<String, Uint8List> _cache = {};

  static Uint8List decode(String base64String) {
    final cached = _cache[base64String];
    if (cached != null) {
      return cached;
    }
    final decoded = base64Decode(base64String);
    _cache[base64String] = decoded;
    return decoded;
  }
}
