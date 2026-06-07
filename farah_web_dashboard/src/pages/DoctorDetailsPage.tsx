import { Button, Card, Col, DatePicker, Modal, Row, Spin, Switch, Tag, Tooltip, Typography, message } from 'antd';
import type { Dayjs } from 'dayjs';
import dayjs from 'dayjs';
import { useEffect, useState } from 'react';
import {
  CalendarOutlined,
  CheckCircleOutlined,
  ClockCircleOutlined,
  ManOutlined,
  TeamOutlined,
  UserOutlined,
  WomanOutlined,
} from '@ant-design/icons';
import { useSearchParams } from 'react-router-dom';
import { motion } from 'framer-motion';
import {
  fetchAdminDoctorPatients,
  fetchDoctorPatientsBreakdown,
  fetchDoctorPatientTransfers,
  fetchDoctorProfile,
  fetchDoctorsStats,
  setDoctorManager,
} from '../services/statsApi';
import type {
  DoctorPatientListItem,
  DoctorPatientsBreakdownResponse,
  DoctorPatientTransfersResponse,
  DoctorProfileResponse,
} from '../types/stats';
import { useAuth } from '../state/AuthContext';

export function DoctorDetailsPage() {
  const [searchParams] = useSearchParams();
  const { role } = useAuth();
  const [loading, setLoading] = useState(true);
  const [updatingManager, setUpdatingManager] = useState(false);
  const [doctorId, setDoctorId] = useState<string | undefined>(() => searchParams.get('doctorId') ?? undefined);
  const [dates, setDates] = useState<[Dayjs | null, Dayjs | null]>([dayjs().startOf('month'), dayjs()]);
  const [rangeModalOpen, setRangeModalOpen] = useState(false);
  const [draftRange, setDraftRange] = useState<[Dayjs | null, Dayjs | null]>([dayjs().startOf('month'), dayjs()]);

  const [profile, setProfile] = useState<DoctorProfileResponse | null>(null);
  const [transferStats, setTransferStats] = useState<DoctorPatientTransfersResponse | null>(null);
  const [patientsBreakdown, setPatientsBreakdown] = useState<DoctorPatientsBreakdownResponse | null>(null);
  const [doctorPatients, setDoctorPatients] = useState<DoctorPatientListItem[]>([]);
  const [allLinkedPatients, setAllLinkedPatients] = useState<DoctorPatientListItem[]>([]);

  const loadAllDoctorPatients = async (targetDoctorId: string): Promise<DoctorPatientListItem[]> => {
    const pageSize = 100;
    const all: DoctorPatientListItem[] = [];
    for (let skip = 0; skip < 10000; skip += pageSize) {
      const batch = await fetchAdminDoctorPatients(targetDoctorId, {
        skip,
        limit: pageSize,
      }).catch(() => [] as DoctorPatientListItem[]);
      if (!batch.length) break;
      all.push(...batch);
      if (batch.length < pageSize) break;
    }
    return all;
  };

  useEffect(() => {
    const loadDoctors = async () => {
      try {
        const response = await fetchDoctorsStats();
        if (!doctorId && response.doctors.length > 0) {
          setDoctorId(response.doctors[0].doctor_id);
        }
      } catch (error) {
        console.error('Failed to load doctors list for profile page', error);
      }
    };
    void loadDoctors();
  }, [doctorId]);

  useEffect(() => {
    const loadLinkedPatients = async () => {
      if (!doctorId) return;
      const all = await loadAllDoctorPatients(doctorId);
      setAllLinkedPatients(all);
      setDoctorPatients(all);
    };
    void loadLinkedPatients();
  }, [doctorId]);

  useEffect(() => {
    const loadDoctorData = async () => {
      if (!doctorId) return;
      try {
        setLoading(true);
        const date_from = dates[0]?.toISOString();
        const date_to = dates[1]?.endOf('day').toISOString();
        const [profileResp, transferResp, patientsBreakdownResp] = await Promise.all([
          fetchDoctorProfile(doctorId, { date_from, date_to }),
          fetchDoctorPatientTransfers(doctorId, { date_from, date_to }),
          fetchDoctorPatientsBreakdown(doctorId, {
            date_from,
            date_to,
            group: 'day',
          }),
        ]);

        setProfile(profileResp);
        setTransferStats(transferResp);
        setPatientsBreakdown(patientsBreakdownResp);
      } catch (error) {
        console.error('Failed to load doctor profile data', error);
      } finally {
        setLoading(false);
      }
    };
    void loadDoctorData();
  }, [doctorId, dates]);

  const normalizeGender = (raw?: string | null): 'male' | 'female' | 'unknown' => {
    const value = (raw ?? '').trim().toLowerCase();
    if (!value) return 'unknown';
    if (['male', 'm', 'man', 'ذكر', 'رجل'].includes(value)) return 'male';
    if (['female', 'f', 'woman', 'انثى', 'أنثى', 'بنت', 'امرأة', 'امراة'].includes(value)) return 'female';
    return 'unknown';
  };

  const currentGender = patientsBreakdown?.patients.current.gender ?? {};
  const rangeGender = patientsBreakdown?.patients.range.gender ?? {};

  const maleFromBreakdownCurrent = Number(currentGender.male ?? 0);
  const femaleFromBreakdownCurrent = Number(currentGender.female ?? 0);

  const maleFromBreakdownRange = Number(rangeGender.male ?? 0);
  const femaleFromBreakdownRange = Number(rangeGender.female ?? 0);

  const maleFromList = doctorPatients.filter((patient) => normalizeGender(patient.gender) === 'male').length;
  const femaleFromList = doctorPatients.filter((patient) => normalizeGender(patient.gender) === 'female').length;

  const hasCurrentBreakdown =
    maleFromBreakdownCurrent > 0 || femaleFromBreakdownCurrent > 0;
  const hasRangeBreakdown = maleFromBreakdownRange > 0 || femaleFromBreakdownRange > 0;

  // لعرض "الفترة الحالية" بشكل متسق: range breakdown أولاً، ثم current، ثم fallback.
  const maleCount = hasRangeBreakdown
    ? maleFromBreakdownRange
    : hasCurrentBreakdown
      ? maleFromBreakdownCurrent
      : maleFromList;
  const femaleCount = hasRangeBreakdown
    ? femaleFromBreakdownRange
    : hasCurrentBreakdown
      ? femaleFromBreakdownCurrent
      : femaleFromList;

  const ageBuckets = [
    { label: '0-19', min: 0, max: 19, count: 0 },
    { label: '20-29', min: 20, max: 29, count: 0 },
    { label: '30-39', min: 30, max: 39, count: 0 },
    { label: '40-50', min: 40, max: 50, count: 0 },
    { label: '51-60', min: 51, max: 60, count: 0 },
    { label: '60+', min: 61, max: 200, count: 0 },
  ];
  for (const patient of doctorPatients) {
    const age = patient.age;
    if (age == null) continue;
    const bucket = ageBuckets.find((item) => age >= item.min && age <= item.max);
    if (bucket) bucket.count += 1;
  }
  const maxAgeBucket = [...ageBuckets].sort((a, b) => b.count - a.count)[0];

  const treatmentCount: Record<string, number> = {};
  const resolveDoctorTreatmentType = (patient: DoctorPatientListItem): string => {
    if (!doctorId) return (patient.treatment_type ?? '').trim();
    const profile = patient.doctor_profiles?.[doctorId];
    const profileTreatment = (profile?.treatment_type ?? '').trim();
    if (profileTreatment) return profileTreatment;
    return (patient.treatment_type ?? '').trim();
  };
  for (const patient of allLinkedPatients) {
    const treatment = resolveDoctorTreatmentType(patient);
    if (!treatment || treatment === 'غير محدد') continue;
    treatmentCount[treatment] = (treatmentCount[treatment] ?? 0) + 1;
  }
  const topTreatmentEntry =
    Object.entries(treatmentCount).sort((a, b) => b[1] - a[1])[0] ?? (['لا يوجد', 0] as [string, number]);
  const treatedPatientsCount = Object.values(treatmentCount).reduce((sum, value) => sum + value, 0);

  const doctorInsights = {
    maleCount,
    femaleCount,
    topAgeBucketLabel: maxAgeBucket?.label ?? 'غير متوفر',
    topAgeBucketCount: maxAgeBucket?.count ?? 0,
    topTreatment: topTreatmentEntry[0],
    topTreatmentCount: topTreatmentEntry[1],
    treatedPatientsCount,
    linkedPatientsCount: allLinkedPatients.length,
    periodPatientsCount: patientsBreakdown?.patients.range.total ?? doctorPatients.length,
    activeCount: transferStats?.active_patients.range.count ?? 0,
    inactiveCount: transferStats?.inactive_patients.range.count ?? 0,
    pendingCount: transferStats?.pending_patients.range.count ?? 0,
    transfersToday: transferStats?.transfers.today ?? 0,
    transfersMonthUnique: patientsBreakdown?.patients.this_month.total ?? patientsBreakdown?.patients.range.total ?? 0,
    transfersMonthOps: transferStats?.transfers.this_month ?? 0,
  };

  const handleManagerToggle = async (checked: boolean) => {
    if (!doctorId || !profile) return;
    try {
      setUpdatingManager(true);
      const response = await setDoctorManager(doctorId, checked);
      setProfile({
        ...profile,
        doctor: {
          ...profile.doctor,
          is_manager: response.is_manager,
        },
      });
      message.success(response.is_manager ? 'تم تفعيل صلاحية الطبيب المدير' : 'تم إلغاء صلاحية الطبيب المدير');
    } catch {
      message.error('تعذر تحديث حالة الطبيب المدير');
    } finally {
      setUpdatingManager(false);
    }
  };

  const applyRangeSelection = () => {
    setDates(draftRange);
    setRangeModalOpen(false);
  };

  if (!doctorId || loading) return <Spin size="large" />;

  return (
    <div className="page-wrap">
      <motion.div
        initial={{ opacity: 0, y: 14 }}
        animate={{ opacity: 1, y: 0 }}
        transition={{ duration: 0.45 }}
        className="doctor-hero"
      >
        <img
          src={profile?.doctor.imageUrl ?? 'https://placehold.co/1000x360?text=Farah+Doctor'}
          alt={profile?.doctor.name ?? 'doctor'}
          className="doctor-hero-image"
        />
        <div className="doctor-hero-overlay">
          <div>
            <Typography.Title level={2} style={{ margin: 0, color: 'white' }}>
              {profile?.doctor.name ?? 'الطبيب'}
            </Typography.Title>
            <Typography.Text style={{ color: 'rgba(255,255,255,.85)' }}>
              {profile?.doctor.phone ?? '-'}
            </Typography.Text>
          </div>
          {profile?.doctor.is_manager ? <Tag color="gold">طبيب مدير</Tag> : <Tag color="blue">طبيب</Tag>}
        </div>
      </motion.div>

      <Card className="glass-card stats-panel" style={{ marginBottom: 12 }}>
        <div className="manager-toggle-card">
          <div className="manager-toggle-copy">
            <TeamOutlined className="manager-toggle-icon" />
            <div>
              <Typography.Text className="manager-toggle-title">طبيب مدير</Typography.Text>
              <Typography.Paragraph className="manager-toggle-subtitle">
                تفعيل صلاحية تحويل وإدارة المرضى لهذا الطبيب
              </Typography.Paragraph>
            </div>
          </div>
          <Switch
            checked={Boolean(profile?.doctor.is_manager)}
            loading={updatingManager}
            disabled={role !== 'admin'}
            onChange={handleManagerToggle}
          />
        </div>
      </Card>

      <Row gutter={[12, 12]} className="stats-tiles-grid">
        <Col xs={24} md={12} xl={6}>
          <StatContainer
            title="إجمالي المرضى"
            value={profile?.counts.total_patients ?? 0}
            icon={<UserOutlined />}
            tone="primary"
          />
        </Col>
        <Col xs={24} md={12} xl={6}>
          <StatContainer
            title="مرضى محولين هذا الشهر"
            value={doctorInsights.transfersMonthUnique}
            subValue={`عمليات التحويل: ${doctorInsights.transfersMonthOps}`}
            icon={<CheckCircleOutlined />}
            tone="info"
          />
        </Col>
        <Col xs={24} md={12} xl={6}>
          <StatContainer
            title="تحويلات اليوم"
            value={doctorInsights.transfersToday}
            icon={<ClockCircleOutlined />}
            tone="warning"
          />
        </Col>
        <Col xs={24} md={12} xl={6}>
          <StatContainer
            title="مرضى الفترة المحددة"
            value={doctorInsights.periodPatientsCount}
            subValue={
              dates[0] && dates[1]
                ? `من ${dates[0].format('YYYY-MM-DD')} إلى ${dates[1].format('YYYY-MM-DD')}`
                : undefined
            }
            icon={<TeamOutlined />}
            tone="secondary"
            actionIcon={<CalendarOutlined />}
            actionTooltip="تحديد الفترة الزمنية"
            onActionClick={() => {
              setDraftRange(dates);
              setRangeModalOpen(true);
            }}
          />
        </Col>
        <Col xs={24} xl={12}>
          <GroupedStatContainer
            title="حالة المرضى"
            icon={<TeamOutlined />}
            tone="info"
            items={[
              {
                label: 'مرضى نشطين',
                value: doctorInsights.activeCount,
                icon: <CheckCircleOutlined />,
                tone: 'success',
              },
              {
                label: 'مرضى غير نشطين',
                value: doctorInsights.inactiveCount,
                icon: <ClockCircleOutlined />,
                tone: 'danger',
              },
              {
                label: 'مرضى قيد الانتظار',
                value: doctorInsights.pendingCount,
                icon: <ClockCircleOutlined />,
                tone: 'warning',
              },
            ]}
          />
        </Col>
        <Col xs={24} xl={12}>
          <GroupedStatContainer
            title="توزيع الجنس"
            icon={<TeamOutlined />}
            tone="secondary"
            items={[
              {
                label: 'عدد الإناث',
                value: doctorInsights.femaleCount,
                icon: <WomanOutlined />,
                tone: 'secondary',
              },
              {
                label: 'عدد الذكور',
                value: doctorInsights.maleCount,
                icon: <ManOutlined />,
                tone: 'primary',
              },
            ]}
          />
        </Col>
        <Col xs={24} md={12} xl={6}>
          <StatContainer
            title="أعلى فئة عمرية"
            value={doctorInsights.topAgeBucketLabel}
            subValue={`${doctorInsights.topAgeBucketCount} مريض`}
            icon={<TeamOutlined />}
            tone="info"
          />
        </Col>
        <Col xs={24} md={12} xl={6}>
          <StatContainer
            title="أكثر نوع علاج"
            value={doctorInsights.topTreatment}
            subValue={`${doctorInsights.topTreatmentCount} من أصل ${doctorInsights.treatedPatientsCount} (المرتبطون: ${doctorInsights.linkedPatientsCount})`}
            icon={<CheckCircleOutlined />}
            tone="success"
          />
        </Col>
      </Row>

      <Modal
        title="اختيار فترة زمنية"
        open={rangeModalOpen}
        onCancel={() => setRangeModalOpen(false)}
        onOk={applyRangeSelection}
        okText="تطبيق"
        cancelText="إلغاء"
      >
        <DatePicker.RangePicker
          value={draftRange}
          onChange={(value) => setDraftRange([value?.[0] ?? null, value?.[1] ?? null])}
          style={{ width: '100%' }}
          allowEmpty={[false, false]}
        />
      </Modal>
    </div>
  );
}

type StatContainerProps = {
  title: string;
  value: string | number;
  subValue?: string;
  icon: React.ReactNode;
  tone: 'primary' | 'success' | 'warning' | 'danger' | 'secondary' | 'info';
  actionIcon?: React.ReactNode;
  actionTooltip?: string;
  onActionClick?: () => void;
};

function StatContainer({
  title,
  value,
  subValue,
  icon,
  tone,
  actionIcon,
  actionTooltip,
  onActionClick,
}: StatContainerProps) {
  return (
    <motion.div
      whileHover={{ y: -5, rotateX: 2 }}
      transition={{ type: 'spring', stiffness: 200, damping: 15 }}
      className={`stat-container stat-${tone}`}
    >
      <div className="stat-head-row">
        <div className="stat-icon-wrap">{icon}</div>
        {actionIcon && onActionClick ? (
          <Tooltip title={actionTooltip ?? ''}>
            <Button type="text" className="stat-action-btn" icon={actionIcon} onClick={onActionClick} />
          </Tooltip>
        ) : null}
      </div>
      <Typography.Text className="stat-title">{title}</Typography.Text>
      <Typography.Title level={2} className="stat-value">
        {value}
      </Typography.Title>
      {subValue ? <Typography.Text className="stat-subvalue">{subValue}</Typography.Text> : null}
    </motion.div>
  );
}

type GroupedStatItem = {
  label: string;
  value: number | string;
  icon: React.ReactNode;
  tone: 'primary' | 'success' | 'warning' | 'danger' | 'secondary' | 'info';
};

type GroupedStatContainerProps = {
  title: string;
  icon: React.ReactNode;
  tone: 'primary' | 'success' | 'warning' | 'danger' | 'secondary' | 'info';
  items: GroupedStatItem[];
};

function GroupedStatContainer({ title, icon, tone, items }: GroupedStatContainerProps) {
  return (
    <motion.div
      whileHover={{ y: -5, rotateX: 2 }}
      transition={{ type: 'spring', stiffness: 200, damping: 15 }}
      className={`stat-container stat-${tone}`}
    >
      <div className="stat-group-header">
        <div className="stat-icon-wrap">{icon}</div>
        <Typography.Text className="stat-title">{title}</Typography.Text>
      </div>
      <div className="stat-group-items">
        {items.map((item) => (
          <div className="stat-group-item" key={item.label}>
            <div className="stat-group-item-label">
              <span className={`stat-group-dot stat-${item.tone}`} />
              {item.icon}
              <Typography.Text>{item.label}</Typography.Text>
            </div>
            <Typography.Title level={3} className="stat-group-value">
              {item.value}
            </Typography.Title>
          </div>
        ))}
      </div>
    </motion.div>
  );
}
