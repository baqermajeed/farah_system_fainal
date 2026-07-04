/// أمر مزامنة دائم يُحفظ على القرص حتى يؤكد السيرفر الاستلام.
/// لا يُحذف إلا بعد نجاح الرفع (2xx) — إعادة المحاولة بلا نهاية.
class SyncOutboxEntry {
  static const String statusPending = 'pending';
  static const String statusSending = 'sending';

  static const String typeAddNote = 'add_note';
  static const String typeUpdateNote = 'update_note';
  static const String typeDeleteNote = 'delete_note';

  final String id;
  final String idempotencyKey;
  final String type;
  final String entityKey;
  final Map<String, dynamic> payload;
  final String status;
  final int createdAtMs;
  final int priority;
  final int retryCount;
  final int nextAttemptAtMs;
  final String? lastError;

  const SyncOutboxEntry({
    required this.id,
    required this.idempotencyKey,
    required this.type,
    required this.entityKey,
    required this.payload,
    required this.status,
    required this.createdAtMs,
    this.priority = 0,
    this.retryCount = 0,
    this.nextAttemptAtMs = 0,
    this.lastError,
  });

  bool get isReady {
    if (status != statusPending && status != statusSending) return false;
    return DateTime.now().millisecondsSinceEpoch >= nextAttemptAtMs;
  }

  SyncOutboxEntry copyWith({
    String? status,
    Map<String, dynamic>? payload,
    int? retryCount,
    int? nextAttemptAtMs,
    String? lastError,
    bool clearLastError = false,
  }) {
    return SyncOutboxEntry(
      id: id,
      idempotencyKey: idempotencyKey,
      type: type,
      entityKey: entityKey,
      payload: payload ?? Map<String, dynamic>.from(this.payload),
      status: status ?? this.status,
      createdAtMs: createdAtMs,
      priority: priority,
      retryCount: retryCount ?? this.retryCount,
      nextAttemptAtMs: nextAttemptAtMs ?? this.nextAttemptAtMs,
      lastError: clearLastError ? null : (lastError ?? this.lastError),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'idempotencyKey': idempotencyKey,
      'type': type,
      'entityKey': entityKey,
      'payload': payload,
      'status': status,
      'createdAtMs': createdAtMs,
      'priority': priority,
      'retryCount': retryCount,
      'nextAttemptAtMs': nextAttemptAtMs,
      'lastError': lastError,
    };
  }

  factory SyncOutboxEntry.fromMap(Map<dynamic, dynamic> map) {
    final payloadRaw = map['payload'];
    final payload = <String, dynamic>{};
    if (payloadRaw is Map) {
      payloadRaw.forEach((key, value) {
        payload['$key'] = value;
      });
    }

    return SyncOutboxEntry(
      id: '${map['id'] ?? ''}',
      idempotencyKey: '${map['idempotencyKey'] ?? map['id'] ?? ''}',
      type: '${map['type'] ?? ''}',
      entityKey: '${map['entityKey'] ?? ''}',
      payload: payload,
      status: '${map['status'] ?? statusPending}',
      createdAtMs: _asInt(map['createdAtMs']),
      priority: _asInt(map['priority']),
      retryCount: _asInt(map['retryCount']),
      nextAttemptAtMs: _asInt(map['nextAttemptAtMs']),
      lastError: map['lastError']?.toString(),
    );
  }

  static int _asInt(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse('$value') ?? 0;
  }
}
