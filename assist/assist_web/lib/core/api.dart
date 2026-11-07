import 'dart:convert';

import 'package:http/http.dart' as http;

import 'config.dart';

class ApiException implements Exception {
  ApiException(this.status, this.code, this.message);
  final int status;
  final String code;
  final String message;
  @override
  String toString() => message;
}

/// 每個角色各自持有一個 ApiClient（並排示範時，同一個網頁裡會有兩個身分）。
class ApiClient {
  ApiClient({String? base}) : base = base ?? resolveApiBase();

  final String base;
  String? token;

  Map<String, String> get _headers => {
    'Content-Type': 'application/json',
    if (token != null) 'Authorization': 'Bearer $token',
  };

  Future<dynamic> get(String path) async => _decode(await http.get(Uri.parse('$base/api$path'), headers: _headers));

  Future<dynamic> post(String path, [Map<String, dynamic>? body]) async =>
      _decode(await http.post(Uri.parse('$base/api$path'), headers: _headers, body: jsonEncode(body ?? {})));

  Future<dynamic> put(String path, Map<String, dynamic> body) async =>
      _decode(await http.put(Uri.parse('$base/api$path'), headers: _headers, body: jsonEncode(body)));

  Future<dynamic> delete(String path) async =>
      _decode(await http.delete(Uri.parse('$base/api$path'), headers: _headers));

  dynamic _decode(http.Response res) {
    final text = utf8.decode(res.bodyBytes);
    final data = text.isEmpty ? null : jsonDecode(text);
    if (res.statusCode >= 400) {
      final err = (data is Map ? data['error'] : null) as Map?;
      throw ApiException(
        res.statusCode,
        err?['code'] as String? ?? 'ERROR',
        err?['message'] as String? ?? '系統忙碌中，請稍後再試',
      );
    }
    return data;
  }
}
