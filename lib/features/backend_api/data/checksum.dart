import 'dart:convert';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';

String sha256Base64(Uint8List bytes) {
  return base64.encode(sha256.convert(bytes).bytes);
}
