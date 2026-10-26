// ─── lib/services/api_service.dart ────────────────────────────────────────────
// Core HTTP client using Dio.
// - Automatically attaches Authorization: Bearer <token> when a token exists.
// - Accurately constructs URLs relative to ApiConfig.baseUrl.
// - Converts Dio errors into readable ApiException objects.
// - Supports GET, POST, PUT, DELETE with JSON request/response.
// ──────────────────────────────────────────────────────────────────────────────

import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import '../config/api_config.dart';
import '../core/api/api_exception.dart';
import '../storage/token_storage.dart';

class ApiService {
  late final Dio _dio;

  ApiService({Dio? dio}) {
    _dio = dio ?? Dio(
      BaseOptions(
        baseUrl: ApiConfig.baseUrl,
        connectTimeout: ApiConfig.connectTimeout,
        receiveTimeout: ApiConfig.receiveTimeout,
        headers: ApiConfig.defaultHeaders,
        validateStatus: (status) => status != null && status < 600,
      ),
    );

    // ── Interceptor: attach Bearer token to every request ──────────────────
    _dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) async {
          options.baseUrl = ApiConfig.baseUrl;
          final token = await TokenStorage.getToken();
          if (token != null && token.isNotEmpty) {
            options.headers['Authorization'] = 'Bearer $token';
          }
          handler.next(options);
        },
        onError: (error, handler) {
          handler.next(error);
        },
      ),
    );
  }

  /// Builds a fully-qualified URL respecting ApiConfig.baseUrl and avoiding /api duplication
  String _buildUrl(String endpoint) {
    if (endpoint.startsWith('http://') || endpoint.startsWith('https://')) {
      return endpoint;
    }
    final base = ApiConfig.baseUrl.replaceAll(RegExp(r'/+$'), '');
    final cleanEndpoint = endpoint.startsWith('/') ? endpoint : '/$endpoint';
    if (cleanEndpoint.startsWith('/uploads/')) {
      final serverRoot = base.endsWith('/api')
          ? base.substring(0, base.length - 4)
          : base;
      return '$serverRoot$cleanEndpoint';
    }
    if (base.endsWith('/api') && cleanEndpoint.startsWith('/api/')) {
      return '$base${cleanEndpoint.substring(4)}';
    }
    return '$base$cleanEndpoint';
  }

  // ── GET ────────────────────────────────────────────────────────────────────
  Future<dynamic> get(
    String endpoint, {
    Map<String, dynamic>? queryParams,
  }) async {
    try {
      final response = await _dio.get(
        _buildUrl(endpoint),
        queryParameters: queryParams,
      );
      return _handleResponse(response);
    } on DioException catch (e) {
      throw _mapDioError(e);
    }
  }

  // ── GET BYTES (Binary files, documents, authenticated downloads) ───────────
  Future<Uint8List> getBytes(String endpoint) async {
    try {
      final response = await _dio.get<List<int>>(
        _buildUrl(endpoint),
        options: Options(
          responseType: ResponseType.bytes,
          headers: {'Accept': '*/*'},
        ),
      );
      final status = response.statusCode ?? 0;
      if (status >= 200 && status < 300) {
        final data = response.data;
        if (data == null || data.isEmpty) {
          throw ApiException(
            statusCode: status,
            message: 'Empty response received from document server.',
          );
        }
        return Uint8List.fromList(data);
      }
      String? errorMsg;
      try {
        if (response.data != null) {
          final str = utf8.decode(response.data!);
          final json = jsonDecode(str);
          if (json is Map && json['message'] != null) {
            errorMsg = json['message'].toString();
          }
        }
      } catch (_) {}
      throw ApiException.fromResponse(
        statusCode: status,
        responseData: errorMsg != null ? {'message': errorMsg} : null,
      );
    } on DioException catch (e) {
      throw _mapDioError(e);
    }
  }

  // ── POST ───────────────────────────────────────────────────────────────────
  Future<dynamic> post(
    String endpoint, {
    Map<String, dynamic>? body,
    bool requiresAuth = true,
  }) async {
    try {
      final response = await _dio.post(_buildUrl(endpoint), data: body);
      return _handleResponse(response);
    } on DioException catch (e) {
      throw _mapDioError(e);
    }
  }

  // ── POST MULTIPART (File upload with form fields) ──────────────────────────
  Future<dynamic> postMultipart(
    String endpoint, {
    required Map<String, dynamic> fields,
    required String fileFieldName,
    required List<int> fileBytes,
    required String fileName,
  }) async {
    try {
      final map = <String, dynamic>{...fields};
      map[fileFieldName] = MultipartFile.fromBytes(
        fileBytes,
        filename: fileName,
      );
      final formData = FormData.fromMap(map);
      final response = await _dio.post(
        _buildUrl(endpoint),
        data: formData,
      );
      return _handleResponse(response);
    } on DioException catch (e) {
      throw _mapDioError(e);
    }
  }


  // ── PUT ────────────────────────────────────────────────────────────────────
  Future<dynamic> put(
    String endpoint, {
    Map<String, dynamic>? body,
  }) async {
    try {
      final response = await _dio.put(_buildUrl(endpoint), data: body);
      return _handleResponse(response);
    } on DioException catch (e) {
      throw _mapDioError(e);
    }
  }

  // ── DELETE ─────────────────────────────────────────────────────────────────
  Future<dynamic> delete(
    String endpoint, {
    Map<String, dynamic>? body,
  }) async {
    try {
      final response = await _dio.delete(_buildUrl(endpoint), data: body);
      return _handleResponse(response);
    } on DioException catch (e) {
      throw _mapDioError(e);
    }
  }

  // ── Response handler ───────────────────────────────────────────────────────
  dynamic _handleResponse(Response response) {
    final status = response.statusCode ?? 0;
    if (status >= 200 && status < 300) {
      return response.data;
    }
    throw ApiException.fromResponse(
      statusCode: status,
      responseData: response.data,
    );
  }

  // ── Dio error → ApiException ───────────────────────────────────────────────
  ApiException _mapDioError(DioException e) {
    switch (e.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.receiveTimeout:
      case DioExceptionType.sendTimeout:
        return ApiException.timeout();
      case DioExceptionType.connectionError:
        return ApiException.noConnection();
      case DioExceptionType.badResponse:
        return ApiException.fromResponse(
          statusCode: e.response?.statusCode ?? 0,
          responseData: e.response?.data,
        );
      default:
        return ApiException.unknown(e.message ?? e);
    }
  }
}
