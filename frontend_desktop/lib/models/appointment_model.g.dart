// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'appointment_model.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class AppointmentModelAdapter extends TypeAdapter<AppointmentModel> {
  @override
  final int typeId = 2;

  @override
  AppointmentModel read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return AppointmentModel(
      id: fields[0] as String? ?? '',
      patientId: fields[1] as String? ?? '',
      patientName: fields[2] as String? ?? '',
      patientPhone: fields[12] as String?,
      doctorId: fields[3] as String? ?? '',
      doctorName: fields[4] as String? ?? '',
      date: fields[5] is DateTime ? fields[5] as DateTime : DateTime.now(),
      time: fields[6] as String? ?? '',
      status: fields[7] as String? ?? 'pending',
      notes: fields[8] as String?,
      imagePath: fields[9] as String?,
      imagePaths: (fields[10] as List?)
              ?.map((e) => e.toString())
              .toList() ??
          const <String>[],
      isLate: fields[13] as bool? ?? false,
      kind: fields[14] as String? ?? 'regular',
      stageName: fields[15] as String?,
    );
  }

  @override
  void write(BinaryWriter writer, AppointmentModel obj) {
    writer
      ..writeByte(16)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.patientId)
      ..writeByte(2)
      ..write(obj.patientName)
      ..writeByte(12)
      ..write(obj.patientPhone)
      ..writeByte(3)
      ..write(obj.doctorId)
      ..writeByte(4)
      ..write(obj.doctorName)
      ..writeByte(5)
      ..write(obj.date)
      ..writeByte(6)
      ..write(obj.time)
      ..writeByte(7)
      ..write(obj.status)
      ..writeByte(8)
      ..write(obj.notes)
      ..writeByte(9)
      ..write(obj.imagePath)
      ..writeByte(10)
      ..write(obj.imagePaths)
      ..writeByte(13)
      ..write(obj.isLate)
      ..writeByte(14)
      ..write(obj.kind)
      ..writeByte(15)
      ..write(obj.stageName);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AppointmentModelAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
