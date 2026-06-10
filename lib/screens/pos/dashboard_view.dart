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

  Future<void> _pickCustomDateRange() async {
    final DateTimeRange? picked = await showDateRangePicker(
      context: context,
      initialDateRange: DateTimeRange(start: _startDate, end: _endDate),
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
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
      final response = await ApiService(
        context,
      ).getDashboardReport(startStr, endStr);

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
    // Helper formats to parse safely
    final creditOrder = _reportData['credit_order'] ?? {};

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
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                  ),
                  Text(
                    "${DateFormat('MMM d, yyyy').format(_startDate)}  -  ${DateFormat('MMM d, yyyy').format(_endDate)}",
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey.shade600,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),

              Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.grey.shade300),
                ),
                child: Row(
                  children: [
                    _buildFilterBtn("Today", "today"),
                    Container(
                      width: 1,
                      height: 20,
                      color: Colors.grey.shade300,
                    ),
                    _buildFilterBtn("Yesterday", "yesterday"),
                    Container(
                      width: 1,
                      height: 20,
                      color: Colors.grey.shade300,
                    ),
                    _buildFilterBtn("This Month", "this_month"),
                    Container(
                      width: 1,
                      height: 20,
                      color: Colors.grey.shade300,
                    ),
                    _buildFilterBtn(
                      "Custom Range",
                      "custom",
                      icon: Icons.calendar_month,
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 24),

          // ==========================================
          // 2. DATA GRID SECTION
          // ==========================================
          Expanded(
            child:
                _isLoading
                    ? const Center(
                      child: CircularProgressIndicator(color: Colors.blue),
                    )
                    : _errorMessage.isNotEmpty
                    ? Center(
                      child: Text(
                        _errorMessage,
                        style: const TextStyle(color: Colors.red),
                      ),
                    )
                    : SingleChildScrollView(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // 🟢 TOP ROW: 4 ENTERPRISE METRICS CARDS
                          Row(
                            children: [
                              Expanded(
                                child: _buildMetricCard(
                                  title: "Gross Sale Value",
                                  value:
                                      "₹${_reportData['total_amount'] ?? '0'}",
                                  subtitle:
                                      "${_reportData['total_order'] ?? '0'} Total Orders",
                                  icon: Icons.receipt,
                                  color: Colors.blue.shade600,
                                  bgColor: Colors.blue.shade50,
                                ),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: _buildMetricCard(
                                  title: "Total Collected",
                                  value:
                                      "₹${_reportData['total_collected'] ?? '0'}",
                                  subtitle: "Cash + UPI Received",
                                  icon: Icons.account_balance_wallet,
                                  color: Colors.green.shade600,
                                  bgColor: Colors.green.shade50,
                                ),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: _buildMetricCard(
                                  title: "Total Pending Dues",
                                  value: "₹${_reportData['total_due'] ?? '0'}",
                                  subtitle: "To Be Collected",
                                  icon: Icons.warning,
                                  color: Colors.red.shade600,
                                  bgColor: Colors.red.shade50,
                                ),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: _buildMetricCard(
                                  title: "Credit (Khata) Bills",
                                  value: "${creditOrder['order'] ?? '0'}",
                                  subtitle: "Booked On Account",
                                  icon: Icons.menu_book,
                                  color: Colors.orange.shade700,
                                  bgColor: Colors.orange.shade50,
                                ),
                              ),
                            ],
                          ),

                          const SizedBox(height: 24),

                          // 🟢 BOTTOM ROW: METHOD BREAKDOWNS
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Direct Safe Channels (Cash & UPI)
                              Expanded(
                                flex: 4,
                                child: Column(
                                  children: [
                                    _buildBreakdownRow(
                                      title: "Direct Cash Volume",
                                      amount:
                                          "₹${_reportData['cash_order']?['cash_amount'] ?? '0'}",
                                      count:
                                          "${_reportData['cash_order']?['order'] ?? '0'} Orders",
                                      icon: Icons.payments,
                                      iconColor: Colors.green,
                                    ),
                                    const SizedBox(height: 12),
                                    _buildBreakdownRow(
                                      title: "Direct UPI/Online Volume",
                                      amount:
                                          "₹${_reportData['online_order']?['online_amount'] ?? '0'}",
                                      count:
                                          "${_reportData['online_order']?['order'] ?? '0'} Orders",
                                      icon: Icons.qr_code_2,
                                      iconColor: Colors.purple,
                                    ),
                                  ],
                                ),
                              ),

                              const SizedBox(width: 24),

                              // Credit Khata Breakdown Box
                              Expanded(
                                flex: 5,
                                child: Container(
                                  padding: const EdgeInsets.all(20),
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                      color: Colors.orange.shade100,
                                    ),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.orange.withOpacity(0.02),
                                        blurRadius: 10,
                                      ),
                                    ],
                                  ),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          Icon(
                                            Icons.folder_shared,
                                            color: Colors.orange.shade800,
                                            size: 20,
                                          ),
                                          const SizedBox(width: 8),
                                          Text(
                                            "Credit (Khata) Internal Ledger Summary",
                                            style: TextStyle(
                                              fontWeight: FontWeight.bold,
                                              fontSize: 15,
                                              color: Colors.orange.shade900,
                                            ),
                                          ),
                                        ],
                                      ),
                                      const Divider(height: 24),
                                      Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.spaceAround,
                                        children: [
                                          _buildSubAnalyticsItem(
                                            "Gross Booked",
                                            "₹${creditOrder['total_amount'] ?? '0'}",
                                            Colors.black87,
                                          ),
                                          _buildSubAnalyticsItem(
                                            "Advance Recv.",
                                            "₹${creditOrder['collected_amount'] ?? '0'}",
                                            Colors.green.shade700,
                                          ),
                                          _buildSubAnalyticsItem(
                                            "Net Dues Left",
                                            "₹${creditOrder['due_amount'] ?? '0'}",
                                            Colors.red.shade700,
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
          ),
        ],
      ),
    );
  }

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
                color: isActive ? Colors.blue.shade700 : Colors.grey.shade700,
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

  Widget _buildMetricCard({
    required String title,
    required String value,
    required String subtitle,
    required IconData icon,
    required Color color,
    required Color bgColor,
  }) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.02),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                title,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey.shade500,
                ),
              ),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: bgColor,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: color, size: 20),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            value,
            style: const TextStyle(
              fontSize: 26,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            subtitle,
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey.shade600,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBreakdownRow({
    required String title,
    required String amount,
    required String count,
    required IconData icon,
    required Color iconColor,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Row(
        children: [
          Icon(icon, color: iconColor, size: 28),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                    color: Colors.black87,
                  ),
                ),
                Text(
                  count,
                  style: const TextStyle(color: Colors.grey, fontSize: 12),
                ),
              ],
            ),
          ),
          Text(
            amount,
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 18,
              color: Colors.black87,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSubAnalyticsItem(String title, String value, Color valueColor) {
    return Column(
      children: [
        Text(
          title,
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey.shade500,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: valueColor,
          ),
        ),
      ],
    );
  }
}
