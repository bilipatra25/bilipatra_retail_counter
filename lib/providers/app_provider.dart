import 'package:flutter/material.dart';
import '../models/cart_item_model.dart';
import '../models/user.dart';
import '../models/product.dart';

class AppProvider with ChangeNotifier {
  // --- Customer State ---
  UserModel? _selectedCustomer;
  // final int defaultWalkInId = 1; //Testing
  final int defaultWalkInId = 0; // Walk In User
  UserModel? get selectedCustomer => _selectedCustomer;
  int get activeCustomerId => _selectedCustomer?.id ?? defaultWalkInId;

  int? _editingOrderId;

  int? get editingOrderId => _editingOrderId;
  bool get isEditingOrder => _editingOrderId != null;

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
  bool _isGlobalDiscountManual = false;

  DiscountType get globalDiscountType => _globalDiscountType;
  double get globalDiscountValue => _globalDiscountValue;
  DiscountBase get globalDiscountBase => _globalDiscountBase;
  bool get isGlobalDiscountManual => _isGlobalDiscountManual;

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
    _updateAutoGlobalDiscount();
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
      _updateAutoGlobalDiscount();
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
    _updateAutoGlobalDiscount();
    notifyListeners();
  }

  void removeCartItem(ProductModel product) {
    _cart.removeWhere((item) => item.product.id == product.id);
    _updateAutoGlobalDiscount();
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
  void applyCartDiscount(DiscountType type, double value, DiscountBase base,
      {bool isManual = true}) {
    _isGlobalDiscountManual = isManual;
    _globalDiscountType = type;
    _globalDiscountValue = value;
    _globalDiscountBase = base;

    if (!_isGlobalDiscountManual) {
      _updateAutoGlobalDiscount();
    }

    notifyListeners();
  }

  // --- Dynamic Math Calculations ---

  // 🟢 NEW: Auto Qty Discount Logic (Now sets Global)
  void _updateAutoGlobalDiscount() {
    if (_isGlobalDiscountManual) return;

    int totalQty = totalItems;
    double percent = 0.0;
    if (totalQty >= 6)
      percent = 25.0;
    else if (totalQty >= 4)
      percent = 20.0; // Covers 4 and 5
    else if (totalQty >= 3)
      percent = 15.0;
    else if (totalQty >= 2)
      percent = 10.0;
    else if (totalQty >= 1) percent = 5.0;

    _globalDiscountType = percent > 0 ? DiscountType.percent : DiscountType.none;
    _globalDiscountValue = percent;
    _globalDiscountBase = DiscountBase.sellingPrice;
  }

  // Gets the exact discount for a specific item, respecting overrides
  double getItemCalculatedDiscount(CartItem item) {
    double baseAmount =
        item.discountBase == DiscountBase.mrp
            ? item.totalMrp
            : item.totalSellingPrice;

    // 1. ISOLATED OVERRIDE: If the item has a custom discount, it ONLY gets this.
    if (item.hasCustomDiscount) {
      return item.calculateDiscountAmount(
        item.discountType,
        item.discountValue,
        item.discountBase,
      );
    }

    // 2. GLOBAL ONLY: apply the global cart discount (which might be auto-calculated).
    if (_globalDiscountValue > 0) {
      if (_globalDiscountType == DiscountType.percent) {
        return (baseAmount * _globalDiscountValue) / 100;
      } else if (_globalDiscountType == DiscountType.flat) {
        // Find the total value of ONLY the items that are eligible for the global discount
        double cartEligibleTotal = _cart.fold(0.0, (sum, cartItem) {
          if (cartItem.hasCustomDiscount) return sum; // Skip overridden items!
          return sum +
              (cartItem.discountBase == DiscountBase.mrp
                  ? cartItem.totalMrp
                  : cartItem.totalSellingPrice);
        });

        // Distribute the flat global discount proportionally
        if (cartEligibleTotal > 0) {
          return _globalDiscountValue * (baseAmount / cartEligibleTotal);
        }
      }
    }

    return 0.0; // No discount applies
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

  // 🟢 NEW: Track how much was paid on the previous bill
  double _previouslyPaidAmount = 0.0;

  double get previouslyPaidAmount => _previouslyPaidAmount;
  // If positive, customer owes us. If negative, we owe customer a refund.
  double get balanceDue => cartFinalTotal - _previouslyPaidAmount;


  // 🟢 UPDATED: Now accepts the previouslyPaid parameter
  void loadExistingOrder(
      int orderId,
      UserModel customer,
      List<CartItem> previousItems,
      {DiscountType globalDiscountType = DiscountType.none, double globalDiscountValue = 0.0, double previouslyPaid = 0.0}
      ) {
    _cart.clear();
    _globalDiscountType = globalDiscountType;
    _globalDiscountValue = globalDiscountValue;
    _isGlobalDiscountManual = true; // Loaded orders should not auto-adjust
    _editingOrderId = orderId;
    _selectedCustomer = customer;

    // 🟢 Save the paid amount to state!
    _previouslyPaidAmount = previouslyPaid;

    _cart.addAll(previousItems);
    notifyListeners();
  }

  // 🟢 UPDATED: Make sure to reset the paid amount when closing the cart
  void clearCartAndCustomer() {
    _cart.clear();
    _selectedCustomer = null;
    _globalDiscountType = DiscountType.none;
    _globalDiscountValue = 0.0;
    _isGlobalDiscountManual = false;
    _editingOrderId = null;
    _previouslyPaidAmount = 0.0; // Reset
    notifyListeners();
  }
}
