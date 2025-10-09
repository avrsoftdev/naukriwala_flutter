import 'dart:convert';
import 'package:crypto/crypto.dart';

String generateSha256(String input) {
  // Convert the input string to bytes using UTF-8 encoding
  final bytes = utf8.encode(input);
  // Compute SHA-256 hash
  final digest = sha256.convert(bytes);
  // Return the hexadecimal representation of the hash
  return digest.toString();
}

void main() {
  const input = "Hello, World!";
  // ignore: unused_local_variable
  final hash = generateSha256(input);
}