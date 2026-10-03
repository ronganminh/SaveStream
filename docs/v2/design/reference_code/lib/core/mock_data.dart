// Dữ liệu mẫu — thay bằng repository thật (Backend / Local DB). Copy khớp màn H01, W01, L01.
import 'enums.dart';
import 'models.dart';

const lina = Creator(id: 'c1', name: 'Lina Studio', handle: '@linastudio', liveStatus: LiveStatus.live);
const mike = Creator(
    id: 'c2', name: 'Mike Fitness', handle: '@mikefit', liveStatus: LiveStatus.offline, lastLiveLabel: 'hôm qua 20:15');
const ha = Creator(id: 'c3', name: 'Hà Beauty', handle: '@habeauty', liveStatus: LiveStatus.offline, lastLiveLabel: '24/9');

const mockCreators = [lina, mike];

final mockUsageFree = UsageSnapshot(
  plan: Plan.free,
  freeMinutesLeft: 7,
  resetAt: DateTime.now().add(const Duration(hours: 6)),
  adsUsed: 2,
  watchCount: 2,
  cloudPackHours: 5,
  updatedAt: DateTime.now(),
);

final mockRecordings = <Recording>[
  Recording(
      id: 'r1',
      creator: lina,
      title: 'Livestream tối thứ Hai',
      startedAt: DateTime.now().subtract(const Duration(hours: 3)),
      duration: const Duration(minutes: 9, seconds: 42),
      engine: Engine.local,
      status: RecordingStatus.completed,
      copies: CopyLocation.localOnly,
      sizeBytes: 182 << 20),
  Recording(
      id: 'r2',
      creator: ha,
      title: 'Review son mới',
      startedAt: DateTime.now().subtract(const Duration(hours: 5)),
      duration: const Duration(hours: 1, minutes: 2),
      engine: Engine.cloud,
      status: RecordingStatus.processing,
      copies: CopyLocation.cloudOnly),
  Recording(
      id: 'r3',
      creator: mike,
      title: 'Full body 45 phút',
      startedAt: DateTime.now().subtract(const Duration(days: 1, hours: 2)),
      duration: const Duration(minutes: 44, seconds: 10),
      engine: Engine.cloud,
      status: RecordingStatus.completed,
      copies: CopyLocation.both,
      sizeBytes: 640 << 20),
  Recording(
      id: 'r4',
      creator: lina,
      title: 'Q&A cuối tuần',
      startedAt: DateTime.now().subtract(const Duration(days: 1, hours: 6)),
      duration: const Duration(minutes: 3, seconds: 5),
      engine: Engine.local,
      status: RecordingStatus.partial,
      copies: CopyLocation.localOnly,
      sizeBytes: 54 << 20),
];
