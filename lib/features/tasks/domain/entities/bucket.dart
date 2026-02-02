import 'package:flutter/material.dart';

class Bucket {
  final String name;
  final bool isArchived;
  final bool showOnDashboard;
  final int? iconCode;
  final String? iconFamily;
  final int? iconColorValue;

  // Default icon: Icons.check_circle (orange task icon)
  static const int defaultIconCode = 0xe86c; // Icons.check_circle
  static const String defaultIconFamily = 'MaterialIcons';
  static const Color defaultIconColor = Colors.orange;

  const Bucket({
    required this.name,
    this.isArchived = false,
    this.showOnDashboard = false,
    this.iconCode,
    this.iconFamily,
    this.iconColorValue,
  });

  /// Returns the IconData for this bucket, or default if not set
  IconData get icon => IconData(
    iconCode ?? defaultIconCode,
    fontFamily: iconFamily ?? defaultIconFamily,
  );

  /// Returns the Color for this bucket's icon, or default if not set
  Color get iconColor =>
      iconColorValue != null ? Color(iconColorValue!) : defaultIconColor;

  Bucket copyWith({
    String? name,
    bool? isArchived,
    bool? showOnDashboard,
    int? iconCode,
    String? iconFamily,
    int? iconColorValue,
  }) {
    return Bucket(
      name: name ?? this.name,
      isArchived: isArchived ?? this.isArchived,
      showOnDashboard: showOnDashboard ?? this.showOnDashboard,
      iconCode: iconCode ?? this.iconCode,
      iconFamily: iconFamily ?? this.iconFamily,
      iconColorValue: iconColorValue ?? this.iconColorValue,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'isArchived': isArchived,
      'showOnDashboard': showOnDashboard,
      if (iconCode != null) 'iconCode': iconCode,
      if (iconFamily != null) 'iconFamily': iconFamily,
      if (iconColorValue != null) 'iconColorValue': iconColorValue,
    };
  }

  factory Bucket.fromMap(Map<String, dynamic> map) {
    return Bucket(
      name: map['name'] ?? '',
      isArchived: map['isArchived'] ?? false,
      showOnDashboard: map['showOnDashboard'] ?? false,
      iconCode: map['iconCode'],
      iconFamily: map['iconFamily'],
      iconColorValue: map['iconColorValue'],
    );
  }
}
