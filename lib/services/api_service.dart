import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:junko_bodie/config/constants.dart';

/// Exception thrown when an API request fails.
class ApiException implements Exception {
  final int? statusCode;
  final String message;

  ApiException({this.statusCode, required this.message});

  @override
  String toString() => 'ApiException(statusCode: $statusCode, message: $message)';
}

/// Base HTTP service wrapping REST calls to Next.js API endpoints.
/// Injects Supabase auth tokens automatically.
class ApiService {
  final String baseUrl = apiBaseUrl;
  final SupabaseClient _supabase = Supabase.instance.client;

  /// Build request headers, injecting the Supabase user's JWT if available.
  Map<String, String> _getHeaders() {
    final headers = {
      'Content-Type': 'application/json',
      'Accept': 'application/json',
    };
    final session = _supabase.auth.currentSession;
    if (session != null) {
      headers['Authorization'] = 'Bearer ${session.accessToken}';
      // Debug: confirm we're actually sending the token. Strip in release.
      assert(() {
        final preview = session.accessToken.length > 16
            ? '${session.accessToken.substring(0, 16)}…'
            : session.accessToken;
        // ignore: avoid_print
        print('[ApiService] Bearer token attached (${preview})');
        return true;
      }());
    } else {
      assert(() {
        // ignore: avoid_print
        print('[ApiService] WARNING — no Supabase session, request will be unauthenticated');
        return true;
      }());
    }
    return headers;
  }

  /// Perform a GET request.
  Future<dynamic> get(String path) async {
    try {
      final uri = Uri.parse('$baseUrl$path');
      final response = await http.get(uri, headers: _getHeaders());
      return _processResponse(response);
    } catch (e) {
      if (e is ApiException) rethrow;
      throw ApiException(message: e.toString());
    }
  }

  /// Perform a POST request.
  Future<dynamic> post(String path, {dynamic body}) async {
    try {
      final uri = Uri.parse('$baseUrl$path');
      final response = await http.post(
        uri,
        headers: _getHeaders(),
        body: body != null ? jsonEncode(body) : null,
      );
      return _processResponse(response);
    } catch (e) {
      if (e is ApiException) rethrow;
      throw ApiException(message: e.toString());
    }
  }

  /// Perform a PATCH request.
  Future<dynamic> patch(String path, {dynamic body}) async {
    try {
      final uri = Uri.parse('$baseUrl$path');
      final response = await http.patch(
        uri,
        headers: _getHeaders(),
        body: body != null ? jsonEncode(body) : null,
      );
      return _processResponse(response);
    } catch (e) {
      if (e is ApiException) rethrow;
      throw ApiException(message: e.toString());
    }
  }

  /// Perform a DELETE request.
  Future<dynamic> delete(String path, {dynamic body}) async {
    try {
      final uri = Uri.parse('$baseUrl$path');
      final response = await http.delete(
        uri,
        headers: _getHeaders(),
        body: body != null ? jsonEncode(body) : null,
      );
      return _processResponse(response);
    } catch (e) {
      if (e is ApiException) rethrow;
      throw ApiException(message: e.toString());
    }
  }

  /// Process HTTP response and return JSON body, or throw ApiException.
  dynamic _processResponse(http.Response response) {
    final int statusCode = response.statusCode;
    dynamic body;
    try {
      body = jsonDecode(response.body);
    } catch (_) {
      body = response.body;
    }

    if (statusCode >= 200 && statusCode < 300) {
      return body;
    } else {
      String message = 'API Request failed';
      if (body is Map && body.containsKey('error')) {
        message = body['error'].toString();
      } else if (body is Map && body.containsKey('message')) {
        message = body['message'].toString();
      }
      throw ApiException(statusCode: statusCode, message: message);
    }
  }
}
