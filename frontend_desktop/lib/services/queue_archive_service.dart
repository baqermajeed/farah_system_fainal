import 'package:frontend_desktop/core/network/api_constants.dart';
import 'package:frontend_desktop/models/queue_entry_model.dart';
import 'package:frontend_desktop/services/api_service.dart';

/// مزامنة أرشيف الطابور مع السيرفر فقط (لا يُستخدم للعرض أو النداء).
class QueueArchiveService {
  final _api = ApiService();

  /// يحفظ ليوم محدد: العدد، الأسماء، وأرقام الطابور.
  Future<void> syncDay({
    required String dateKey,
    required List<QueueEntry> entries,
  }) async {
    final payload = {
      'date': dateKey,
      'entries': entries
          .map((e) => {'number': e.number, 'name': e.name})
          .toList(growable: false),
    };

    await _api.put(ApiConstants.receptionQueue, data: payload);
  }
}
