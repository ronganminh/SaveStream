import '../contracts/connectivity_service.dart';

final class FakeConnectivityService implements ConnectivityService {
  const FakeConnectivityService({this.isOnline = true});

  final bool isOnline;

  @override
  Stream<bool> get online => Stream<bool>.value(isOnline);
}
