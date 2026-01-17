// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'medical_record_model.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class MedicalRecordModelAdapter extends TypeAdapter<MedicalRecordModel> {
  @override
  final int typeId = 3;

  @override
  MedicalRecordModel read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return MedicalRecordModel(
      id: fields[0] as String,
      patientId: fields[1] as String,
      doctorId: fields[2] as String,
      date: fields[3] as DateTime,
      treatmentType: fields[4] as String,
      diagnosis: fields[5] as String,
      images: (fields[6] as List?)?.cast<String>(),
      notes: fields[7] as String?,
    );
  }

  @override
  void write(BinaryWriter writer, MedicalRecordModel obj) {
    writer
      ..writeByte(8)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.patientId)
      ..writeByte(2)
      ..write(obj.doctorId)
      ..writeByte(3)
      ..write(obj.date)
      ..writeByte(4)
      ..write(obj.treatmentType)
      ..writeByte(5)
      ..write(obj.diagnosis)
      ..writeByte(6)
      ..write(obj.images)
      ..writeByte(7)
      ..write(obj.notes);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is MedicalRecordModelAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
