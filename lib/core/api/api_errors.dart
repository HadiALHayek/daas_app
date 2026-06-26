import 'package:dio/dio.dart';

String extractApiError(DioException e) {
  if (e.type == DioExceptionType.connectionError ||
      e.type == DioExceptionType.connectionTimeout ||
      e.type == DioExceptionType.receiveTimeout) {
    return 'تعذر الاتصال بالخادم. تحقق من الإنترنت وعنوان API.';
  }

  final data = e.response?.data;
  if (data is Map && data['error'] != null) {
    return data['error'].toString();
  }

  final status = e.response?.statusCode;
  if (status == 401) return 'انتهت الجلسة. سجّل الدخول مرة أخرى.';
  if (status == 404) return 'غير موجود على الخادم';
  if (status == 400) return 'بيانات غير صالحة';
  if (status != null) return 'خطأ من الخادم ($status)';

  return 'حدث خطأ غير متوقع';
}
