import 'package:flutter/material.dart';

import '../../models/cart_item_model.dart';
import '../../providers/app_provider.dart';

class DiscountBottomSheet extends StatefulWidget {
  final AppProvider provider;
  final CartItem? specificItem;

  const DiscountBottomSheet({
    Key? key,
    required this.provider,
    this.specificItem,
  }) : super(key: key);

  /// Helper method to easily show the bottom sheet
  static void show(
    BuildContext context, {
    required AppProvider provider,
    CartItem? specificItem,
  }) {
    showModalBottomSheet(
      context: context,
      isScrollControlled:
          true, // Important: allows it to resize when keyboard appears
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder:
          (context) => Padding(
            // Add padding for the keyboard
            padding: EdgeInsets.only(
              bottom: MediaQuery.of(context).viewInsets.bottom,
            ),
            child: SafeArea(
              child: DiscountBottomSheet(
                provider: provider,
                specificItem: specificItem,
              ),
            ),
          ),
    );
  }

  @override
  State<DiscountBottomSheet> createState() => _DiscountBottomSheetState();
}

class _DiscountBottomSheetState extends State<DiscountBottomSheet> {
  late TextEditingController _discountController;
  late FocusNode _inputFocus;
  late DiscountType _selectedType;
  late DiscountBase _selectedBase;

  @override
  void initState() {
    super.initState();
    final provider = widget.provider;
    final specificItem = widget.specificItem;

    _selectedType =
        specificItem != null
            ? (specificItem.discountType == DiscountType.none
                ? DiscountType.percent
                : specificItem.discountType)
            : (provider.globalDiscountType == DiscountType.none
                ? DiscountType.percent
                : provider.globalDiscountType);

    _selectedBase =
        specificItem != null
            ? specificItem.discountBase
            : provider.globalDiscountBase;

    double initialValue =
        specificItem != null
            ? specificItem.discountValue
            : provider.globalDiscountValue;
    _discountController = TextEditingController(
      text: initialValue == 0 ? "" : initialValue.toStringAsFixed(0),
    );
    _inputFocus = FocusNode();
  }

  @override
  void dispose() {
    _discountController.dispose();
    _inputFocus.dispose();
    super.dispose();
  }

  void _applyDiscount() {
    final val = double.tryParse(_discountController.text) ?? 0;
    if (widget.specificItem != null) {
      widget.provider.applyItemDiscount(
        widget.specificItem!.product,
        val > 0 ? _selectedType : DiscountType.none,
        val,
        _selectedBase,
      );
    } else {
      widget.provider.applyCartDiscount(
        val > 0 ? _selectedType : DiscountType.none,
        val,
        _selectedBase,
        isManual: true,
      );
    }
    Navigator.pop(context);
  }

  Widget _buildToggleButton(String text, bool isSelected, VoidCallback onTap) {
    bool isAutoMode = widget.specificItem == null && widget.provider.isAutoDiscountEnabled && !widget.provider.isGlobalDiscountManual;
    return Expanded(
      child: GestureDetector(
        onTap: isAutoMode ? null : onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: isSelected ? Colors.blue.shade700 : Colors.grey.shade100,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: isSelected ? Colors.blue.shade700 : Colors.grey.shade300,
            ),
          ),
          alignment: Alignment.center,
          child: Text(
            text,
            style: TextStyle(
              color: isSelected ? Colors.white : Colors.black87,
              fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
              fontSize: 13,
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final provider = widget.provider;
    final specificItem = widget.specificItem;
    final bool isAutoMode = specificItem == null && provider.isAutoDiscountEnabled && !provider.isGlobalDiscountManual;

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment:
            CrossAxisAlignment.stretch, // Make elements fill width
        children: [
          // Drag Handle
          Center(
            child: Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),

          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.local_offer,
                  color: Colors.blue.shade700,
                  size: 24,
                ),
              ),
              const SizedBox(width: 12),
              Text(
                specificItem != null ? 'Item Discount' : 'Global Discount',
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 20,
                ),
              ),
              const Spacer(),
              IconButton(
                icon: const Icon(Icons.close, color: Colors.grey),
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),
          const SizedBox(height: 16),

          if (specificItem == null) ...[
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      "Automatic Qty Discount",
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                    Text(
                      (!provider.isAutoDiscountEnabled || provider.isGlobalDiscountManual)
                          ? "Currently: AUTO DISCOUNT OFF"
                          : "Currently: AUTO CALCULATING",
                      style: TextStyle(
                        fontSize: 11,
                        color:
                            (!provider.isAutoDiscountEnabled || provider.isGlobalDiscountManual)
                                ? Colors.grey.shade600
                                : Colors.green.shade800,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
                Switch(
                  value: provider.isAutoDiscountEnabled && !provider.isGlobalDiscountManual,
                  activeThumbColor: Colors.green,
                  onChanged: (val) {
                    setState(() {
                      provider.toggleAutoDiscount(val);
                      if (val) {
                        _discountController.text = provider.globalDiscountValue > 0
                            ? provider.globalDiscountValue.toStringAsFixed(0)
                            : "";
                      } else {
                        _discountController.clear();
                      }
                    });
                  },
                ),
              ],
            ),
            const Divider(height: 24),
          ],

          TextField(
            controller: _discountController,
            readOnly: isAutoMode,
            focusNode: _inputFocus,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            textInputAction: TextInputAction.done,
            onSubmitted: (_) => _applyDiscount(),
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            decoration: InputDecoration(
              labelText: 'Discount Value',
              prefixText: _selectedType == DiscountType.flat ? '₹ ' : '',
              suffixText: _selectedType == DiscountType.percent ? '%' : '',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              filled: true,
              fillColor:
                  isAutoMode ? Colors.grey.shade200 : Colors.blue.shade50,
            ),
          ),
          const SizedBox(height: 20),

          AbsorbPointer(
            absorbing: isAutoMode,
            child: Opacity(
              opacity: isAutoMode ? 0.5 : 1.0,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    "DISCOUNT TYPE",
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: Colors.grey,
                      letterSpacing: 1.2,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      _buildToggleButton(
                        "Percentage (%)",
                        _selectedType == DiscountType.percent,
                        () => setState(
                          () => _selectedType = DiscountType.percent,
                        ),
                      ),
                      const SizedBox(width: 12),
                      _buildToggleButton(
                        "Flat (₹)",
                        _selectedType == DiscountType.flat,
                        () => setState(() => _selectedType = DiscountType.flat),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  const Text(
                    "CALCULATE FROM",
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: Colors.grey,
                      letterSpacing: 1.2,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      _buildToggleButton(
                        "Selling Price",
                        _selectedBase == DiscountBase.sellingPrice,
                        () => setState(
                          () => _selectedBase = DiscountBase.sellingPrice,
                        ),
                      ),
                      const SizedBox(width: 12),
                      _buildToggleButton(
                        "MRP",
                        _selectedBase == DiscountBase.mrp,
                        () => setState(() => _selectedBase = DiscountBase.mrp),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 30),

          // Action Buttons
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () {
                    if (widget.specificItem != null) {
                      provider.applyItemDiscount(
                        widget.specificItem!.product,
                        DiscountType.none,
                        0,
                        DiscountBase.sellingPrice,
                      );
                    } else {
                      provider.applyCartDiscount(
                        DiscountType.none,
                        0,
                        DiscountBase.sellingPrice,
                        isManual: true,
                      );
                    }
                    Navigator.pop(context);
                  },
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    side: const BorderSide(color: Colors.red),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  child: const Text(
                    'Remove',
                    style: TextStyle(
                      color: Colors.red,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green.shade700,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  onPressed: _applyDiscount,
                  child: const Text(
                    'Apply',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
