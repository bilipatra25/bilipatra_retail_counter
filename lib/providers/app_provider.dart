import 'package:flutter/material.dart';
import '../models/cart_item_model.dart';
import '../models/user.dart';
import '../models/product.dart';

class AppProvider with ChangeNotifier {
  // --- Customer State ---
  UserModel? _selectedCustomer;
  final int defaultWalkInId = 1;
  UserModel? get selectedCustomer => _selectedCustomer;
  int get activeCustomerId => _selectedCustomer?.id ?? defaultWalkInId;

  void setCustomer(UserModel user) {
    _selectedCustomer = user;
    notifyListeners();
  }

  void clearCustomer() {
    _selectedCustomer = null;
    notifyListeners();
  }

  // --- Cart State ---
  final List<CartItem> _cart = [];
  List<CartItem> get cart => _cart;

  // --- Global Cart Discount State ---
  DiscountType _globalDiscountType = DiscountType.none;
  double _globalDiscountValue = 0.0;
  DiscountBase _globalDiscountBase = DiscountBase.sellingPrice;

  DiscountType get globalDiscountType => _globalDiscountType;
  double get globalDiscountValue => _globalDiscountValue;
  DiscountBase get globalDiscountBase => _globalDiscountBase;

  // --- Methods ---
  void addProduct(ProductModel product) {
    final existingIndex = _cart.indexWhere(
      (item) => item.product.id == product.id,
    );
    if (existingIndex >= 0) {
      _cart[existingIndex].quantity++;
    } else {
      _cart.add(CartItem(product: product));
    }
    notifyListeners();
  }

  void decrementQuantity(ProductModel product) {
    final existingIndex = _cart.indexWhere(
      (item) => item.product.id == product.id,
    );
    if (existingIndex >= 0) {
      if (_cart[existingIndex].quantity > 1) {
        _cart[existingIndex].quantity--;
      } else {
        _cart.removeAt(existingIndex);
      }
      notifyListeners();
    }
  }

  void setItemQuantity(ProductModel product, int quantity) {
    if (quantity <= 0) {
      removeCartItem(product);
      return;
    }
    final existingIndex = _cart.indexWhere(
      (item) => item.product.id == product.id,
    );
    if (existingIndex >= 0) {
      _cart[existingIndex].quantity = quantity;
    } else {
      _cart.add(CartItem(product: product, quantity: quantity));
    }
    notifyListeners();
  }

  void removeCartItem(ProductModel product) {
    _cart.removeWhere((item) => item.product.id == product.id);
    notifyListeners();
  }

  // 🟢 Item-Level Override Logic
  void applyItemDiscount(
    ProductModel product,
    DiscountType type,
    double value,
    DiscountBase base,
  ) {
    final existingIndex = _cart.indexWhere(
      (item) => item.product.id == product.id,
    );
    if (existingIndex >= 0) {
      _cart[existingIndex].hasCustomDiscount =
          (type != DiscountType.none && value > 0);
      _cart[existingIndex].discountType = type;
      _cart[existingIndex].discountValue = value;
      _cart[existingIndex].discountBase = base;
      notifyListeners();
    }
  }

  // 🟢 Cart-Level Distribution Logic
  void applyCartDiscount(DiscountType type, double value, DiscountBase base) {
    _globalDiscountType = type;
    _globalDiscountValue = value;
    _globalDiscountBase = base;

    // Optional: If you apply a global cart discount, do you want to wipe out existing item overrides?
    // Uncomment the next 3 lines if YES. Leave commented if NO.
    // for (var item in _cart) {
    //   item.hasCustomDiscount = false;
    // }

    notifyListeners();
  }

  // --- Dynamic Math Calculations ---

  // Gets the exact discount for a specific item, respecting overrides
  double getItemCalculatedDiscount(CartItem item) {
    if (item.hasCustomDiscount) {
      return item.calculateDiscountAmount(
        item.discountType,
        item.discountValue,
        item.discountBase,
      );
    } else {
      // If it's a global FLAT discount, we divide it proportionally across non-overridden items
      // For simplicity here, we assume Flat Cart discounts are distributed equally, or we use percent.
      // Usually, Global is a percentage.
      return item.calculateDiscountAmount(
        _globalDiscountType,
        _globalDiscountValue,
        _globalDiscountBase,
      );
    }
  }

  double getItemFinalTotal(CartItem item) {
    return item.totalSellingPrice - getItemCalculatedDiscount(item);
  }

  double get cartSubtotal =>
      _cart.fold(0.0, (sum, item) => sum + item.totalSellingPrice);

  double get cartTotalDiscount =>
      _cart.fold(0.0, (sum, item) => sum + getItemCalculatedDiscount(item));

  double get cartFinalTotal =>
      _cart.fold(0.0, (sum, item) => sum + getItemFinalTotal(item));

  int get totalItems => _cart.fold(0, (sum, item) => sum + item.quantity);

  void clearCartAndCustomer() {
    _cart.clear();
    _selectedCustomer = null;
    _globalDiscountType = DiscountType.none;
    _globalDiscountValue = 0.0;
    notifyListeners();
  }
}
