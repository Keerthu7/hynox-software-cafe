import 'package:flutter/foundation.dart';
import 'domain.dart';

typedef Persist = Future<void> Function(String value);

/// Persist a candidate before publishing it, so a write failure never looks saved.
class CafeStore extends ChangeNotifier {
  CafeData _data;
  final Persist persist;
  final bool connected;
  final Future<Map<String, String>> Function()? receiptStatuses;
  final Future<void> Function(String orderId)? retryReceipt;
  final Future<void> Function(String current, String password)? changePassword;
  final Future<bool> Function(CafeOrder order)? openWhatsApp;
  final Future<Map<String, dynamic>> Function()? loadSubscription;
  final Future<Map<String, dynamic>> Function(String planId)? requestPlan;
  final Future<Map<String, dynamic>> Function(String planId, String method)? paySubscription;
  Map<String, dynamic>? activeSubscription;
  bool busy = false;
  CafeData get data => _data;
  CafeStore(
    this._data,
    this.persist, {
    this.connected = false,
    this.activeSubscription,
    this.receiptStatuses,
    this.retryReceipt,
    this.changePassword,
    this.openWhatsApp,
    this.loadSubscription,
    this.requestPlan,
    this.paySubscription,
  });

  void updateSubscription(Map<String, dynamic>? sub) {
    activeSubscription = sub;
    notifyListeners();
  }

  Future<void> change(void Function(CafeData candidate) operation) async {
    if (busy) {
      throw StateError('A save is already in progress. Please try again.');
    }
    busy = true;
    notifyListeners();
    try {
      final candidate = CafeData.decode(_data.encode());
      operation(candidate);
      await persist(candidate.encode());
      _data = candidate;
    } finally {
      busy = false;
      notifyListeners();
    }
  }
}
