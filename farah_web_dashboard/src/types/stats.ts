export type TokenResponse = {
  access_token: string;
  refresh_token: string;
};

export type StaffUser = {
  id: string;
  name: string | null;
  phone: string;
  gender?: string | null;
  age?: number | null;
  city?: string | null;
  imageUrl?: string | null;
  role: string;
  doctor_manager?: boolean | null;
};

export type CallCenterStaffAppointmentStats = {
  user_id: string | null;
  total: number;
  today: number;
  this_month: number;
  range: {
    from: string | null;
    to: string | null;
    count: number;
  };
  accepted: number;
  not_accepted: number;
};

export type CallCenterAppointmentListItem = {
  id: string;
  patient_name: string;
  patient_phone: string;
  scheduled_at: string;
  governorate: string;
  platform: string;
  note: string;
  created_by_user_id: string;
  created_by_username: string;
  created_at: string;
  status: string;
  accepted_at?: string | null;
};

export type DashboardStats = {
  overview: {
    total_patients: number;
    total_doctors: number;
    total_appointments: number;
    upcoming_appointments: number;
  };
  today: {
    new_patients: number;
    appointments: number;
    chat_messages: number;
  };
  this_month: {
    new_patients: number;
    appointments: number;
  };
  appointments_by_status: Record<string, number>;
  chat: { total_rooms: number; total_messages: number };
  notifications: { total_sent: number; active_devices: number };
  patient_types: {
    all: {
      visit_type: Record<string, number>;
      consultation_type: Record<string, number>;
    };
  };
};

export type OverviewStatsResponse = {
  group: string;
  range: { from: string | null; to: string | null };
  new_patients: Array<{ period: string; count: number }>;
};

export type DoctorComparison = {
  doctor_id: string;
  user_id: string;
  name: string | null;
  phone: string | null;
  imageUrl: string | null;
  is_manager: boolean;
  patients: {
    total_current: number;
    active_current: number;
    pending_current: number;
    inactive_current: number;
  };
  transfers: {
    today: number;
    this_month: number;
    range: number;
  };
  appointments: {
    today: number;
    this_month: number;
    range: number;
    completed_all_time: number;
  };
  treatment_notes: number;
};

export type DoctorsComparisonResponse = {
  range: { from: string | null; to: string | null };
  total_doctors: number;
  doctors: DoctorComparison[];
};

export type DoctorBasic = {
  doctor_id: string;
  user_id: string;
  name: string | null;
  phone: string | null;
  imageUrl: string | null;
};

export type DoctorStatsListResponse = {
  doctors: Array<
    DoctorBasic & {
      total_patients: number;
      total_appointments: number;
      completed_appointments: number;
      treatment_notes: number;
    }
  >;
  total_doctors: number;
};

export type DoctorPatientListItem = {
  id: string;
  user_id: string;
  name: string | null;
  phone: string;
  gender?: string | null;
  age?: number | null;
  city?: string | null;
  treatment_type?: string | null;
  doctor_profiles?: Record<
    string,
    {
      treatment_type?: string | null;
      assigned_at?: string | null;
      last_action_at?: string | null;
      payment_methods?: string[] | null;
    }
  >;
  visit_type?: string | null;
  consultation_type?: string | null;
  payment_methods?: string[] | null;
  imageUrl?: string | null;
  created_at?: string | null;
};

export type DoctorProfileResponse = {
  doctor: DoctorBasic & { is_manager: boolean };
  counts: {
    total_patients: number;
    total_appointments: number;
    today_messages: number;
  };
  patient_insights: {
    gender: {
      male: number;
      female: number;
      unknown: number;
    };
    age: {
      top_bucket_label: string;
      top_bucket_count: number;
      unknown_count: number;
    };
    treatment: {
      top_type: string;
      top_count: number;
      total_linked: number;
    };
  };
  messages: {
    total: number;
    today: number;
    this_month: number;
    range: { from: string | null; to: string | null; count: number };
  };
  appointments: {
    today: number;
    this_month: number;
    range: { from: string | null; to: string | null; count: number };
  };
  transfers: {
    today: number;
    this_month: number;
    range: { from: string | null; to: string | null; count: number };
  };
};

export type DoctorDetailsCardsResponse = {
  doctor: DoctorBasic & { is_manager: boolean };
  counts: {
    total_patients: number;
  };
  patient_insights: {
    gender: {
      male: number;
      female: number;
      unknown: number;
    };
    age: {
      top_bucket_label: string;
      top_bucket_count: number;
      unknown_count: number;
    };
    treatment: {
      top_type: string;
      top_count: number;
      total_linked: number;
    };
  };
  metrics: {
    period_patients_count: number;
    transfers_today: number;
    transfers_month_unique: number;
    transfers_month_ops: number;
    active_count: number;
    inactive_count: number;
    pending_count: number;
  };
  range: {
    from: string | null;
    to: string | null;
  };
};

export type DoctorPatientTransfersResponse = {
  doctor_id: string;
  transfers: {
    today: number;
    this_month: number;
    range: { from: string | null; to: string | null; count: number };
  };
  active_patients: {
    today: number;
    this_month: number;
    range: { from: string | null; to: string | null; count: number };
  };
  pending_patients: {
    today: number;
    this_month: number;
    range: { from: string | null; to: string | null; count: number };
  };
  inactive_patients: {
    today: number;
    this_month: number;
    range: { from: string | null; to: string | null; count: number };
  };
};

export type DoctorPatientsBreakdownResponse = {
  doctor: DoctorBasic & { is_manager: boolean };
  group: 'day' | 'month' | 'year';
  range: { from: string | null; to: string | null };
  filters: Record<string, string | null>;
  patients: {
    today: BreakdownBlock;
    this_month: BreakdownBlock;
    range: BreakdownBlock;
    current: BreakdownBlock;
  };
  timeline: Array<{ period: string; total: number; active: number; pending: number; inactive: number }>;
};

export type BreakdownBlock = {
  total: number;
  visit_type: Record<string, number>;
  consultation_type: Record<string, number>;
  gender: Record<string, number>;
  activity_status: Record<string, number>;
  cities: Array<{ city: string; count: number }>;
};

export type DoctorAppointmentsBreakdownResponse = {
  doctor: DoctorBasic & { is_manager: boolean };
  filters?: {
    status?: string | null;
    stage_name?: string | null;
  };
  summary: {
    today: number;
    this_month: number;
    range_count: number;
    selected_count?: number;
    upcoming_now: number;
    all_time: number;
  };
  by_status: Record<string, Record<string, number>>;
  timeline: Array<{ period: string; count: number }>;
  today_list: Array<{
    id: string;
    patient_id: string;
    patient_name: string | null;
    patient_phone?: string | null;
    scheduled_at: string;
    status: string;
    stage_name: string | null;
    note: string | null;
  }>;
  selected_list?: Array<{
    id: string;
    patient_id: string;
    patient_name: string | null;
    patient_phone?: string | null;
    scheduled_at: string;
    status: string;
    stage_name: string | null;
    note: string | null;
  }>;
};

export type UsersStatsResponse = {
  total_users: number;
  by_role: Record<string, number>;
};

export type AppointmentsStatsResponse = {
  total: number;
  by_status: Record<string, number>;
  by_doctor: Record<string, number>;
  upcoming: number;
  past: number;
  range: { from: string | null; to: string | null };
};

export type ChatStatsResponse = {
  total_rooms: number;
  total_messages: number;
  messages_by_doctor: Record<string, number>;
  rooms_by_doctor: Record<string, number>;
};

export type NotificationStatsResponse = {
  total_notifications: number;
  total_active_devices: number;
};

export type TransfersStatsResponse = {
  group: string;
  range: { from: string | null; to: string | null };
  doctor_id: string | null;
  by_period: Array<{ period: string; count: number }>;
  by_doctor: Record<string, number>;
  total_transfers: number;
};
