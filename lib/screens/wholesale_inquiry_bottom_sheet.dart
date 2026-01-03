import 'package:flutter/material.dart';
import '../models/order.dart';
import '../services/api_service.dart';

class WholesaleInquiryBottomSheet extends StatefulWidget {
  final BuildContext parentContext;

  const WholesaleInquiryBottomSheet({super.key, required this.parentContext});

  @override
  State<WholesaleInquiryBottomSheet> createState() =>
      _WholesaleInquiryBottomSheetState();
}

class _WholesaleInquiryBottomSheetState
    extends State<WholesaleInquiryBottomSheet> {
  final _formKey = GlobalKey<FormState>();

  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _mobileController = TextEditingController();
  final TextEditingController _addressController = TextEditingController();

  int _page = 1;
  final int _limit = 10;

  bool _isLoading = false;
  bool _hasMore = true;

  final List<Order> _orders = [];

  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _loadOrders();

    _scrollController.addListener(() {
      if (_scrollController.position.pixels >=
              _scrollController.position.maxScrollExtent - 100 &&
          !_isLoading &&
          _hasMore) {
        _loadOrders();
      }
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _nameController.dispose();
    _mobileController.dispose();
    _addressController.dispose();
    super.dispose();
  }

  Future<void> _loadOrders() async {
    setState(() => _isLoading = true);

    try {
      final api = ApiService(widget.parentContext);
      final res = await api.orderList(_page, _limit);

      if (res['flag'] == 1 && res['data'] != null) {
        final List list = res['data']['result'];

        if (list.isEmpty) {
          _hasMore = false;
        } else {
          _orders.addAll(list.map((e) => Order.fromJson(e)));
          _page++;
        }
      }
    } catch (e) {
      debugPrint("❌ Pagination error: $e");
    }

    setState(() => _isLoading = false);
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        top: 16,
        bottom: MediaQuery.of(context).viewInsets.bottom + 16,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _dragHandle(),
          const SizedBox(height: 8),

          const Text(
            "Wholesale Inquiry",
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.green,
            ),
          ),

          const SizedBox(height: 16),

          _buildForm(),

          const SizedBox(height: 16),

          _buildRecentCustomers(),

          const SizedBox(height: 12),

          _buildSubmitButton(),
        ],
      ),
    );
  }

  /// ---------------- FORM ----------------
  Widget _buildForm() {
    return Form(
      key: _formKey,
      child: Column(
        children: [
          _inputField(
            controller: _nameController,
            label: "Customer Name",
            icon: Icons.person,
            validator: (v) => v == null || v.isEmpty ? "Enter name" : null,
          ),
          const SizedBox(height: 10),

          _inputField(
            controller: _mobileController,
            label: "Mobile Number",
            icon: Icons.phone,
            keyboardType: TextInputType.phone,
            maxLength: 10,
            validator:
                (v) =>
                    v == null || v.length != 10 ? "Enter valid mobile" : null,
          ),
          const SizedBox(height: 10),

          _inputField(
            controller: _addressController,
            label: "Address",
            icon: Icons.location_on,
            maxLines: 2,
            validator:
                (v) => v == null || v.length < 5 ? "Enter full address" : null,
          ),
        ],
      ),
    );
  }

  /// ---------------- RECENT CUSTOMERS ----------------
  Widget _buildRecentCustomers() {
    return SizedBox(
      height: 220,
      child:
          _orders.isEmpty && _isLoading
              ? const Center(child: CircularProgressIndicator())
              : ListView.builder(
                controller: _scrollController,
                itemCount: _orders.length + (_hasMore ? 1 : 0),
                itemBuilder: (context, index) {
                  if (index == _orders.length) {
                    return const Padding(
                      padding: EdgeInsets.symmetric(vertical: 12),
                      child: Center(child: CircularProgressIndicator()),
                    );
                  }

                  final customer = _orders[index];
                  return ListTile(
                    leading: const Icon(Icons.history),
                    title: Text(customer.orderUsername),
                    subtitle: Text(customer.orderMobileNo),
                    trailing: Text(
                      "₹${customer.totalAmount}",
                      style: const TextStyle(
                        color: Colors.green,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    onTap: () {
                      _nameController.text = customer.orderUsername;
                      _mobileController.text = customer.orderMobileNo;
                      _addressController.text = customer.orderAddress;
                    },
                  );
                },
              ),
    );
  }

  /// ---------------- SUBMIT ----------------
  Widget _buildSubmitButton() {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.green,
          padding: const EdgeInsets.symmetric(vertical: 14),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
        onPressed: () {
          if (_formKey.currentState!.validate()) {
            Navigator.pop(context);
          }
        },
        child: const Text(
          "Continue",
          style: TextStyle(fontSize: 16, color: Colors.white),
        ),
      ),
    );
  }

  /// ---------------- COMMON WIDGETS ----------------
  Widget _inputField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    TextInputType keyboardType = TextInputType.text,
    int maxLines = 1,
    int? maxLength,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      maxLines: maxLines,
      maxLength: maxLength,
      validator: validator,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
        counterText: "",
      ),
    );
  }

  Widget _dragHandle() {
    return Container(
      width: 40,
      height: 4,
      decoration: BoxDecoration(
        color: Colors.grey[300],
        borderRadius: BorderRadius.circular(2),
      ),
    );
  }
}
