enum EventType {
  routineCompleted('routine_completed'),
  routineUndone('routine_undone'),
  recallCompleted('recall_completed');

  const EventType(this.wireName);

  final String wireName;

  static EventType fromWireName(String name) =>
      values.firstWhere((type) => type.wireName == name);
}

class AppEvent {
  const AppEvent({
    required this.id,
    required this.type,
    required this.payload,
    required this.occurredAt,
    this.synced = false,
  });

  final String id;
  final EventType type;
  final Map<String, Object?> payload;
  final DateTime occurredAt;
  final bool synced;
}
