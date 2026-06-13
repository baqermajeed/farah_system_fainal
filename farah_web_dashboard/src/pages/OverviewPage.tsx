import { Card, Col, DatePicker, Modal, Row, Spin, Typography } from 'antd';
import type { Dayjs } from 'dayjs';
import dayjs from 'dayjs';
import { useEffect, useState } from 'react';
import { useNavigate } from 'react-router-dom';
import { CalendarOutlined } from '@ant-design/icons';
import { KpiCard } from '../components/KpiCard';
import { AuroraBackground } from '../components/AuroraBackground';
import { Doctor3DCard } from '../components/Doctor3DCard';
import { fetchDashboardStats, fetchDoctorsStats, fetchOverviewStats } from '../services/statsApi';
import type { DashboardStats, DoctorStatsListResponse } from '../types/stats';

export function OverviewPage() {
  const [loading, setLoading] = useState(true);
  const [data, setData] = useState<DashboardStats | null>(null);
  const [topDoctors, setTopDoctors] = useState<DoctorStatsListResponse['doctors']>([]);
  const [periodRange, setPeriodRange] = useState<[Dayjs | null, Dayjs | null]>([dayjs().startOf('month'), dayjs()]);
  const [periodRangeModalOpen, setPeriodRangeModalOpen] = useState(false);
  const [draftPeriodRange, setDraftPeriodRange] = useState<[Dayjs | null, Dayjs | null]>([
    dayjs().startOf('month'),
    dayjs(),
  ]);
  const [rangeNewPatients, setRangeNewPatients] = useState(0);
  const [rangeLoading, setRangeLoading] = useState(false);
  const navigate = useNavigate();

  useEffect(() => {
    let isCancelled = false;
    const loadRangeNewPatients = async () => {
      const date_from = periodRange[0]?.toISOString();
      const date_to = periodRange[1]?.endOf('day').toISOString();
      if (!date_from || !date_to) {
        setRangeNewPatients(0);
        return;
      }
      try {
        setRangeLoading(true);
        const overview = await fetchOverviewStats({ group: 'day', date_from, date_to });
        if (isCancelled) return;
        const total = overview.new_patients.reduce((sum, item) => sum + Number(item.count ?? 0), 0);
        setRangeNewPatients(total);
      } catch (error) {
        if (isCancelled) return;
        console.error('Failed to load range new patients', error);
        setRangeNewPatients(0);
      } finally {
        if (isCancelled) return;
        setRangeLoading(false);
      }
    };
    void loadRangeNewPatients();
    return () => {
      isCancelled = true;
    };
  }, [periodRange]);

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

  if (loading) {
    return <Spin size="large" />;
  }

  if (!data) {
    return <Typography.Text>تعذر جلب البيانات.</Typography.Text>;
  }

  const applyPeriodRangeSelection = () => {
    setPeriodRange(draftPeriodRange);
    setPeriodRangeModalOpen(false);
  };

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
          <KpiCard title="مرضى جدد اليوم" value={data.today.new_patients} />
        </Col>
        <Col xs={24} md={12} xl={6}>
          <KpiCard title="كل المرضى الجدد" value={data.patient_types.all.visit_type.new ?? 0} />
        </Col>
        <Col xs={24} md={12} xl={6}>
          <KpiCard title="المرضى الجدد هذا الشهر" value={data.this_month.new_patients} />
        </Col>
        <Col xs={24} md={12} xl={6}>
          <KpiCard
            title="مرضى جدد حسب فترة معينة"
            value={rangeLoading ? '...' : rangeNewPatients}
            actionIcon={<CalendarOutlined />}
            actionTooltip="تحديد الفترة الزمنية"
            onActionClick={() => {
              setDraftPeriodRange(periodRange);
              setPeriodRangeModalOpen(true);
            }}
          />
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

      <Modal
        title="اختيار فترة زمنية"
        open={periodRangeModalOpen}
        onCancel={() => setPeriodRangeModalOpen(false)}
        onOk={applyPeriodRangeSelection}
        okText="تطبيق"
        cancelText="إلغاء"
      >
        <DatePicker.RangePicker
          value={draftPeriodRange}
          onChange={(value) => setDraftPeriodRange([value?.[0] ?? null, value?.[1] ?? null])}
          style={{ width: '100%' }}
          allowEmpty={[false, false]}
        />
      </Modal>
    </div>
  );
}
