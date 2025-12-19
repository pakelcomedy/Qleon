/// Connectivity Service
/// ------------------------------------------------------------
/// Monitors network connectivity state
/// Used to react to offline / online changes
/// ------------------------------------------------------------

import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';

class ConnectivityService {
  ConnectivityService(this._connectivity);

  final Connectivity _connectivity;

  /// -------------------------------
  /// STREAM
  /// -------------------------------

  Stream<ConnectivityResult> get onConnectivityChanged {
    return _connectivity.onConnectivityChanged;
  }

  /// -------------------------------
  /// CHECK CURRENT STATE
  /// -------------------------------

  Future<bool> get isConnected async {
    final result = await _connectivity.checkConnectivity();
    return _isConnectedResult(result);
  }

  /// -------------------------------
  /// UTIL
  /// -------------------------------

  bool _isConnectedResult(ConnectivityResult result) {
    return result == ConnectivityResult.mobile ||
        result == ConnectivityResult.wifi ||
        result == ConnectivityResult.ethernet;
  }
}