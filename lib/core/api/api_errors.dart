import 'package:dio/dio.dart';

import '../constants/strings_ar.dart';

String extractApiError(DioException e) {
  if (e.type == DioExceptionType.connectionError ||
      e.type == DioExceptionType.connectionTimeout ||
      e.type == DioExceptionType.receiveTimeout) {
    return 'تعذر الاتصال بالخادم. تحقق من الإنترنت وعنوان API.';
  }

  final raw = e.response?.data;
  if (raw is Map && raw['error'] != null) {
    return raw['error'].toString();
  }

  if (raw is String) {
    if (raw.contains('DEPLOYMENT_NOT_FOUND')) {
      return 'عنوان API غير صحيح أو منتهي. حدّث API_BASE_URL من لوحة Vercel.';
    }
    if (raw.contains('<!DOCTYPE html>') || raw.contains('<html')) {
      return 'الخادم أرجع صفحة HTML بدل JSON. تحقق من عنوان API_BASE_URL.';
    }
  }

  final status = e.response?.statusCode;
  if (status == 401) {
    return 'انتهت الجلسة بعد ساعة من عدم الاستخدام. سجّل الدخول مرة أخرى.';
  }
  if (status == 404) return 'غير موجود على الخادم. تأكد أن الـ API محدّث على Vercel.';
  if (status == 400) return 'بيانات غير صالحة';
  if (status == 500) return 'خطأ في الخادم. حاول لاحقاً.';
  if (status != null) return 'خطأ من الخادم ($status)';

  return 'حدث خطأ غير متوقع';
}

String formatAppError(Object error) {
  if (error is DioException) {
    return extractApiError(error);
  }
  if (error is Exception) {
    return error.toString().replaceFirst('Exception: ', '');
  }
  return StringsAr.error;
}
