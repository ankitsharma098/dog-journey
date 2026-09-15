import 'dart:async';

import 'package:flutter/foundation.dart';

/// Turns a Bloc's state stream into a [Listenable] go_router can use as
/// `refreshListenable`, so a redirect re-evaluates on every AuthBloc
/// emission without the router needing to know about Bloc at all.
class GoRouterRefreshStream extends ChangeNotifier {
  GoRouterRefreshStream(Stream<dynamic> stream) {
    notifyListeners();
    _subscription = stream.asBroadcastStream().listen(
      (_) => notifyListeners(),
    );
  }

  late final StreamSubscription<dynamic> _subscription;

  @override
  void dispose() {
    _subscription.cancel();
    super.dispose();
  }
}
