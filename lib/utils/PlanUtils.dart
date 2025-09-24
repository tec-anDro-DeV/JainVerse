import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:jainverse/Presenter/PlanPresenter.dart';

class PlanUtils {
  // Cached lists after fetching from backend
  static List<Map<String, dynamic>> _monthlyPlans = [];
  static List<Map<String, dynamic>> _yearlyPlans = [];

  /// Fetch plans from backend and cache them. Returns true on success.
  static Future<bool> fetchPlans(String token, [BuildContext? context]) async {
    try {
      final presenter = PlanPresenter();
      final String res;
      if (context != null) {
        res = await presenter.getAllPlans(token, context);
      } else {
        res = await presenter.getAllPlansLegacy(token);
      }
      // The presenter may return either a JSON string or a decoded Map depending
      // on how Dio / BasePresenter is implemented. Handle both cases.
      dynamic parsed;
      try {
        parsed = json.decode(res);
      } catch (e) {
        // If res is not a JSON string, it might already be a Map
        if (res is Map<String, dynamic>) {
          parsed = res;
        } else {
          // As a last resort, attempt to cast
          parsed = res;
        }
      }

      // If response is already a Map (not a String), use it directly
      if (parsed is! Map<String, dynamic>) {
        // Try one more defensive parse when presenter returned non-string
        try {
          parsed = (parsed as dynamic) ?? {};
        } catch (_) {
          parsed = {};
        }
      }

      // Debug logging to help diagnose runtime issues where response might be
      // a Map or a JSON string. These prints are safe during development.
      // Remove or guard them in production if necessary.
      try {
        // ignore: avoid_print
        print('[PlanUtils] fetchPlans response runtimeType=${res.runtimeType}');
        // ignore: avoid_print
        print('[PlanUtils] parsed is ${parsed.runtimeType}');
      } catch (_) {}

      if (parsed != null &&
          parsed is Map<String, dynamic> &&
          parsed['status'] == true &&
          parsed['data'] != null &&
          parsed['data'] is List &&
          parsed['data'].isNotEmpty) {
        final data = parsed['data'][0];

        _monthlyPlans = [];
        _yearlyPlans = [];

        if (data['monthly_plans'] != null && data['monthly_plans'] is List) {
          for (var p in data['monthly_plans']) {
            _monthlyPlans.add(_normalizePlan(p, period: 'Monthly'));
          }
        }

        if (data['yearly_plans'] != null && data['yearly_plans'] is List) {
          for (var p in data['yearly_plans']) {
            _yearlyPlans.add(_normalizePlan(p, period: 'Yearly'));
          }
        }

        return true;
      }

      return false;
    } catch (e) {
      // On failure, leave caches untouched
      return false;
    }
  }

  static Map<String, dynamic> _normalizePlan(
    dynamic p, {
    required String period,
  }) {
    // Backend plan can have numeric id and plan_amount without $ sign.
    return {
      'id': p['id']?.toString() ?? p['product_id']?.toString() ?? '',
      'numeric_id': p['id'] ?? 0,
      'name': p['plan_name'] ?? p['name'] ?? '',
      'price':
          p['plan_amount'] != null
              ? '\$${p['plan_amount']}'
              : (p['price'] ?? '\$0.00'),
      'isFeatured': p['status'] == 1 || p['isFeatured'] == true,
      'features':
          p['description'] != null ? [p['description']] : (p['features'] ?? []),
      'product_id': p['product_id'], // iOS/Store product id if available
      'raw': p,
      'period': period,
    };
  }

  static List<Map<String, dynamic>> getMonthlyPlans() => _monthlyPlans;
  static List<Map<String, dynamic>> getYearlyPlans() => _yearlyPlans;

  /// Get plan details by id. Handles numeric/string ids and product_id lookups.
  static Map<String, dynamic>? getPlanDetailsById(
    String planId,
    String period,
  ) {
    final plans = period == 'Monthly' ? _monthlyPlans : _yearlyPlans;
    try {
      return plans.firstWhere((plan) {
        if (plan['id'] != null && plan['id'].toString() == planId) return true;
        if (plan['numeric_id'] != null &&
            plan['numeric_id'].toString() == planId)
          return true;
        if (plan['product_id'] != null && plan['product_id'] == planId)
          return true;
        return false;
      });
    } catch (e) {
      return null;
    }
  }
}
