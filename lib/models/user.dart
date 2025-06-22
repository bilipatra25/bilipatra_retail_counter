class UserModel {
  final int id;
  final String name;
  final String number;
  final String address;

  UserModel({
    required this.id,
    required this.name,
    required this.number,
    required this.address,
  });

  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      id: json['customer_id'],
      name: json['customer_name'] ?? '',
      number: json['mobile_no'].toString(),
      address: json['address'] ?? '',
    );
  }
}
