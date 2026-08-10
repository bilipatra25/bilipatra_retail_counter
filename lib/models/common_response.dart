class CommonResponse {
  final int flag;
  final int code;
  final String message;

  CommonResponse({
    required this.flag,
    required this.code,
    required this.message,
  });

  factory CommonResponse.fromJson(Map<String, dynamic> json) {
    return CommonResponse(
      flag: json['flag'],
      code: json['code'],
      message: json['message'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'flag': flag,
      'code': code,
      'message': message,
    };
  }
}
