enum PatientActivityFilterMode {
  daily,
  monthly,
  custom,
}

extension PatientActivityFilterModeLabel on PatientActivityFilterMode {
  String get label {
    switch (this) {
      case PatientActivityFilterMode.daily:
        return 'يومي';
      case PatientActivityFilterMode.monthly:
        return 'شهري';
      case PatientActivityFilterMode.custom:
        return 'فترة مخصصة';
    }
  }
}

