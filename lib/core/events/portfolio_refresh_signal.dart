import 'package:flutter/foundation.dart';

/// Notifica a cartera (movil/web) que debe recargarse tras tomar un caso.
class PortfolioRefreshSignal {
  PortfolioRefreshSignal._();

  static final PortfolioRefreshSignal instance = PortfolioRefreshSignal._();

  final ValueNotifier<int> version = ValueNotifier(0);

  void notifyChanged() {
    version.value++;
  }
}
