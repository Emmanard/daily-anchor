import '../../core/events/app_event.dart';

class DayProgress {
  const DayProgress({
    required this.date,
    required this.routinesCompleted,
    required this.recallAttempts,
  });

  /// A calendar day with no time of day.
  final DateTime date;
  final int routinesCompleted;
  final int recallAttempts;

  /// A day counts when at least one routine was finished.
  bool get active => routinesCompleted > 0;
}

/// The last [days] days from the events saved on this phone, oldest first. A
/// routine counts as done on a day when its latest event that day is a
/// completion, so completing and then undoing leaves it not done.
List<DayProgress> buildLocalProgress(
  Iterable<AppEvent> events,
  DateTime now,
  int days,
) {
  final dayList = [
    for (var i = days - 1; i >= 0; i--)
      DateTime(now.year, now.month, now.day - i),
  ];
  final done = {for (final day in dayList) day: <String>{}};
  final recall = {for (final day in dayList) day: 0};

  final ordered = events.toList()
    ..sort((a, b) => a.occurredAt.compareTo(b.occurredAt));
  for (final event in ordered) {
    final local = event.occurredAt.toLocal();
    final day = DateTime(local.year, local.month, local.day);
    final routines = done[day];
    if (routines == null) continue;

    final routineId = event.payload['routineId'];
    switch (event.type) {
      case EventType.routineCompleted:
        if (routineId is String) routines.add(routineId);
      case EventType.routineUndone:
        if (routineId is String) routines.remove(routineId);
      case EventType.recallCompleted:
        recall[day] = recall[day]! + 1;
      case EventType.feedbackSubmitted:
        break;
    }
  }

  return [
    for (final day in dayList)
      DayProgress(
        date: day,
        routinesCompleted: done[day]!.length,
        recallAttempts: recall[day]!,
      ),
  ];
}

const _weekdays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
const _months = [
  'Jan',
  'Feb',
  'Mar',
  'Apr',
  'May',
  'Jun',
  'Jul',
  'Aug',
  'Sep',
  'Oct',
  'Nov',
  'Dec',
];

/// "Today", "Yesterday", or a short date such as "Mon 27 Oct".
String dayLabel(DateTime date, DateTime now) {
  final today = DateTime(now.year, now.month, now.day);
  final daysAgo = today
      .difference(DateTime(date.year, date.month, date.day))
      .inDays;
  if (daysAgo == 0) return 'Today';
  if (daysAgo == 1) return 'Yesterday';
  return '${_weekdays[date.weekday - 1]} ${date.day} ${_months[date.month - 1]}';
}
