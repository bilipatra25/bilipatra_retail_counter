import '../models/product.dart';

enum DiscountType { none, flat, percent }
enum DiscountBase { mrp, sellingPrice }

class CartItem {
  bool isFreeItem;
  final ProductModel product;
  int quantity;

  // Item-level override flags
  bool hasCustomDiscount;
  DiscountType discountType;
  double discountValue;
  DiscountBase discountBase;

  CartItem({
    required this.product,
    this.quantity = 1,
    this.isFreeItem = false,
    this.hasCustomDiscount = false,
    this.discountType = DiscountType.none,
    this.discountValue = 0.0,
    this.discountBase = DiscountBase.sellingPrice,
  });

  // Base pricing calculators
  double get totalMrp => isFreeItem ? 0.0 : product.price * quantity;
  double get totalSellingPrice {
    if (isFreeItem) return 0.0;
    double basePrice = product.discountPrice > 0 ? product.discountPrice : product.price;
    return basePrice * quantity;
  }

  // This method calculates the discount based on whatever rule is passed to it
  double calculateDiscountAmount(DiscountType type, double value, DiscountBase base) {
    if (type == DiscountType.none || value == 0) return 0.0;

    double targetTotal = base == DiscountBase.mrp ? totalMrp : totalSellingPrice;

    if (type == DiscountType.flat) {
      return value; // Flat ₹ is applied as-is
    } else if (type == DiscountType.percent) {
      return targetTotal * (value / 100);
    }
    return 0.0;
  }
}