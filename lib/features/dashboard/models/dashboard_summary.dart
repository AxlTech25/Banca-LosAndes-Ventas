class DashboardSummary {
  const DashboardSummary({
    required this.pendingVisits,
    required this.totalInPortfolio,
    required this.managedToday,
    required this.portfolioAmount,
    required this.approvedThisMonth,
    this.readyForApproval = 0,
  });

  final int pendingVisits;
  final int totalInPortfolio;
  final int managedToday;
  final double portfolioAmount;
  final int approvedThisMonth;
  final int readyForApproval;
}
