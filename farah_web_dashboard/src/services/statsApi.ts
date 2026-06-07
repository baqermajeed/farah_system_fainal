import { http } from './http';
import type {
  AppointmentsStatsResponse,
  ChatStatsResponse,
  DashboardStats,
  DoctorAppointmentsBreakdownResponse,
  DoctorPatientsBreakdownResponse,
  DoctorPatientTransfersResponse,
  DoctorProfileResponse,
  DoctorsComparisonResponse,
  DoctorStatsListResponse,
  DoctorPatientListItem,
  NotificationStatsResponse,
  TokenResponse,
  TransfersStatsResponse,
  UsersStatsResponse,
} from '../types/stats';

const authHeaders = {
  'Content-Type': 'application/x-www-form-urlencoded',
};

export async function loginStaff(username: string, password: string): Promise<TokenResponse> {
  const form = new URLSearchParams();
  form.append('username', username);
  form.append('password', password);
  const { data } = await http.post<TokenResponse>('/auth/staff-login', form, { headers: authHeaders });
  return data;
}

export async function fetchDashboardStats() {
  const { data } = await http.get<DashboardStats>('/stats/dashboard');
  return data;
}

export async function fetchDoctorsStats() {
  const { data } = await http.get<DoctorStatsListResponse>('/stats/doctors');
  return data;
}

export async function fetchAdminDoctorPatients(
  doctorId: string,
  params: { date_from?: string; date_to?: string; skip?: number; limit?: number },
) {
  const { data } = await http.get<DoctorPatientListItem[]>(`/admin/doctors/${doctorId}/patients`, { params });
  return data;
}

export async function setDoctorManager(doctorId: string, isManager: boolean) {
  const { data } = await http.patch<{ ok: boolean; doctor_id: string; is_manager: boolean }>(
    `/admin/doctors/${doctorId}/manager`,
    { is_manager: isManager },
  );
  return data;
}

export async function fetchDoctorsComparison(params: { date_from?: string; date_to?: string }) {
  const { data } = await http.get<DoctorsComparisonResponse>('/stats/doctors/comparison', { params });
  return data;
}

export async function fetchDoctorProfile(doctorId: string, params: { date_from?: string; date_to?: string }) {
  const { data } = await http.get<DoctorProfileResponse>(`/stats/doctors/${doctorId}/profile`, { params });
  return data;
}

export async function fetchDoctorPatientTransfers(doctorId: string, params: { date_from?: string; date_to?: string }) {
  const { data } = await http.get<DoctorPatientTransfersResponse>(`/stats/doctors/${doctorId}/patient-transfers`, {
    params,
  });
  return data;
}

export async function fetchDoctorPatientsBreakdown(
  doctorId: string,
  params: Record<string, string | undefined>,
) {
  const { data } = await http.get<DoctorPatientsBreakdownResponse>(`/stats/doctors/${doctorId}/patients-breakdown`, {
    params,
  });
  return data;
}

export async function fetchDoctorAppointmentsBreakdown(
  doctorId: string,
  params: Record<string, string | undefined>,
) {
  const { data } = await http.get<DoctorAppointmentsBreakdownResponse>(
    `/stats/doctors/${doctorId}/appointments-breakdown`,
    {
      params,
    },
  );
  return data;
}

export async function fetchUsersStats() {
  const { data } = await http.get<UsersStatsResponse>('/stats/users');
  return data;
}

export async function fetchAppointmentsStats(params: { date_from?: string; date_to?: string }) {
  const { data } = await http.get<AppointmentsStatsResponse>('/stats/appointments', { params });
  return data;
}

export async function fetchChatStats(params: { date_from?: string; date_to?: string }) {
  const { data } = await http.get<ChatStatsResponse>('/stats/chat', { params });
  return data;
}

export async function fetchNotificationsStats(params: { date_from?: string; date_to?: string }) {
  const { data } = await http.get<NotificationStatsResponse>('/stats/notifications', { params });
  return data;
}

export async function fetchTransfersStats(params: {
  group?: 'day' | 'month' | 'year';
  date_from?: string;
  date_to?: string;
  doctor_id?: string;
}) {
  const { data } = await http.get<TransfersStatsResponse>('/stats/transfers', { params });
  return data;
}
