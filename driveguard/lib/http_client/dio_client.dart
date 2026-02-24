import 'package:dio/dio.dart';
import 'package:pretty_dio_logger/pretty_dio_logger.dart';

class DioClient {
  final dio = Dio(
    BaseOptions(
      baseUrl: "",
      connectTimeout: Duration(seconds: 5000),
      receiveTimeout: Duration(seconds: 3000),
    ),
  );

  DioClient() {
    dio.interceptors.add(
      PrettyDioLogger(
        requestHeader: true,
        requestBody: true,
        responseHeader: false,
        responseBody: true,
        error: true,
        compact: false,
        maxWidth: 90,
      ),
    );
  }
}
