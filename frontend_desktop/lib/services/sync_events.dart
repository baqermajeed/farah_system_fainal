import 'dart:async';

import 'package:frontend_desktop/models/medical_record_model.dart';
import 'package:frontend_desktop/models/gallery_image_model.dart';

/// أحداث مزامنة خفيفة لربط الواجهة بعد نجاح الرفع.
class SyncEvents {
  SyncEvents._();

  static final _noteSyncedController =
      StreamController<NoteSyncedEvent>.broadcast();
  static final _noteRemovedController =
      StreamController<NoteRemovedEvent>.broadcast();
  static final _gallerySyncedController =
      StreamController<GallerySyncedEvent>.broadcast();
  static final _galleryRemovedController =
      StreamController<GalleryRemovedEvent>.broadcast();
  static final _pendingCountController = StreamController<int>.broadcast();

  static Stream<NoteSyncedEvent> get noteSynced => _noteSyncedController.stream;
  static Stream<NoteRemovedEvent> get noteRemoved =>
      _noteRemovedController.stream;
  static Stream<GallerySyncedEvent> get gallerySynced =>
      _gallerySyncedController.stream;
  static Stream<GalleryRemovedEvent> get galleryRemoved =>
      _galleryRemovedController.stream;
  static Stream<int> get pendingCount => _pendingCountController.stream;

  static void emitNoteSynced(NoteSyncedEvent event) {
    if (!_noteSyncedController.isClosed) {
      _noteSyncedController.add(event);
    }
  }

  static void emitNoteRemoved(NoteRemovedEvent event) {
    if (!_noteRemovedController.isClosed) {
      _noteRemovedController.add(event);
    }
  }

  static void emitGallerySynced(GallerySyncedEvent event) {
    if (!_gallerySyncedController.isClosed) {
      _gallerySyncedController.add(event);
    }
  }

  static void emitGalleryRemoved(GalleryRemovedEvent event) {
    if (!_galleryRemovedController.isClosed) {
      _galleryRemovedController.add(event);
    }
  }

  static void emitPendingCount(int count) {
    if (!_pendingCountController.isClosed) {
      _pendingCountController.add(count);
    }
  }
}

class NoteSyncedEvent {
  final String patientId;
  final String localNoteId;
  final MedicalRecordModel serverRecord;

  const NoteSyncedEvent({
    required this.patientId,
    required this.localNoteId,
    required this.serverRecord,
  });
}

class NoteRemovedEvent {
  final String patientId;
  final String noteId;

  const NoteRemovedEvent({
    required this.patientId,
    required this.noteId,
  });
}

class GallerySyncedEvent {
  final String patientId;
  final String localImageId;
  final GalleryImageModel serverImage;

  const GallerySyncedEvent({
    required this.patientId,
    required this.localImageId,
    required this.serverImage,
  });
}

class GalleryRemovedEvent {
  final String patientId;
  final String imageId;

  const GalleryRemovedEvent({
    required this.patientId,
    required this.imageId,
  });
}
