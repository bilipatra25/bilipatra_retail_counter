import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../services/api_service.dart';

class DashboardView extends StatefulWidget {
  const DashboardView({super.key});

  @override
  State<DashboardView> createState() => _DashboardViewState();
}

class _DashboardViewState extends State<DashboardView> {
  bool _isLoading = true;
  String _errorMessage = "";

  // Data State
  Map<String, dynamic> _reportData = {};

  // Filter State
  String _selectedFilter = "today"; // today, yesterday, this_month, custom
  late DateTime _startDate;
  late DateTime _endDate;

  @override
  void initState() {
    super.initState();
    _setFilter("today");
  }

  void _setFilter(String filter) {
    // 🟢 Intercept the custom filter to open the picker
    if (filter == "custom") {
      _pickCustomDateRange();
      return;
    }

    final now = DateTime.now();
    setState(() {
      _selectedFilter = filter;
      if (filter == "today") {
        _startDate = now;
        _endDate = now;
      } else if (filter == "yesterday") {
        _startDate = now.subtract(const Duration(days: 1));
        _endDate = now.subtract(const Duration(days: 1));
      } else if (filter == "this_month") {
        _startDate = DateTime(now.year, now.month, 1);
        _endDate = now;
      }
    });
    _fetchReport();
  }

  // 🟢 NEW: Custom Date Range Picker Logic
  Future<void> _pickCustomDateRange() async {
    final DateTimeRange? picked = await showDateRangePicker(
      context: context,
      initialDateRange: DateTimeRange(start: _startDate, end: _endDate),
      firstDate: DateTime(2020), // How far back they can search
      lastDate: DateTime.now(),  // Can't search the future
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.light(
              primary: Colors.blue.shade700,
              onPrimary: Colors.white,
              onSurface: Colors.black87,
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      setState(() {
        _selectedFilter = "custom";
        _startDate = picked.start;
        _endDate = picked.end;
      });
      _fetchReport();
    }
  }

  Future<void> _fetchReport() async {
    setState(() {
      _isLoading = true;
      _errorMessage = "";
    });

    final startStr = DateFormat('yyyy-MM-dd').format(_startDate);
    final endStr = DateFormat('yyyy-MM-dd').format(_endDate);

    try {
      final response = await ApiService(context).getDashboardReport(startStr, endStr);

      if (response['flag'] == 1 || response['code'] == 200) {
        setState(() {
          _reportData = response['data'] ?? {};
          _isLoading = false;
        });
      } else {
        throw Exception(response['message'] ?? "Failed to load report");
      }
    } catch (e) {
      setState(() {
        _errorMessage = e.toString();
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.grey.shade50,
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ==========================================
          // 1. HEADER & FILTERS
          // ==========================================
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    "Store Overview",
                    style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Colors.black87),
                  ),
                  Text(
                    "${DateFormat('MMM d, yyyy').format(_startDate)}  -  ${DateFormat('MMM d, yyyy').format(_endDate)}",
                    style: TextStyle(fontSize: 14, color: Colors.grey.shade600, fontWeight: FontWeight.w500),
                  ),
                ],
              ),

              // Filter Buttons
              Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.grey.shade300),
                ),
                child: Row(
                  children: [
                    _buildFilterBtn("Today", "today"),
                    Container(width: 1, height: 20, color: Colors.grey.shade300),
                    _buildFilterBtn("Yesterday", "yesterday"),
                    Container(width: 1, height: 20, color: Colors.grey.shade300),
                    _buildFilterBtn("This Month", "this_month"),
                    Container(width: 1, height: 20, color: Colors.grey.shade300),
                    // 🟢 NEW: Custom Button
                    _buildFilterBtn("Custom Range", "custom", icon: Icons.calendar_month),
                  ],
                ),
              )
            ],
          ),

          const SizedBox(height: 32),

          // ==========================================
          // 2. DATA GRID
          // ==========================================
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator(color: Colors.blue))
                : _errorMessage.isNotEmpty
                ? Center(child: Text(_errorMessage, style: const TextStyle(color: Colors.red)))
                : SingleChildScrollView(
              child: Column(
                children: [
                  // Top Row: Big Metrics
                  Row(
                    children: [
                      Expanded(
                        child: _buildMetricCard(
                          title: "Gross Revenue",
                          value: "₹${_reportData['total_amount'] ?? '0'}",
                          subtitle: "${_reportData['total_order'] ?? '0'} Total Orders",
                          icon: Icons.account_balance_wallet,
                          color: Colors.blue.shade600,
                          bgColor: Colors.blue.shade50,
                        ),
                      ),
                      const SizedBox(width: 24),
                      Expanded(
                        child: _buildMetricCard(
                          title: "Cash Collection",
                          value: "₹${_reportData['cash_order']?['cash_amount'] ?? '0'}",
                          subtitle: "${_reportData['cash_order']?['order'] ?? '0'} Cash Orders",
                          icon: Icons.payments,
                          color: Colors.green.shade600,
                          bgColor: Colors.green.shade50,
                        ),
                      ),
                      const SizedBox(width: 24),
                      Expanded(
                        child: _buildMetricCard(
                          title: "Online / UPI",
                          value: "₹${_reportData['online_order']?['online_amount'] ?? '0'}",
                          subtitle: "${_reportData['online_order']?['order'] ?? '0'} UPI Orders",
                          icon: Icons.qr_code_2,
                          color: Colors.purple.shade600,
                          bgColor: Colors.purple.shade50,
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 40),

                  // Bottom Section
                  Container(
                    padding: const EdgeInsets.all(32),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.grey.shade200),
                      boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 10, offset: const Offset(0, 5))],
                    ),
                    child: Center(
                      child: Column(
                        children: [
                          Icon(Icons.insights, size: 64, color: Colors.grey.shade300),
                          const SizedBox(height: 16),
                          Text(
                            "Great job! The store has processed ${_reportData['total_order'] ?? '0'} orders in this period.",
                            style: TextStyle(fontSize: 18, color: Colors.grey.shade600),
                          )
                        ],
                      ),
                    ),
                  )
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // 🟢 UPDATED: Helper Widget for Filter Buttons (Now supports optional icons)
  Widget _buildFilterBtn(String label, String value, {IconData? icon}) {
    final isActive = _selectedFilter == value;
    return InkWell(
      onTap: () => _setFilter(value),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        decoration: BoxDecoration(
          color: isActive ? Colors.blue.shade50 : Colors.transparent,
          borderRadius: BorderRadius.circular(isActive ? 8 : 0),
        ),
        child: Row(
          children: [
            if (icon != null) ...[
              Icon(
                  icon,
                  size: 16,
                  color: isActive ? Colors.blue.shade700 : Colors.grey.shade700
              ),
              const SizedBox(width: 6),
            ],
            Text(
              label,
              style: TextStyle(
                fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
                color: isActive ? Colors.blue.shade700 : Colors.grey.shade700,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Helper Widget for Metric Cards
  Widget _buildMetricCard({required String title, required String value, required String subtitle, required IconData icon, required Color color, required Color bgColor}) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 15, offset: const Offset(0, 8))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(title, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Colors.grey.shade600)),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(color: bgColor, borderRadius: BorderRadius.circular(12)),
                child: Icon(icon, color: color, size: 24),
              )
            ],
          ),
          const SizedBox(height: 16),
          Text(value, style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: Colors.black87)),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(color: Colors.grey.shade100, borderRadius: BorderRadius.circular(4)),
            child: Text(subtitle, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: Colors.grey.shade700)),
          )
        ],
      ),
    );
  }
}