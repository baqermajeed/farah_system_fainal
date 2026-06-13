import { http } from './http';
import axios from 'axios';
import { appConfig } from '../config/appConfig';
import type {
  AppointmentsStatsResponse,
  ChatStatsResponse,
  CallCenterAppointmentListItem,
  CallCenterStaffAppointmentStats,
  DashboardStats,
  DoctorAppointmentsBreakdownResponse,
  DoctorDetailsCardsResponse,
  DoctorPatientsBreakdownResponse,
  DoctorPatientTransfersResponse,
  DoctorProfileResponse,
  DoctorsComparisonResponse,
  DoctorStatsListResponse,
  DoctorPatientListItem,
  NotificationStatsResponse,
  OverviewStatsResponse,
  StaffUser,
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

export async function fetchOverviewStats(params: {
  group?: 'day' | 'month' | 'year';
  date_from?: string;
  date_to?: string;
}) {
  const { data } = await http.get<OverviewStatsResponse>('/stats/overview', { params });
  return data;
}

export async function fetchDoctorsStats() {
  const { data } = await http.get<DoctorStatsListResponse>('/stats/doctors');
  return data;
}

export async function fetchStaffUsers(params?: { role?: string; skip?: number; limit?: number }) {
  const { data } = await http.get<StaffUser[]>('/admin/staff', { params });
  return data;
}

export async function fetchCallCenterStaffStats(params: { user_id: string }) {
  const { data } = await http.get<CallCenterStaffAppointmentStats>('/call-center/appointments/stats', {
    params,
  });
  return data;
}

export async function fetchCallCenterAppointments(params?: {
  date_from?: string;
  date_to?: string;
  created_by_user_id?: string;
  search?: string;
  skip?: number;
  limit?: number;
}) {
  const { data } = await http.get<CallCenterAppointmentListItem[]>('/call-center/appointments', { params });
  return data;
}

async function fetchCallCenterAppointmentsAllByBase(
  baseUrl: string,
  params: { created_by_user_id?: string; search?: string },
): Promise<CallCenterAppointmentListItem[]> {
  const pageSize = 100;
  let skip = 0;
  const all: CallCenterAppointmentListItem[] = [];

  while (true) {
    const token = localStorage.getItem('farah-access-token');
    const response = await axios.get<CallCenterAppointmentListItem[]>(`${baseUrl}/call-center/appointments`, {
      params: {
        ...params,
        skip,
        limit: pageSize,
      },
      headers: token ? { Authorization: `Bearer ${token}` } : undefined,
    });

    const batch = response.data ?? [];
    all.push(...batch);
    if (batch.length < pageSize) break;
    skip += pageSize;
  }

  return all;
}

async function fetchStaffUsersByBase(
  baseUrl: string,
  params?: { role?: string; skip?: number; limit?: number },
): Promise<StaffUser[]> {
  const token = localStorage.getItem('farah-access-token');
  const response = await axios.get<StaffUser[]>(`${baseUrl}/admin/staff`, {
    params,
    headers: token ? { Authorization: `Bearer ${token}` } : undefined,
  });
  return response.data ?? [];
}

function normalizePhone(phone: string | null | undefined) {
  return (phone ?? '').replace(/[٠-٩]/g, (digit) => String('٠١٢٣٤٥٦٧٨٩'.indexOf(digit))).replace(/\D/g, '');
}

function canonicalPhone(phone: string | null | undefined) {
  const digits = normalizePhone(phone);
  if (!digits) return '';
  if (digits.length === 13 && digits.startsWith('964')) {
    return `0${digits.slice(3)}`;
  }
  if (digits.length === 10 && digits.startsWith('7')) {
    return `0${digits}`;
  }
  return digits;
}

export async function fetchCallCenterAppointmentsFromBoth(params: { created_by_user_id: string; staff_phone?: string | null }) {
  const merged: CallCenterAppointmentListItem[] = [];
  const seen = new Set<string>();

  const pushUnique = (items: CallCenterAppointmentListItem[]) => {
    for (const item of items) {
      const key = `${item.id}|${item.created_at}|${item.created_by_user_id}`;
      if (!seen.has(key)) {
        seen.add(key);
        merged.push(item);
      }
    }
  };

  try {
    const najaf = await fetchCallCenterAppointmentsAllByBase(appConfig.apiBaseUrl, {
      created_by_user_id: params.created_by_user_id,
    });
    pushUnique(najaf);
  } catch (error) {
    console.error('Failed to load call center appointments from Najaf backend', error);
  }

  try {
    const candidateCreatorIds = new Set<string>();
    candidateCreatorIds.add(params.created_by_user_id);

    const kendyStaff = await fetchStaffUsersByBase(appConfig.apiKendyBaseUrl, { role: 'call_center', skip: 0, limit: 500 });
    const targetPhone = canonicalPhone(params.staff_phone);
    if (targetPhone) {
      for (const user of kendyStaff) {
        if (canonicalPhone(user.phone) === targetPhone && user.id) {
          candidateCreatorIds.add(user.id);
        }
      }
    }

    for (const creatorId of candidateCreatorIds) {
      const kendy = await fetchCallCenterAppointmentsAllByBase(appConfig.apiKendyBaseUrl, {
        created_by_user_id: creatorId,
      });
      pushUnique(kendy);
    }
  } catch (error) {
    console.error('Failed to load call center appointments from Kendy backend', error);
  }

  return merged;
}

export async function fetchCallCenterStaffFromBoth() {
  const [najafStaff, kendyStaff] = await Promise.allSettled([
    fetchStaffUsers({ role: 'call_center', skip: 0, limit: 500 }),
    fetchStaffUsersByBase(appConfig.apiKendyBaseUrl, { role: 'call_center', skip: 0, limit: 500 }),
  ]);

  const allStaff: StaffUser[] = [
    ...(najafStaff.status === 'fulfilled' ? najafStaff.value : []),
    ...(kendyStaff.status === 'fulfilled' ? kendyStaff.value : []),
  ];

  const byKey = new Map<string, StaffUser>();
  for (const staff of allStaff) {
    const phoneKey = canonicalPhone(staff.phone);
    const key = phoneKey || staff.id;
    if (!byKey.has(key)) {
      byKey.set(key, staff);
    }
  }

  return Array.from(byKey.values());
}

export async function fetchAdminDoctorPatients(
  doctorId: string,
  params: { date_from?: string; date_to?: string; skip?: number; limit?: number },
) {
  const { data } = await http.get<DoctorPatientListItem[]>(`/admin/doctors/${doctorId}/patients`, { params });
  return data;
}

export async function fetchSystemPatients(params: { search?: string; skip?: number; limit?: number }) {
  const { data } = await http.get<DoctorPatientListItem[]>('/reception/patients', { params });
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

export async function fetchDoctorDetailsCards(doctorId: string, params: { date_from?: string; date_to?: string }) {
  const { data } = await http.get<DoctorDetailsCardsResponse>(`/stats/doctors/${doctorId}/doctor-details-cards`, {
    params,
  });
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
