import 'package:connectivity_plus/connectivity_plus.dart';

import 'contracts/connectivity_service.dart';

typedef ConnectivityCheck = Future<List<ConnectivityResult>> Function();

final class ConnectivityPlusService implements ConnectivityService {
  ConnectivityPlusService({
    Connectivity? connectivity,
    ConnectivityCheck? checkConnectivity,
    Stream<List<ConnectivityResult>>? connectivityChanges,
  }) : _connectivity = connectivity ?? Connectivity(),
       _checkConnectivity = checkConnectivity,
       _connectivityChanges = connectivityChanges;

  final Connectivity _connectivity;
  final ConnectivityCheck? _checkConnectivity;
  final Stream<List<ConnectivityResult>>? _connectivityChanges;

  @override
  Stream<bool> get online async* {
    final List<ConnectivityResult> initial =
        await (_checkConnectivity?.call() ?? _connectivity.checkConnectivity());
    yield _hasConnection(initial);

    yield* (_connectivityChanges ?? _connectivity.onConnectivityChanged)
        .map(_hasConnection)
        .distinct();
  }

  static bool _hasConnection(List<ConnectivityResult> results) {
    return results.any((ConnectivityResult result) {
      return result != ConnectivityResult.none;
    });
  }
}
