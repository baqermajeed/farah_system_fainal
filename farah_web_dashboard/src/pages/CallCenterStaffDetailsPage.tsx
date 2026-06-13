import { ArrowRightOutlined } from '@ant-design/icons';
import { Button, Card, Col, Empty, Input, Row, Spin, Typography } from 'antd';
import { useEffect, useState } from 'react';
import { useLocation, useNavigate, useParams } from 'react-router-dom';
import { KpiCard } from '../components/KpiCard';
import { fetchCallCenterAppointmentsFromBoth, fetchCallCenterStaffFromBoth, fetchSystemPatients } from '../services/statsApi';
import type { CallCenterAppointmentListItem, CallCenterStaffAppointmentStats, DoctorPatientListItem, StaffUser } from '../types/stats';

type DetailsLocationState = {
  member?: StaffUser;
};

function sameCalendarDay(a: Date, b: Date) {
  return a.getFullYear() === b.getFullYear() && a.getMonth() === b.getMonth() && a.getDate() === b.getDate();
}

function sameCalendarMonth(a: Date, b: Date) {
  return a.getFullYear() === b.getFullYear() && a.getMonth() === b.getMonth();
}

function buildStatsFromAppointments(
  staffId: string,
  appointments: CallCenterAppointmentListItem[],
): CallCenterStaffAppointmentStats {
  const now = new Date();

  let today = 0;
  let thisMonth = 0;
  let acceptedThisMonth = 0;

  for (const appointment of appointments) {
    const createdAt = appointment.created_at ? new Date(appointment.created_at) : null;
    const scheduledAt = appointment.scheduled_at ? new Date(appointment.scheduled_at) : null;
    const baseDate = createdAt && !Number.isNaN(createdAt.getTime()) ? createdAt : scheduledAt;
    if (!baseDate || Number.isNaN(baseDate.getTime())) continue;

    if (sameCalendarDay(baseDate, now)) {
      today += 1;
    }
    if (sameCalendarMonth(baseDate, now)) {
      thisMonth += 1;
    }

    if ((appointment.status ?? '').trim().toLowerCase() === 'accepted') {
      const acceptedAt = appointment.accepted_at ? new Date(appointment.accepted_at) : null;
      const acceptedDate = acceptedAt && !Number.isNaN(acceptedAt.getTime()) ? acceptedAt : baseDate;
      if (sameCalendarMonth(acceptedDate, now)) {
        acceptedThisMonth += 1;
      }
    }
  }

  const total = appointments.length;
  const notAcceptedThisMonth = Math.max(0, thisMonth - acceptedThisMonth);

  return {
    user_id: staffId,
    total,
    today,
    this_month: thisMonth,
    range: { from: null, to: null, count: total },
    accepted: acceptedThisMonth,
    not_accepted: notAcceptedThisMonth,
  };
}

export function CallCenterStaffDetailsPage() {
  const navigate = useNavigate();
  const { staffId } = useParams<{ staffId: string }>();
  const location = useLocation();
  const routeState = (location.state as DetailsLocationState | null) ?? null;

  const [staffMember, setStaffMember] = useState<StaffUser | null>(routeState?.member ?? null);
  const [stats, setStats] = useState<CallCenterStaffAppointmentStats | null>(null);
  const [loading, setLoading] = useState(true);
  const [patientSearch, setPatientSearch] = useState('');
  const [patientSearchLoading, setPatientSearchLoading] = useState(false);
  const [patientSearchTouched, setPatientSearchTouched] = useState(false);
  const [patientResults, setPatientResults] = useState<DoctorPatientListItem[]>([]);

  useEffect(() => {
    if (!staffId) {
      setLoading(false);
      return;
    }

    const load = async () => {
      try {
        setLoading(true);

        let resolvedMember = routeState?.member ?? null;
        if (!routeState?.member) {
          const staff = await fetchCallCenterStaffFromBoth();
          const matchedMember = staff.find((item) => item.id === staffId) ?? null;
          setStaffMember(matchedMember);
          resolvedMember = matchedMember;
        }

        const appointments = await fetchCallCenterAppointmentsFromBoth({
          created_by_user_id: staffId,
          staff_phone: resolvedMember?.phone ?? null,
        });
        const statsData = buildStatsFromAppointments(staffId, appointments);
        setStats(statsData);
      } catch (error) {
        console.error('Failed to load call center staff details', error);
        setStats(null);
      } finally {
        setLoading(false);
      }
    };

    void load();
  }, [routeState?.member, staffId]);

  if (loading) return <Spin size="large" />;

  if (!staffId) {
    return (
      <Card className="glass-card">
        <Empty description="معرّف الموظف غير صحيح" />
      </Card>
    );
  }

  const runPatientSearch = async (raw: string) => {
    const query = raw.trim();
    setPatientSearchTouched(true);

    if (!query) {
      setPatientResults([]);
      return;
    }

    try {
      setPatientSearchLoading(true);
      const data = await fetchSystemPatients({ search: query, skip: 0, limit: 30 });
      setPatientResults(data);
    } catch (error) {
      console.error('Failed to search patients', error);
      setPatientResults([]);
    } finally {
      setPatientSearchLoading(false);
    }
  };

  return (
    <div className="page-wrap">
      <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', gap: 12 }}>
        <div>
          <Typography.Title level={3} style={{ marginBottom: 0 }}>
            تفاصيل موظف الكول سنتر
          </Typography.Title>
          <Typography.Paragraph type="secondary" style={{ marginBottom: 0 }}>
            {staffMember?.name ?? 'موظف غير معروف'} - {staffMember?.phone ?? '-'}
          </Typography.Paragraph>
        </div>
        <Button icon={<ArrowRightOutlined />} onClick={() => navigate('/call-center')}>
          رجوع
        </Button>
      </div>

      <Row gutter={[12, 12]} style={{ marginTop: 12 }}>
        <Col xs={24} md={12} xl={8}>
          <KpiCard title="عدد الحجوزات الكلي" value={stats?.total ?? 0} />
        </Col>
        <Col xs={24} md={12} xl={8}>
          <KpiCard title="عدد الحجوزات هذا الشهر" value={stats?.this_month ?? 0} />
        </Col>
        <Col xs={24} md={12} xl={8}>
          <KpiCard title="عدد الحجوزات اليوم" value={stats?.today ?? 0} />
        </Col>
        <Col xs={24} md={12} xl={12}>
          <KpiCard title="عدد الحجوزات المقبولة هذا الشهر" value={stats?.accepted ?? 0} />
        </Col>
        <Col xs={24} md={12} xl={12}>
          <KpiCard title="عدد الحجوزات غير المقبولة هذا الشهر" value={stats?.not_accepted ?? 0} />
        </Col>
      </Row>

      <Card className="glass-card" style={{ marginTop: 16 }}>
        <Typography.Title level={4} style={{ marginBottom: 8 }}>
          البحث العام عن مريض
        </Typography.Title>
        <Typography.Paragraph type="secondary" style={{ marginBottom: 12 }}>
          ابحث بالاسم أو رقم الهاتف على مستوى النظام بالكامل.
        </Typography.Paragraph>

        <Input.Search
          value={patientSearch}
          placeholder="اكتب اسم المريض أو رقم الهاتف"
          enterButton="بحث"
          allowClear
          onChange={(event) => setPatientSearch(event.target.value)}
          onSearch={(value) => {
            void runPatientSearch(value);
          }}
        />

        <div style={{ marginTop: 12 }}>
          {patientSearchLoading ? (
            <Spin />
          ) : patientResults.length === 0 ? (
            patientSearchTouched ? <Empty description="لا توجد نتائج مطابقة" /> : null
          ) : (
            <Row gutter={[12, 12]}>
              {patientResults.map((patient) => (
                <Col xs={24} md={12} xl={8} key={patient.id}>
                  <Card size="small" className="glass-card">
                    <Typography.Title level={5} style={{ marginBottom: 6 }}>
                      {patient.name ?? 'مريض بدون اسم'}
                    </Typography.Title>
                    <Typography.Paragraph style={{ marginBottom: 4 }}>
                      رقم الهاتف: {patient.phone}
                    </Typography.Paragraph>
                    <Typography.Paragraph style={{ marginBottom: 4 }}>
                      المدينة: {patient.city ?? 'غير محددة'}
                    </Typography.Paragraph>
                    <Typography.Paragraph style={{ marginBottom: 0 }}>
                      نوع الزيارة: {patient.visit_type ?? 'غير محدد'}
                    </Typography.Paragraph>
                  </Card>
                </Col>
              ))}
            </Row>
          )}
        </div>
      </Card>
    </div>
  );
}
