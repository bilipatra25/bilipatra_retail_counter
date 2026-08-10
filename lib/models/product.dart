class ProductModel {
  final int id;
  final String name;
  final String image;
  final double price;
  final double discountPrice;
  final String description;
  final String weight;
  final String manufactureBy;
  final DateTime mfd;
  final DateTime expiry;
  int quantity;

  ProductModel({
    required this.id,
    required this.name,
    required this.image,
    required this.price,
    required this.discountPrice,
    required this.description,
    required this.weight,
    required this.manufactureBy,
    required this.mfd,
    required this.expiry,
    this.quantity = 0,
  });

  factory ProductModel.fromJson(Map<String, dynamic> json) {
    return ProductModel(
      id: json['product_id'],
      name: json['product_name'] ?? '',
      image: json['product_image'] ?? '',
      price: (json['product_price'] ?? 0).toDouble(),
      discountPrice: (json['product_discount_price'] ?? 0).toDouble(),
      description: json['product_description'] ?? '',
      weight: json['product_weight'] ?? '',
      manufactureBy: json['manufacture_by'] ?? '',
      mfd: DateTime.parse(json['product_mfd']),
      expiry: DateTime.parse(json['product_expiry_date']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'product_id': id,
      'product_name': name,
      'product_image': image,
      'product_price': price,
      'product_discount_price': discountPrice,
      'product_description': description,
      'product_weight': weight,
      'manufacture_by': manufactureBy,
      'product_mfd': mfd.toIso8601String(),
      'product_expiry_date': expiry.toIso8601String(),
    };
  }

  ProductModel copyWith({
    int? quantity,
  }) {
    return ProductModel(
      id: id,
      name: name,
      image: image,
      price: price,
      discountPrice: discountPrice,
      description: description,
      weight: weight,
      manufactureBy: manufactureBy,
      mfd: mfd,
      expiry: expiry,
      quantity: quantity ?? this.quantity,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
          other is ProductModel && runtimeType == other.runtimeType && id == other.id;

  @override
  int get hashCode => id.hashCode;
}

