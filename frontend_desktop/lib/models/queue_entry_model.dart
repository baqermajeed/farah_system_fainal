enum QueueEntryStatus { waiting, called, done }

extension QueueEntryStatusX on QueueEntryStatus {
  String get value {
    switch (this) {
      case QueueEntryStatus.waiting:
        return 'waiting';
      case QueueEntryStatus.called:
        return 'called';
      case QueueEntryStatus.done:
        return 'done';
    }
  }

  static QueueEntryStatus fromValue(String? raw) {
    switch (raw) {
      case 'called':
        return QueueEntryStatus.called;
      case 'done':
        return QueueEntryStatus.done;
      case 'waiting':
      default:
        return QueueEntryStatus.waiting;
    }
  }
}

class QueueEntry {
  final String id;
  final int number;
  final String name;
  final QueueEntryStatus status;

  const QueueEntry({
    required this.id,
    required this.number,
    required this.name,
    this.status = QueueEntryStatus.waiting,
  });

  QueueEntry copyWith({
    int? number,
    String? name,
    QueueEntryStatus? status,
  }) {
    return QueueEntry(
      id: id,
      number: number ?? this.number,
      name: name ?? this.name,
      status: status ?? this.status,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'number': number,
    'name': name,
    'status': status.value,
  };

  factory QueueEntry.fromJson(Map<String, dynamic> json) {
    return QueueEntry(
      id: json['id']?.toString() ?? '',
      number: json['number'] is int
          ? json['number'] as int
          : int.tryParse('${json['number']}') ?? 0,
      name: json['name']?.toString() ?? '',
      status: QueueEntryStatusX.fromValue(json['status']?.toString()),
    );
  }
}
