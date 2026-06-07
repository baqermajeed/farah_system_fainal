import { Card, Col, Row, Spin, Typography } from 'antd';
import { useEffect, useMemo, useState } from 'react';
import { useNavigate } from 'react-router-dom';
import { Pie, PieChart, ResponsiveContainer, Tooltip, XAxis, YAxis, CartesianGrid, BarChart, Bar } from 'recharts';
import { KpiCard } from '../components/KpiCard';
import { AuroraBackground } from '../components/AuroraBackground';
import { Doctor3DCard } from '../components/Doctor3DCard';
import { fetchDashboardStats, fetchDoctorsStats } from '../services/statsApi';
import type { DashboardStats, DoctorStatsListResponse } from '../types/stats';

export function OverviewPage() {
  const [loading, setLoading] = useState(true);
  const [data, setData] = useState<DashboardStats | null>(null);
  const [topDoctors, setTopDoctors] = useState<DoctorStatsListResponse['doctors']>([]);
  const navigate = useNavigate();

  useEffect(() => {
    const load = async () => {
      try {
        setLoading(true);
        const [dashboard, doctors] = await Promise.all([fetchDashboardStats(), fetchDoctorsStats()]);
        setData(dashboard);
        setTopDoctors(
          [...doctors.doctors]
            .sort((a, b) => (b.total_patients || 0) - (a.total_patients || 0))
            .slice(0, 4),
        );
      } catch (error) {
        console.error('Failed to load overview data', error);
        setData(null);
        setTopDoctors([]);
      } finally {
        setLoading(false);
      }
    };
    void load();
  }, []);

  const pieData = useMemo(
    () =>
      data
        ? Object.entries(data.appointments_by_status).map(([name, value]) => ({
            name,
            value,
          }))
        : [],
    [data],
  );

  const patientTypeBars = useMemo(() => {
    if (!data) return [];
    const visit = data.patient_types.all.visit_type;
    const consult = data.patient_types.all.consultation_type;
    return [
      { name: 'مريض جديد', value: visit.new ?? 0 },
      { name: 'مراجع قديم', value: visit.old ?? 0 },
      { name: 'معاينة مدفوعة', value: consult.paid ?? 0 },
      { name: 'معاينة مجانية', value: consult.free ?? 0 },
    ];
  }, [data]);

  if (loading) {
    return <Spin size="large" />;
  }

  if (!data) {
    return <Typography.Text>تعذر جلب البيانات.</Typography.Text>;
  }

  return (
    <div className="page-wrap">
      <AuroraBackground />
      <Typography.Title level={3}>نظرة عامة شاملة</Typography.Title>
      <Typography.Paragraph type="secondary">
        عرض تنفيذي سريع لكل النظام: المرضى، المواعيد، المحادثات، والإشعارات.
      </Typography.Paragraph>

      <Row gutter={[16, 16]}>
        <Col xs={24} md={12} xl={6}>
          <KpiCard title="إجمالي المرضى" value={data.overview.total_patients} />
        </Col>
        <Col xs={24} md={12} xl={6}>
          <KpiCard title="إجمالي الأطباء" value={data.overview.total_doctors} />
        </Col>
        <Col xs={24} md={12} xl={6}>
          <KpiCard title="إجمالي المواعيد" value={data.overview.total_appointments} />
        </Col>
        <Col xs={24} md={12} xl={6}>
          <KpiCard title="المواعيد القادمة" value={data.overview.upcoming_appointments} />
        </Col>
        <Col xs={24} md={12} xl={6}>
          <KpiCard title="مرضى جدد اليوم" value={data.today.new_patients} />
        </Col>
        <Col xs={24} md={12} xl={6}>
          <KpiCard title="مواعيد اليوم" value={data.today.appointments} />
        </Col>
        <Col xs={24} md={12} xl={6}>
          <KpiCard title="رسائل اليوم" value={data.today.chat_messages} />
        </Col>
        <Col xs={24} md={12} xl={6}>
          <KpiCard title="أجهزة نشطة" value={data.notifications.active_devices} />
        </Col>
      </Row>

      <Row gutter={[16, 16]} style={{ marginTop: 8 }}>
        <Col xs={24} xl={10}>
          <Card title="توزيع حالة المواعيد" className="glass-card">
            <div style={{ height: 300 }}>
              <ResponsiveContainer width="100%" height="100%">
                <PieChart>
                  <Pie data={pieData} dataKey="value" nameKey="name" outerRadius={95} />
                  <Tooltip />
                </PieChart>
              </ResponsiveContainer>
            </div>
          </Card>
        </Col>
        <Col xs={24} xl={14}>
          <Card title="أنواع المرضى والمعاينات" className="glass-card">
            <div style={{ height: 300 }}>
              <ResponsiveContainer width="100%" height="100%">
                <BarChart data={patientTypeBars}>
                  <CartesianGrid strokeDasharray="3 3" />
                  <XAxis dataKey="name" />
                  <YAxis />
                  <Tooltip />
                  <Bar dataKey="value" fill="#00A79D" radius={[6, 6, 0, 0]} />
                </BarChart>
              </ResponsiveContainer>
            </div>
          </Card>
        </Col>
      </Row>

      <Card className="glass-card" title="الأطباء الأكثر نشاطًا" style={{ marginTop: 8 }}>
        <Row gutter={[16, 16]}>
          {topDoctors.map((doctor) => (
            <Col xs={24} sm={12} xl={6} key={doctor.doctor_id}>
              <Doctor3DCard
                doctor={doctor}
                stats={{
                  patients: doctor.total_patients,
                  appointments: doctor.total_appointments,
                  completed: doctor.completed_appointments,
                }}
                onOpen={() => navigate(`/doctor-details?doctorId=${doctor.doctor_id}`)}
              />
            </Col>
          ))}
        </Row>
      </Card>
    </div>
  );
}
