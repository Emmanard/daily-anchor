import 'package:flutter/material.dart';

class Routine {
  const Routine({
    required this.id,
    required this.title,
    this.iconKey = defaultIconKey,
  });

  static const defaultIconKey = 'task';

  final String id;
  final String title;
  final String iconKey;

  IconData get icon => switch (iconKey) {
    'water' => Icons.water_drop_outlined,
    'walk' => Icons.directions_walk,
    'call' => Icons.call_outlined,
    _ => Icons.task_alt,
  };
}
