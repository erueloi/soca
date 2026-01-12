import 'package:cloud_firestore/cloud_firestore.dart';

enum InjuryType { fisica, quimica, mecanica, estructural }

class SubAction {
  final String id;
  final String title;
  final bool isCompleted;
  final String? taskId;

  SubAction({
    required this.id,
    required this.title,
    this.isCompleted = false,
    this.taskId,
  });

  Map<String, dynamic> toMap() => {
    'id': id,
    'title': title,
    'isCompleted': isCompleted,
    'taskId': taskId,
  };

  factory SubAction.fromMap(Map<String, dynamic> map) {
    return SubAction(
      id: map['id'] ?? '',
      title: map['title'] ?? '',
      isCompleted: map['isCompleted'] ?? false,
      taskId: map['taskId'],
    );
  }

  SubAction copyWith({
    String? id,
    String? title,
    bool? isCompleted,
    String? taskId,
  }) {
    return SubAction(
      id: id ?? this.id,
      title: title ?? this.title,
      isCompleted: isCompleted ?? this.isCompleted,
      taskId: taskId ?? this.taskId,
    );
  }
}

class HistoryEntry {
  final DateTime date;
  final String action; // e.g. "Canvi d'estat", "Nova foto"
  final String user;
  final String? comment;

  HistoryEntry({
    required this.date,
    required this.action,
    required this.user,
    this.comment,
  });

  Map<String, dynamic> toMap() => {
    'date': Timestamp.fromDate(date),
    'action': action,
    'user': user,
    'comment': comment,
  };

  factory HistoryEntry.fromMap(Map<String, dynamic> map) {
    return HistoryEntry(
      date: (map['date'] as Timestamp).toDate(),
      action: map['action'] ?? '',
      user: map['user'] ?? '',
      comment: map['comment'],
    );
  }
}

class PathologyPhoto {
  final String url;
  final DateTime? date;

  PathologyPhoto({required this.url, this.date});

  Map<String, dynamic> toMap() => {
    'url': url,
    'date': date != null ? Timestamp.fromDate(date!) : null,
  };

  factory PathologyPhoto.fromMap(Map<String, dynamic> map) {
    return PathologyPhoto(
      url: map['url'] ?? '',
      date: map['date'] != null ? (map['date'] as Timestamp).toDate() : null,
    );
  }

  factory PathologyPhoto.fromUrl(String url) => PathologyPhoto(url: url);
}

class PathologySheet {
  final String title;
  final InjuryType type;
  final String description;
  final List<PathologyPhoto> photos;
  final String causes;
  final String currentState;
  final String recommendedAction;
  final int severity; // 1-10
  final List<SubAction> subActions;
  final List<HistoryEntry> history;

  PathologySheet({
    required this.title,
    required this.type,
    required this.description,
    required this.photos,
    required this.causes,
    required this.currentState,
    required this.recommendedAction,
    required this.severity,
    this.subActions = const [],
    this.history = const [],
  });

  List<String> get photoUrls => photos.map((e) => e.url).toList();

  Map<String, dynamic> toMap() {
    return {
      'title': title,
      'type': type.name,
      'description': description,
      'photos': photos.map((e) => e.toMap()).toList(),
      // Keep legacy for safety? Or drop? Dropping is cleaner if migration is handled in fromMap.
      // 'photoUrls': photos.map((e) => e.url).toList(),
      'causes': causes,
      'currentState': currentState,
      'recommendedAction': recommendedAction,
      'severity': severity,
      'subActions': subActions.map((e) => e.toMap()).toList(),
      'history': history.map((e) => e.toMap()).toList(),
    };
  }

  factory PathologySheet.fromMap(Map<String, dynamic> map) {
    var photosList = <PathologyPhoto>[];
    if (map['photos'] != null) {
      photosList = (map['photos'] as List)
          .map((e) => PathologyPhoto.fromMap(e as Map<String, dynamic>))
          .toList();
    } else if (map['photoUrls'] != null) {
      photosList = (map['photoUrls'] as List)
          .map((e) => PathologyPhoto.fromUrl(e as String))
          .toList();
    }

    return PathologySheet(
      title: map['title'] ?? '',
      type: InjuryType.values.firstWhere(
        (e) => e.name == map['type'],
        orElse: () => InjuryType.fisica,
      ),
      description: map['description'] ?? '',
      photos: photosList,
      causes: map['causes'] ?? '',
      currentState: map['currentState'] ?? '',
      recommendedAction: map['recommendedAction'] ?? '',
      severity: map['severity'] ?? 1,
      subActions:
          (map['subActions'] as List<dynamic>?)
              ?.map((e) => SubAction.fromMap(e))
              .toList() ??
          [],
      history:
          (map['history'] as List<dynamic>?)
              ?.map((e) => HistoryEntry.fromMap(e))
              .toList() ??
          [],
    );
  }

  PathologySheet copyWith({
    String? title,
    InjuryType? type,
    String? description,
    List<PathologyPhoto>? photos,
    String? causes,
    String? currentState,
    String? recommendedAction,
    int? severity,
    List<SubAction>? subActions,
    List<HistoryEntry>? history,
  }) {
    return PathologySheet(
      title: title ?? this.title,
      type: type ?? this.type,
      description: description ?? this.description,
      photos: photos ?? this.photos,
      causes: causes ?? this.causes,
      currentState: currentState ?? this.currentState,
      recommendedAction: recommendedAction ?? this.recommendedAction,
      severity: severity ?? this.severity,
      subActions: subActions ?? this.subActions,
      history: history ?? this.history,
    );
  }
}

class ConstructionPoint {
  final String id;
  final String floorId; // "Planta Baixa", "Planta 1", etc.
  final double xPercent;
  final double yPercent;
  final PathologySheet? pathology;
  final DateTime createdAt;
  final String status; // "Pendent", "En Progrés", "Finalitzat"

  ConstructionPoint({
    required this.id,
    required this.floorId,
    required this.xPercent,
    required this.yPercent,
    this.pathology,
    required this.createdAt,
    this.status = 'Pendent',
  });

  Map<String, dynamic> toMap() {
    return {
      'floorId': floorId,
      'xPercent': xPercent,
      'yPercent': yPercent,
      'pathology': pathology?.toMap(),
      'createdAt': Timestamp.fromDate(createdAt),
      'status': status,
    };
  }

  factory ConstructionPoint.fromMap(Map<String, dynamic> map, String id) {
    return ConstructionPoint(
      id: id,
      floorId: map['floorId'] ?? '',
      xPercent: (map['xPercent'] ?? 0).toDouble(),
      yPercent: (map['yPercent'] ?? 0).toDouble(),
      pathology: map['pathology'] != null
          ? PathologySheet.fromMap(map['pathology'])
          : null,
      createdAt: (map['createdAt'] as Timestamp).toDate(),
      status: map['status'] ?? 'Pendent',
    );
  }

  ConstructionPoint copyWith({
    String? id,
    String? floorId,
    double? xPercent,
    double? yPercent,
    PathologySheet? pathology,
    DateTime? createdAt,
    String? status,
  }) {
    return ConstructionPoint(
      id: id ?? this.id,
      floorId: floorId ?? this.floorId,
      xPercent: xPercent ?? this.xPercent,
      yPercent: yPercent ?? this.yPercent,
      pathology: pathology ?? this.pathology,
      createdAt: createdAt ?? this.createdAt,
      status: status ?? this.status,
    );
  }
}
