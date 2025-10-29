import 'package:uuid/uuid.dart';
import 'database_service.dart';
import '../utils/constants.dart';

class ApiUsageService {
  // Pricing for claude-sonnet-4-5 (as of 2025)
  static const double INPUT_COST_PER_MILLION = 3.0;   // $3/MTok
  static const double OUTPUT_COST_PER_MILLION = 15.0;  // $15/MTok

  Future<void> logUsage({
    required String operationType,
    required int inputTokens,
    required int outputTokens,
    required String model,
  }) async {
    final cost = _calculateCost(inputTokens, outputTokens);

    await DatabaseService.instance.insertApiUsageLog({
      'id': const Uuid().v4(),
      'timestamp': DateTime.now().millisecondsSinceEpoch,
      'operation_type': operationType,
      'input_tokens': inputTokens,
      'output_tokens': outputTokens,
      'estimated_cost_usd': cost,
      'model': model,
      'created_at': DateTime.now().millisecondsSinceEpoch,
    });
  }

  double _calculateCost(int inputTokens, int outputTokens) {
    final inputCost = (inputTokens / 1000000) * INPUT_COST_PER_MILLION;
    final outputCost = (outputTokens / 1000000) * OUTPUT_COST_PER_MILLION;
    return inputCost + outputCost;
  }

  Future<UsageStats> getStats() async {
    final db = await DatabaseService.instance.database;

    // Total stats
    final total = await db.rawQuery('''
      SELECT
        COUNT(*) as call_count,
        SUM(estimated_cost_usd) as total_cost,
        SUM(input_tokens) as total_input_tokens,
        SUM(output_tokens) as total_output_tokens
      FROM ${AppConstants.apiUsageLogTable}
    ''');

    // This month
    final monthStart = DateTime(DateTime.now().year, DateTime.now().month, 1);
    final thisMonth = await db.rawQuery('''
      SELECT
        COUNT(*) as call_count,
        SUM(estimated_cost_usd) as total_cost
      FROM ${AppConstants.apiUsageLogTable}
      WHERE timestamp >= ?
    ''', [monthStart.millisecondsSinceEpoch]);

    return UsageStats(
      totalCalls: total[0]['call_count'] as int,
      totalCost: total[0]['total_cost'] as double? ?? 0.0,
      monthCalls: thisMonth[0]['call_count'] as int,
      monthCost: thisMonth[0]['total_cost'] as double? ?? 0.0,
    );
  }
}

class UsageStats {
  final int totalCalls;
  final double totalCost;
  final int monthCalls;
  final double monthCost;

  UsageStats({
    required this.totalCalls,
    required this.totalCost,
    required this.monthCalls,
    required this.monthCost,
  });

  double get averageCostPerCall =>
    totalCalls > 0 ? totalCost / totalCalls : 0.0;
}
