class DashboardSummary {
  final double todaySales;
  final double todayProfit;
  final int todayOrders;
  final int lowStockProducts;

  const DashboardSummary({
    required this.todaySales,
    required this.todayProfit,
    required this.todayOrders,
    required this.lowStockProducts,
  });

  const DashboardSummary.empty()
      : todaySales = 0,
        todayProfit = 0,
        todayOrders = 0,
        lowStockProducts = 0;
}
