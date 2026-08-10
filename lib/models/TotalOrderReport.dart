class TotalOrderReport {
  final int totalOrder;
  final String totalAmount;
  final int cashOrderCount;
  final String cashAmount;
  final int onlineOrderCount;
  final String onlineAmount;

  TotalOrderReport({
    required this.totalOrder,
    required this.totalAmount,
    required this.cashOrderCount,
    required this.cashAmount,
    required this.onlineOrderCount,
    required this.onlineAmount,
  });

  factory TotalOrderReport.fromJson(Map<String, dynamic> json) {
    final data = json['data'];
    return TotalOrderReport(
      totalOrder: data['total_order'],
      totalAmount: data['total_amount'],
      cashOrderCount: data['cash_order']['order'],
      cashAmount: data['cash_order']['cash_amount'],
      onlineOrderCount: data['online_order']['order'],
      onlineAmount: data['online_order']['online_amount'],
    );
  }
}
