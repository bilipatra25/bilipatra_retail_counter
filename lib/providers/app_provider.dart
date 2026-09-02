import 'package:flutter/material.dart';
import '../models/cart_item_model.dart';
import '../models/user.dart';
import '../models/product.dart';
import '../models/free_product_offer_model.dart';

class AppProvider with ChangeNotifier {
  List<FreeProductOffer> _freeOffers = [];
  bool _isAutoDiscountEnabled = false;
  bool get isAutoDiscountEnabled => _isAutoDiscountEnabled;
  List<FreeProductOffer> get freeOffers => _freeOffers;

  void toggleAutoDiscount(bool enable) {
    _isAutoDiscountEnabled = enable;
    _isGlobalDiscountManual = !enable;
    if (enable) {
      _updateAutoGlobalDiscount();
    } else {
      _globalDiscountType = DiscountType.none;
      _globalDiscountValue = 0.0;
    }
    notifyListeners();
  }

  void setGlobalConfigs(bool autoDiscount, DiscountBase base) {
    _isAutoDiscountEnabled = autoDiscount;
    _globalDiscountBase = base;
    _updateAutoGlobalDiscount();
    notifyListeners();
  }

  void setFreeOffers(List<FreeProductOffer> offers) {
    _freeOffers = offers;
    _syncFreeItems();
  }

  void _syncFreeItems() {
    if (_freeOffers.isEmpty) return;
    Map<int, int> buyCounts = {};
    for (var item in _cart) {
      if (!item.isFreeItem) {
        buyCounts[item.product.id] = (buyCounts[item.product.id] ?? 0) + item.quantity;
      }
    }
    Map<int, FreeProductOffer> earned = {};
    for (var offer in _freeOffers) {
      int bought = buyCounts[offer.buyProductId] ?? 0;
      int bundles = (bought / offer.buyQty).floor();
      if (bundles > 0) {
        if (!earned.containsKey(offer.freeProductId)) {
          earned[offer.freeProductId] = FreeProductOffer(
            id: offer.id, branchId: offer.branchId, buyProductId: offer.buyProductId,
            buyQty: offer.buyQty, freeProductId: offer.freeProductId,
            freeQty: bundles * offer.freeQty, isActive: offer.isActive,
            freeProductDetail: offer.freeProductDetail,
          );
        } else {
          var existing = earned[offer.freeProductId]!;
          earned[offer.freeProductId] = FreeProductOffer(
            id: existing.id, branchId: existing.branchId, buyProductId: existing.buyProductId,
            buyQty: existing.buyQty, freeProductId: existing.freeProductId,
            freeQty: existing.freeQty + (bundles * offer.freeQty), isActive: existing.isActive,
            freeProductDetail: existing.freeProductDetail,
          );
        }
      }
    }
    _cart.removeWhere((item) => item.isFreeItem);
    earned.values.forEach((offer) {
      _cart.add(CartItem(
        product: offer.freeProductDetail,
        quantity: offer.freeQty,
        isFreeItem: true,
        hasCustomDiscount: false,
        discountType: DiscountType.none,
        discountValue: 0.0,
        discountBase: _globalDiscountBase,
      ));
    });
    notifyListeners();
  }
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
      (item) => item.product.id == product.id && !item.isFreeItem,
    );
    if (existingIndex >= 0) {
      _cart[existingIndex].quantity++;
    } else {
      _cart.add(CartItem(product: product));
    }
    _updateAutoGlobalDiscount();
    _syncFreeItems();
    notifyListeners();
  }

  void decrementQuantity(ProductModel product) {
    final existingIndex = _cart.indexWhere(
      (item) => item.product.id == product.id && !item.isFreeItem,
    );
    if (existingIndex >= 0) {
      if (_cart[existingIndex].quantity > 1) {
        _cart[existingIndex].quantity--;
      } else {
        _cart.removeAt(existingIndex);
      }
      _updateAutoGlobalDiscount();
    _syncFreeItems();
    notifyListeners();
    }
  }

  void setItemQuantity(ProductModel product, int quantity) {
    if (quantity <= 0) {
      removeCartItem(product);
      return;
    }
    final existingIndex = _cart.indexWhere(
      (item) => item.product.id == product.id && !item.isFreeItem,
    );
    if (existingIndex >= 0) {
      _cart[existingIndex].quantity = quantity;
    } else {
      _cart.add(CartItem(product: product, quantity: quantity));
    }
    _updateAutoGlobalDiscount();
    _syncFreeItems();
    notifyListeners();
  }

  void removeCartItem(ProductModel product) {
    _cart.removeWhere((item) => item.product.id == product.id && !item.isFreeItem);
    _updateAutoGlobalDiscount();
    _syncFreeItems();
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
  void applyCartDiscount(
    DiscountType type,
    double value,
    DiscountBase base, {
    bool isManual = true,
  }) {
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

  // 🟢 NEW: Check if item is eligible for auto-qty discount (>= 200g)
  bool _isEligibleForAutoDiscount(CartItem item) {
    return true;

    //Special product exception
    /*if (item.product.name.contains('Diabo')) {
      return true;
    }*/

    String weightStr = item.product.weight.toLowerCase();
    double value = 0;

    // Extract numeric part
    RegExp regExp = RegExp(r'(\d+\.?\d*)');
    var match = regExp.firstMatch(weightStr);
    if (match != null) {
      value = double.tryParse(match.group(1)!) ?? 0;
    }

    if (weightStr.contains('kg')) {
      value *= 1000;
    }

    return value >= 200;
  }

  // 🟢 NEW: Auto Qty Discount Logic (Now sets Global)
  void _updateAutoGlobalDiscount() {
    if (_cart.isEmpty) {
      _globalDiscountType = DiscountType.none;
      _globalDiscountValue = 0.0;
      _isGlobalDiscountManual = false;
      return;
    }
    
    if (_isGlobalDiscountManual) return;

    if (!_isAutoDiscountEnabled) {
      _globalDiscountType = DiscountType.none;
      _globalDiscountValue = 0.0;
      return;
    }

    int eligibleQty = _cart.fold(0, (sum, item) {
      if (item.isFreeItem) return sum;
      return sum + (_isEligibleForAutoDiscount(item) ? item.quantity : 0);
    });

    double percent = 0.0;
    if (eligibleQty >= 6)
      percent = 25.0;
    else if (eligibleQty >= 3)
      percent = 20.0;
    else if (eligibleQty >= 2)
      percent = 15.0;
    else if (eligibleQty >= 1)
      percent = 10.0;

    _globalDiscountType =
        percent > 0 ? DiscountType.percent : DiscountType.none;
    _globalDiscountValue = percent;
    _globalDiscountBase = DiscountBase.sellingPrice;
  }

  // Gets the exact discount for a specific item, respecting overrides
  double getItemCalculatedDiscount(CartItem item) {
    if (item.isFreeItem) return 0.0;

    // 1. ISOLATED OVERRIDE: If the item has a custom discount, it ONLY gets this.
    if (item.hasCustomDiscount) {
      return item.calculateDiscountAmount(
        item.discountType,
        item.discountValue,
        item.discountBase,
      );
    }

    // 2. GLOBAL DISCOUNT
    if (_globalDiscountValue > 0) {
      // 🟢 SPECIAL CASE: If in Auto Mode, only apply to >= 200g items
      if (!_isGlobalDiscountManual && !_isEligibleForAutoDiscount(item)) {
        return 0.0;
      }

      double globalBaseAmount =
          _globalDiscountBase == DiscountBase.mrp
              ? item.totalMrp
              : item.totalSellingPrice;

      if (_globalDiscountType == DiscountType.percent) {
        return (globalBaseAmount * _globalDiscountValue) / 100;
      } else if (_globalDiscountType == DiscountType.flat) {
        // Find the total value of ONLY the items that are eligible for the global discount
        double cartEligibleTotal = _cart.fold(0.0, (sum, cartItem) {
          if (cartItem.isFreeItem) return sum;
          if (cartItem.hasCustomDiscount) return sum; // Skip overridden items!
          // In Auto Mode, also skip small items for flat distribution (though auto is usually percent)
          if (!_isGlobalDiscountManual && !_isEligibleForAutoDiscount(cartItem)) {
            return sum;
          }

          return sum +
              (_globalDiscountBase == DiscountBase.mrp
                  ? cartItem.totalMrp
                  : cartItem.totalSellingPrice);
        });

        // Distribute the flat global discount proportionally
        if (cartEligibleTotal > 0) {
          return _globalDiscountValue * (globalBaseAmount / cartEligibleTotal);
        }
      }
    }

    return 0.0; // No discount applies
  }

  double getItemFinalTotal(CartItem item) {
    final finalPrice = item.totalSellingPrice - getItemCalculatedDiscount(item);
    return finalPrice < 0 ? 0.0 : finalPrice;
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
    List<CartItem> previousItems, {
    DiscountType globalDiscountType = DiscountType.none,
    double globalDiscountValue = 0.0,
    double previouslyPaid = 0.0,
  }) {
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

