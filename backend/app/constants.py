from enum import Enum

class Role(str, Enum):
    """System roles for RBAC."""
    ADMIN = "admin"           # المدير
    DOCTOR = "doctor"         # طبيب
    PATIENT = "patient"       # مريض
    RECEPTIONIST = "receptionist"  # موظف استقبال
    PHOTOGRAPHER = "photographer"  # مصور
    