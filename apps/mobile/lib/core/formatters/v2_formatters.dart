String formatMinutesAsHoursMinutes(
  int minutes, {
  required String hoursLabel,
  required String minutesLabel,
}) {
  final int safeMinutes = minutes < 0 ? 0 : minutes;
  final int hours = safeMinutes ~/ 60;
  final int remaining = safeMinutes % 60;
  if (hours == 0) return '$remaining $minutesLabel';
  if (remaining == 0) return '$hours $hoursLabel';
  return '$hours $hoursLabel $remaining $minutesLabel';
}

String formatResetCountdown(
  Duration duration, {
  required String hoursLabel,
  required String minutesLabel,
}) {
  final int totalMinutes = duration.isNegative ? 0 : duration.inMinutes;
  return formatMinutesAsHoursMinutes(
    totalMinutes,
    hoursLabel: hoursLabel,
    minutesLabel: minutesLabel,
  );
}

String formatFileSize(int bytes) {
  final int safeBytes = bytes < 0 ? 0 : bytes;
  const int kb = 1024;
  const int mb = kb * 1024;
  const int gb = mb * 1024;
  if (safeBytes >= gb) {
    return '${(safeBytes / gb).toStringAsFixed(1)} GB';
  }
  if (safeBytes >= mb) {
    return '${(safeBytes / mb).toStringAsFixed(1)} MB';
  }
  if (safeBytes >= kb) {
    return '${(safeBytes / kb).toStringAsFixed(1)} KB';
  }
  return '$safeBytes B';
}

String formatDurationHms(Duration duration) {
  final int seconds = duration.isNegative ? 0 : duration.inSeconds;
  final int hours = seconds ~/ 3600;
  final int minutes = (seconds % 3600) ~/ 60;
  final int remaining = seconds % 60;
  return '${hours.toString().padLeft(2, '0')}'
      ':${minutes.toString().padLeft(2, '0')}'
      ':${remaining.toString().padLeft(2, '0')}';
}
