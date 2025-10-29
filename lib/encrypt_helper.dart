import 'dart:convert';

/// Encrypts a string using Base64 encoding

String encryptText(String text) {

  return base64Encode(utf8.encode(text));

}

/// Decrypts a string using Base64 decoding


String decryptText(String encrypted) {

  try {

    return utf8.decode(base64Decode(encrypted));

  } catch (e) {

    // If it's not valid Base64, return it as-is (likely already plain text)

    return encrypted;

  }

}
