import 'package:bilipatra_retail_counter/screens/pos/admin_dashboard_modal.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../models/product.dart';
import '../../providers/app_provider.dart';
import '../../services/api_service.dart';

class LeftPaneWidget extends StatefulWidget {
  const LeftPaneWidget({super.key});

  @override
  State<LeftPaneWidget> createState() => _LeftPaneWidgetState();
}

class _LeftPaneWidgetState extends State<LeftPaneWidget> {
  final FocusNode _keyboardFocusNode = FocusNode();
  String _barcodeBuffer = "";
  DateTime _lastKeyPress = DateTime.now();

  final TextEditingController _searchController = TextEditingController();

  // API & Pagination States
  late ApiService _apiService;
  final ScrollController _scrollController = ScrollController();
  final List<ProductModel> _products = [];
  bool _isLoading = false;
  bool _hasMore = true;
  int _currentPage = 1;
  final int _pageSize = 20;

  // Category State
  final List<String> _categories = [
    "All",
    "Nirant",
    "B12",
    "100",
    "200",
    "400",
  ];
  String _selectedCategory = "All";

  @override
  void initState() {
    super.initState();
    _apiService = ApiService(context);

    // Fetch initial products
    _fetchProducts();

    // Setup pagination listener
    _scrollController.addListener(() {
      if (_scrollController.position.pixels >=
          _scrollController.position.maxScrollExtent - 200) {
        _fetchProducts();
      }
    });

    // Request scanner focus
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _keyboardFocusNode.requestFocus();
    });
  }

  @override
  void dispose() {
    _keyboardFocusNode.dispose();
    _scrollController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  // ==========================================
  // API FETCH LOGIC
  // ==========================================
  Future<void> _fetchProducts() async {
    if (_isLoading || !_hasMore) return;

    setState(() => _isLoading = true);

    try {
      final results = await _apiService.productList(_currentPage, _pageSize);
      setState(() {
        _products.addAll(results);
        _hasMore = results.length == _pageSize;
        _currentPage++;
      });
    } catch (e) {
      debugPrint("Error fetching products: $e");
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("Failed to load products")));
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void refreshProducts() {
    setState(() {
      _products.clear();
      _currentPage = 1;
      _hasMore = true;
      _searchController.clear();
    });
    _fetchProducts();
  }

  List<ProductModel> get _filteredProducts {
    String query = _searchController.text.toLowerCase();

    return _products.where((p) {
      // 1. Check Search Query (Matches Name or ID)
      bool matchesSearch =
          query.isEmpty ||
          p.name.toLowerCase().contains(query) ||
          p.id.toString().contains(query);

      // 2. Check Custom Category Logic (Name vs Weight)
      bool matchesCategory = true;
      if (_selectedCategory != "All") {
        String catLower = _selectedCategory.toLowerCase();

        // If the category is a weight, check the product's weight field
        if (catLower == "100" || catLower == "200" || catLower == "400") {
          matchesCategory = p.weight.toLowerCase().contains(catLower);
        } else {
          // Otherwise, check the product's name
          matchesCategory = p.name.toLowerCase().contains(catLower);
        }
      }

      return matchesSearch && matchesCategory;
    }).toList();
  }

  // ==========================================
  // BARCODE SCANNER LOGIC
  // ==========================================
  void _handleHardwareScan(KeyEvent event) {
    if (event is KeyDownEvent) {
      final duration = DateTime.now().difference(_lastKeyPress);

      if (duration.inMilliseconds > 100) {
        _barcodeBuffer = "";
      }
      _lastKeyPress = DateTime.now();

      if (event.logicalKey == LogicalKeyboardKey.enter) {
        if (_barcodeBuffer.isNotEmpty) {
          _processBarcodeScanned(_barcodeBuffer);
          _barcodeBuffer = "";
        }
      } else if (event.character != null) {
        _barcodeBuffer += event.character!;
      }
    }
  }

  void _processBarcodeScanned(String barcode) {
    try {
      // Find product by ID (Update this logic if you add actual barcodes to your DB later)
      final product = _products.firstWhere((p) => p.id.toString() == barcode);
      Provider.of<AppProvider>(context, listen: false).addProduct(product);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("✅ Added ${product.name} to cart"),
          duration: const Duration(milliseconds: 500),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("❌ Product not found"),
          duration: Duration(milliseconds: 800),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  // ==========================================
  // MANUAL QUANTITY DIALOG
  // ==========================================
  void _showQuantityEditDialog(
    ProductModel product,
    int currentQty,
    AppProvider provider,
  ) {
    final TextEditingController qtyController = TextEditingController(
      text: currentQty.toString(),
    );

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text('Set Quantity for ${product.name}'),
          content: TextField(
            controller: qtyController,
            keyboardType: TextInputType.number,
            autofocus: true,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            decoration: const InputDecoration(
              border: OutlineInputBorder(),
              labelText: 'Quantity',
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
                foregroundColor: Colors.white,
              ),
              onPressed: () {
                final newQty = int.tryParse(qtyController.text) ?? 0;
                provider.setItemQuantity(product, newQty);
                Navigator.pop(context);
              },
              child: const Text('Update'),
            ),
          ],
        );
      },
    );
  }

  void _openManageProducts(BuildContext context) {
    final String targetUrl =
        'https://retail-counter.bilipatra.com/admin/products';

    showDialog(
      context: context,
      barrierDismissible: false,
      builder:
          (context) => AdminDashboardModal(
            url: targetUrl,
            title: "Product Management", // Custom title
          ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final appProvider = Provider.of<AppProvider>(context);

    return Focus(
      focusNode: _keyboardFocusNode,
      onKeyEvent: (node, event) {
        _handleHardwareScan(event);
        return KeyEventResult.ignored;
      },
      child: Column(
        children: [
          // 1. Top Bar
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _searchController,
                    onChanged: (value) {
                      setState(() {});
                    },
                    decoration: InputDecoration(
                      hintText: "Search products by name or barcode...",
                      prefixIcon: const Icon(Icons.search),
                      filled: true,
                      fillColor: Colors.white,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                      contentPadding: const EdgeInsets.symmetric(vertical: 0),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                IconButton(
                  tooltip: "Refresh Products",
                  icon: const Icon(Icons.refresh, color: Colors.green),
                  onPressed: refreshProducts,
                ),
                const SizedBox(width: 8),
                ElevatedButton.icon(
                  onPressed: () => _openManageProducts(context),
                  icon: const Icon(Icons.edit_note),
                  label: const Text("Manage Products"),
                ),
              ],
            ),
          ),

          // 2. Categories
          SizedBox(
            height: 40,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: _categories.length,
              itemBuilder: (context, index) {
                final category = _categories[index];
                final isSelected = category == _selectedCategory;
                return Padding(
                  padding: const EdgeInsets.only(right: 8.0),
                  child: ChoiceChip(
                    label: Text(category),
                    selected: isSelected,
                    selectedColor: Colors.green.shade100,
                    onSelected: (selected) {
                      setState(() => _selectedCategory = category);
                    },
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 12),

          // 3. Product Grid
          // 3. Product Grid
          // 3. Product Grid
          Expanded(
            child:
                _isLoading && _products.isEmpty
                    // State 1: Initial Loading
                    ? const Center(
                      child: CircularProgressIndicator(color: Colors.green),
                    )
                    // State 2: API Failed / No Products Loaded (The Network Drop Fix)
                    : _products.isEmpty
                    ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.wifi_off_rounded,
                            size: 64,
                            color: Colors.grey.shade400,
                          ),
                          const SizedBox(height: 16),
                          const Text(
                            "Couldn't load products from server.",
                            style: TextStyle(fontSize: 18, color: Colors.grey),
                          ),
                          const SizedBox(height: 16),
                          ElevatedButton.icon(
                            onPressed:
                                _fetchProducts, // 🟢 Tap to retry API call
                            icon: const Icon(Icons.refresh),
                            label: const Text("Retry Connection"),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.green.shade600,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 24,
                                vertical: 12,
                              ),
                            ),
                          ),
                        ],
                      ),
                    )
                    // State 3: User searched for something that doesn't exist
                    : _filteredProducts.isEmpty
                    ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.search_off,
                            size: 64,
                            color: Colors.grey.shade400,
                          ),
                          const SizedBox(height: 16),
                          Text(
                            "No products found for '${_searchController.text}'",
                            style: const TextStyle(
                              fontSize: 18,
                              color: Colors.grey,
                            ),
                          ),
                        ],
                      ),
                    )
                    // State 4: Normal Grid View
                    : GridView.builder(
                      controller: _scrollController,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                      gridDelegate:
                          const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 3,
                            mainAxisExtent: 260,
                            crossAxisSpacing: 12,
                            mainAxisSpacing: 12,
                          ),
                      itemCount:
                          _filteredProducts.length +
                          (_hasMore && _searchController.text.isEmpty ? 1 : 0),
                      itemBuilder: (context, index) {
                        if (index == _filteredProducts.length) {
                          return const Center(
                            child: CircularProgressIndicator(),
                          );
                        }

                        final product = _filteredProducts[index];
                        final cartItemIndex = appProvider.cart.indexWhere(
                          (c) => c.product.id == product.id,
                        );
                        final inCart = cartItemIndex >= 0;
                        final qtyInCart =
                            inCart
                                ? appProvider.cart[cartItemIndex].quantity
                                : 0;

                        return _buildProductCard(
                          product,
                          inCart,
                          qtyInCart,
                          appProvider,
                        );
                      },
                    ),
          ),
        ],
      ),
    );
  }

  Widget _buildProductCard(
    ProductModel product,
    bool inCart,
    int qty,
    AppProvider provider,
  ) {
    return Card(
      elevation: 2,
      color: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // Image Placeholder (Use CachedNetworkImage in production)
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child:
                  product.image.isNotEmpty
                      ? Image.network(
                        product.image,
                        height: 80,
                        width: 80,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => _buildPlaceholder(),
                      )
                      : _buildPlaceholder(),
            ),
            const SizedBox(height: 8),

            Text(
              product.name,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            Text(
              product.weight,
              style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
            ),
            const SizedBox(height: 4),
            Text(
              '₹ ${product.price.toStringAsFixed(0)}',
              style: const TextStyle(
                color: Colors.green,
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
            const Spacer(),

            inCart
                ? Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(8),
                    color: Colors.green.shade50,
                    border: Border.all(color: Colors.green.shade200),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      IconButton(
                        icon: const Icon(
                          Icons.remove,
                          color: Colors.green,
                          size: 20,
                        ),
                        onPressed: () => provider.decrementQuantity(product),
                      ),

                      // 🟢 TAP TO EDIT QUANTITY 🟢
                      InkWell(
                        onTap:
                            () =>
                                _showQuantityEditDialog(product, qty, provider),
                        borderRadius: BorderRadius.circular(4),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: Colors.green.shade300),
                          ),
                          child: Text(
                            '$qty',
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                        ),
                      ),

                      IconButton(
                        icon: const Icon(
                          Icons.add,
                          color: Colors.green,
                          size: 20,
                        ),
                        onPressed: () => provider.addProduct(product),
                      ),
                    ],
                  ),
                )
                : SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () => provider.addProduct(product),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green.shade600,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: const Text('Add to Cart'),
                  ),
                ),
          ],
        ),
      ),
    );
  }

  Widget _buildPlaceholder() {
    return Container(
      height: 80,
      width: 80,
      decoration: BoxDecoration(
        color: Colors.grey.shade200,
        borderRadius: BorderRadius.circular(8),
      ),
      child: const Icon(Icons.image, color: Colors.grey, size: 40),
    );
  }
}
