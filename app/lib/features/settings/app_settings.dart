class AppSettings {
  const AppSettings({
    this.textScale = minTextScale,
    this.highContrast = false,
    this.reduceMotion = false,
    this.welcomeSeen = false,
  });

  static const double minTextScale = 1.0;
  static const double maxTextScale = 2.0;

  final double textScale;
  final bool highContrast;
  final bool reduceMotion;

  /// Whether the first-run welcome screen has been completed.
  final bool welcomeSeen;

  AppSettings copyWith({
    double? textScale,
    bool? highContrast,
    bool? reduceMotion,
    bool? welcomeSeen,
  }) {
    return AppSettings(
      textScale: textScale ?? this.textScale,
      highContrast: highContrast ?? this.highContrast,
      reduceMotion: reduceMotion ?? this.reduceMotion,
      welcomeSeen: welcomeSeen ?? this.welcomeSeen,
    );
  }
}
