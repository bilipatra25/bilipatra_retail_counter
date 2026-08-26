import 'product.dart';

class FreeProductOffer {
  final int id;
  final int branchId;
  final int buyProductId;
  final int buyQty;
  final int freeProductId;
  final int freeQty;
  final int isActive;
  final ProductModel freeProductDetail;

  FreeProductOffer({
    required this.id,
    required this.branchId,
    required this.buyProductId,
    required this.buyQty,
    required this.freeProductId,
    required this.freeQty,
    required this.isActive,
    required this.freeProductDetail,
  });

  factory FreeProductOffer.fromJson(Map<String, dynamic> json) {
    return FreeProductOffer(
      id: json['id'] ?? 0,
      branchId: json['branch_id'] ?? 0,
      buyProductId: json['buy_product_id'] ?? 0,
      buyQty: json['buy_qty'] ?? 0,
      freeProductId: json['free_product_id'] ?? 0,
      freeQty: json['free_qty'] ?? 0,
      isActive: json['is_active'] ?? 0,
      freeProductDetail: ProductModel(
        id: json['free_product_id'] ?? 0,
        name: json['product_name'] ?? json['free_product_name'] ?? 'Free Item',
        image: json['product_image'] ?? '',
        price: (json['product_price'] ?? 0).toDouble(),
        discountPrice: (json['product_discount_price'] ?? 0).toDouble(),
        description: json['product_description'] ?? '',
        weight: json['product_weight'] ?? '',
        manufactureBy: json['manufacture_by'] ?? '',
        mfd: DateTime.tryParse(json['product_mfd']?.toString() ?? '') ?? DateTime.now(),
        expiry: DateTime.tryParse(json['product_expiry_date']?.toString() ?? '') ?? DateTime.now(),
      ),
    );
  }
}
