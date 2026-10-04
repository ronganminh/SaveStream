import '../models/app_status.dart';

abstract interface class AppStatusRepository {
  Future<AppStatus> getStatus();
}
