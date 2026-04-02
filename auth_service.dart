import "dart:convert";
import "package:dio/dio.dart";
import 'package:cookie_jar/cookie_jar.dart';
import 'package:dio_cookie_manager/dio_cookie_manager.dart';

class AuthService {
  static const String _baseUrl = 'http://10.0.2.2:8080/api/auth';

  static final CookieJar _cookieJar = CookieJar();

  static final Dio _dio = Dio(BaseOptions(
    baseUrl: _baseUrl,
    contentType: 'application/json',
    validateStatus: (_) => true,
  ))
    ..interceptors.add(CookieManager(_cookieJar));

  static Future<Map<String, dynamic>> register({
    required String name,
    required String email,
    required String phone,
    required String password,
    required String confirmPassword,
  }) async {
    try {
      final response = await _dio.post('/register', data: {
        'name': name,
        'email': email,
        'phone': phone,
        'password': password,
        'confirmPassword': confirmPassword,
      });

      if (response.statusCode == 201) {
        return {'success': true, 'data': response.data};
      } else {
        return {
          'success': false,
          'error': response.data['error'] ?? 'Registration failed',
        };
      }
    } catch (e) {
      return {'success': false, 'error': 'Network error. Check your connection.'};
    }
  }

  static Future<Map<String, dynamic>> login({
    required String email,
    required String password,
  }) async {
    try {
      final response = await _dio.post('/login', data: {
        'email': email,
        'password': password,
      });

      if (response.statusCode == 200) {
        return {'success': true, 'data': response.data};
      } else {
        return {
          'success': false,
          'error': response.data['error'] ?? 'Login failed',
        };
      }
    } catch (e) {
      return {'success': false, 'error': 'Network error. Check your connection.'};
    }
  }

  static Future<Map<String, dynamic>> logout() async {
    try {
      final response = await _dio.post('/logout');
      await _cookieJar.deleteAll();
      return {'success': response.statusCode == 200};
    } catch (e) {
      return {'success': false, 'error': 'Network error.'};
    }
  }

  static Future<Map<String, dynamic>> getCurrentUser() async {
    try {
      final response = await _dio.get('/me');
      if (response.statusCode == 200) {
        return {'success': true, 'data': response.data};
      } else {
        return {'success': false, 'error': response.data['error'] ?? 'Not logged in'};
      }
    } catch (e) {
      return {'success': false, 'error': 'Network error.'};
    }
  }

  static Future<Map<String, dynamic>> updateProfile({
    required String name,
    required String email,
    required String phone,
  }) async {
    try {
      final response = await _dio.put('/profile', data: {
        'name':  name,
        'email': email,
        'phone': phone,
      });

      if (response.statusCode == 200) {
        return {'success': true, 'data': response.data};
      } else {
        return {
          'success': false,
          'error': response.data['error']
              ?? response.data['message']
              ?? 'Update failed',
        };
      }
    } catch (e) {
      return {'success': false, 'error': 'Network error. Check your connection.'};
    }
  }
}
