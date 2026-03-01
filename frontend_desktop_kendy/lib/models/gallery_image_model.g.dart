// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'gallery_image_model.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class GalleryImageModelAdapter extends TypeAdapter<GalleryImageModel> {
  @override
  final int typeId = 5;

  @override
  GalleryImageModel read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return GalleryImageModel(
      id: fields[0] as String,
      patientId: fields[1] as String,
      doctorId: fields[2] as String?,
      imagePath: fields[3] as String,
      note: fields[4] as String?,
      createdAt: fields[5] as String,
    );
  }

  @override
  void write(BinaryWriter writer, GalleryImageModel obj) {
    writer
      ..writeByte(6)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.patientId)
      ..writeByte(2)
      ..write(obj.doctorId)
      ..writeByte(3)
      ..write(obj.imagePath)
      ..writeByte(4)
      ..write(obj.note)
      ..writeByte(5)
      ..write(obj.createdAt);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is GalleryImageModelAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
