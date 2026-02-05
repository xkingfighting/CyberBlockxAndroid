/// API Response Wrapper
class ApiResponse<T> {
  final bool isSuccess;
  final T? data;
  final String? errorMessage;
  final String? errorCode;
  final int? statusCode;

  ApiResponse._({
    required this.isSuccess,
    this.data,
    this.errorMessage,
    this.errorCode,
    this.statusCode,
  });

  factory ApiResponse.success(T data) {
    return ApiResponse._(isSuccess: true, data: data);
  }

  factory ApiResponse.failure(
    String message, {
    String? errorCode,
    int? statusCode,
  }) {
    return ApiResponse._(
      isSuccess: false,
      errorMessage: message,
      errorCode: errorCode,
      statusCode: statusCode,
    );
  }
}
