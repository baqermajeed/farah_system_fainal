import { Button, Card, Col, DatePicker, Modal, Row, Select, Spin, Switch, Table, Tag, Tooltip, Typography, message } from 'antd';
import type { Dayjs } from 'dayjs';
import dayjs from 'dayjs';
import { useEffect, useMemo, useState } from 'react';
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
  fetchDoctorAppointmentsBreakdown,
  fetchDoctorDetailsCards,
  fetchDoctorsStats,
  setDoctorManager,
} from '../services/statsApi';
import type { DoctorAppointmentsBreakdownResponse, DoctorDetailsCardsResponse } from '../types/stats';
import { useAuth } from '../state/AuthContext';

const IMPLANT_STAGES = [
  'مرحلة زراعة الاسنان',
  'مرحلة رفع خيط العملية',
  'متابعة حالة المريض',
  'المتابعة الثانية لحالة المريض',
  'التقاط طبعة الاسنان',
  'التركيب التجريبي الاول',
  'التركيب التجريبي الثاني',
  'التركيب النهائي الاخير',
];

export function DoctorDetailsPage() {
  const [searchParams] = useSearchParams();
  const { role } = useAuth();
  const [loading, setLoading] = useState(true);
  const [cardsRefreshing, setCardsRefreshing] = useState(false);
  const [updatingManager, setUpdatingManager] = useState(false);
  const [doctorId, setDoctorId] = useState<string | undefined>(() => searchParams.get('doctorId') ?? undefined);
  const [dates, setDates] = useState<[Dayjs | null, Dayjs | null]>([dayjs().startOf('month'), dayjs()]);
  const [rangeModalOpen, setRangeModalOpen] = useState(false);
  const [draftRange, setDraftRange] = useState<[Dayjs | null, Dayjs | null]>([dayjs().startOf('month'), dayjs()]);
  const [implantDay, setImplantDay] = useState<Dayjs>(dayjs());
  const [implantStage, setImplantStage] = useState<string>(IMPLANT_STAGES[0]);
  const [implantLoading, setImplantLoading] = useState(false);

  const [cardsData, setCardsData] = useState<DoctorDetailsCardsResponse | null>(null);
  const [implantAppointments, setImplantAppointments] = useState<DoctorAppointmentsBreakdownResponse | null>(null);
  const isManagerDoctor = Boolean(cardsData?.doctor.is_manager);

  useEffect(() => {
    const loadDoctors = async () => {
      if (doctorId) return;
      try {
        const response = await fetchDoctorsStats();
        if (response.doctors.length > 0) {
          setDoctorId(response.doctors[0].doctor_id);
        }
      } catch (error) {
        console.error('Failed to load doctors list for profile page', error);
      }
    };
    void loadDoctors();
  }, [doctorId]);

  useEffect(() => {
    let isCancelled = false;
    const loadDoctorData = async () => {
      if (!doctorId) return;
      try {
        const isInitialLoad = cardsData === null;
        if (isInitialLoad) {
          setLoading(true);
        } else {
          setCardsRefreshing(true);
        }
        const date_from = dates[0]?.toISOString();
        const date_to = dates[1]?.endOf('day').toISOString();
        const cardsResp = await fetchDoctorDetailsCards(doctorId, { date_from, date_to });

        if (isCancelled) return;

        setCardsData(cardsResp);
      } catch (error) {
        if (isCancelled) return;
        console.error('Failed to load doctor profile data', error);
      } finally {
        if (isCancelled) return;
        setLoading(false);
        setCardsRefreshing(false);
      }
    };
    void loadDoctorData();
    return () => {
      isCancelled = true;
    };
  }, [doctorId, dates]);

  useEffect(() => {
    let isCancelled = false;
    const loadImplantAppointments = async () => {
      if (!doctorId || !isManagerDoctor) {
        setImplantAppointments(null);
        return;
      }
      try {
        setImplantLoading(true);
        const date_from = implantDay.startOf('day').toISOString();
        const date_to = implantDay.endOf('day').toISOString();
        const response = await fetchDoctorAppointmentsBreakdown(doctorId, {
          group: 'day',
          date_from,
          date_to,
          stage_name: implantStage,
        });
        if (isCancelled) return;
        setImplantAppointments(response);
      } catch (error) {
        if (isCancelled) return;
        console.error('Failed to load implant appointments', error);
      } finally {
        if (isCancelled) return;
        setImplantLoading(false);
      }
    };
    void loadImplantAppointments();
    return () => {
      isCancelled = true;
    };
  }, [doctorId, implantDay, implantStage, isManagerDoctor]);

  const doctorInsights = {
    maleCount: Number(cardsData?.patient_insights.gender.male ?? 0),
    femaleCount: Number(cardsData?.patient_insights.gender.female ?? 0),
    topAgeBucketLabel: cardsData?.patient_insights.age.top_bucket_label ?? 'غير متوفر',
    topAgeBucketCount: Number(cardsData?.patient_insights.age.top_bucket_count ?? 0),
    topTreatment: cardsData?.patient_insights.treatment.top_type ?? 'لا يوجد',
    topTreatmentCount: Number(cardsData?.patient_insights.treatment.top_count ?? 0),
    treatedPatientsCount: Number(cardsData?.patient_insights.treatment.total_linked ?? 0),
    linkedPatientsCount: Number(cardsData?.patient_insights.treatment.total_linked ?? 0),
    periodPatientsCount: Number(cardsData?.metrics.period_patients_count ?? 0),
    activeCount: Number(cardsData?.metrics.active_count ?? 0),
    inactiveCount: Number(cardsData?.metrics.inactive_count ?? 0),
    pendingCount: Number(cardsData?.metrics.pending_count ?? 0),
    transfersToday: Number(cardsData?.metrics.transfers_today ?? 0),
    transfersMonthUnique: Number(cardsData?.metrics.transfers_month_unique ?? 0),
    transfersMonthOps: Number(cardsData?.metrics.transfers_month_ops ?? 0),
  };

  const implantRows = implantAppointments?.selected_list ?? implantAppointments?.today_list ?? [];

  const implantColumns = useMemo(
    () => [
      {
        title: 'اسم المريض',
        dataIndex: 'patient_name',
        render: (value: string | null) => value ?? 'بدون اسم',
      },
      {
        title: 'الهاتف',
        dataIndex: 'patient_phone',
        render: (value: string | null) => value ?? '-',
      },
      {
        title: 'الوقت',
        dataIndex: 'scheduled_at',
        render: (value: string) => dayjs(value).format('HH:mm'),
      },
      {
        title: 'المرحلة',
        dataIndex: 'stage_name',
        render: (value: string | null) => value ?? '-',
      },
    ],
    [],
  );

  const handleManagerToggle = async (checked: boolean) => {
    if (!doctorId || !cardsData) return;
    try {
      setUpdatingManager(true);
      const response = await setDoctorManager(doctorId, checked);
      setCardsData({
        ...cardsData,
        doctor: {
          ...cardsData.doctor,
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

  if (!doctorId || (loading && !cardsData)) return <Spin size="large" />;

  return (
    <div className="page-wrap">
      <motion.div
        initial={{ opacity: 0, y: 14 }}
        animate={{ opacity: 1, y: 0 }}
        transition={{ duration: 0.45 }}
        className="doctor-hero"
      >
        <div className="doctor-hero-content">
          <div className="doctor-hero-media">
            <img
              src={cardsData?.doctor.imageUrl ?? 'https://placehold.co/1000x360?text=Farah+Doctor'}
              alt={cardsData?.doctor.name ?? 'doctor'}
              className="doctor-hero-image"
            />
          </div>
          <div className="doctor-hero-details">
            <Typography.Title level={2} className="doctor-hero-name">
              {cardsData?.doctor.name ?? 'الطبيب'}
            </Typography.Title>
            <Typography.Text className="doctor-hero-phone">
              {cardsData?.doctor.phone ?? '-'}
            </Typography.Text>
            <Typography.Text className="doctor-hero-role">
              نوع الطبيب: {cardsData?.doctor.is_manager ? 'طبيب مدير' : 'طبيب'}
            </Typography.Text>
            <div>
              {cardsData?.doctor.is_manager ? <Tag color="gold">طبيب مدير</Tag> : <Tag color="blue">طبيب</Tag>}
            </div>
          </div>
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
            checked={Boolean(cardsData?.doctor.is_manager)}
            loading={updatingManager}
            disabled={role !== 'admin'}
            onChange={handleManagerToggle}
          />
        </div>
      </Card>

      <Row gutter={[12, 12]} className="stats-tiles-grid" align="stretch">
        <Col xs={24} md={12} xl={6}>
          <StatContainer
            title="إجمالي المرضى"
            value={cardsData?.counts.total_patients ?? 0}
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
        <Col xs={24} xl={12} style={{ display: 'flex' }}>
          <GroupedStatContainer
            title="حالة المرضى"
            icon={<TeamOutlined />}
            tone="info"
            actionIcon={<CalendarOutlined />}
            actionTooltip="تحديد الفترة الزمنية"
            onActionClick={() => {
              setDraftRange(dates);
              setRangeModalOpen(true);
            }}
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
        <Col xs={24} xl={12} style={{ display: 'flex' }}>
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
            subValue={
              `${doctorInsights.topTreatmentCount} من أصل ${doctorInsights.treatedPatientsCount} (المرتبطون: ${doctorInsights.linkedPatientsCount})`
            }
            icon={<CheckCircleOutlined />}
            tone="success"
          />
        </Col>
      </Row>

      {cardsRefreshing ? (
        <div style={{ display: 'flex', justifyContent: 'center', marginTop: 6 }}>
          <Spin size="small" />
        </div>
      ) : null}

      {isManagerDoctor ? (
        <Card className="glass-card" style={{ marginTop: 12 }} title="مواعيد مرضى الزراعة حسب المرحلة">
          <Row gutter={[12, 12]} style={{ marginBottom: 12 }}>
            <Col xs={24} md={8}>
              <DatePicker
                value={implantDay}
                onChange={(value) => setImplantDay(value ?? dayjs())}
                style={{ width: '100%' }}
              />
            </Col>
            <Col xs={24} md={16}>
              <Select
                value={implantStage}
                onChange={setImplantStage}
                options={IMPLANT_STAGES.map((stage) => ({ value: stage, label: stage }))}
                style={{ width: '100%' }}
              />
            </Col>
          </Row>

          <Table
            rowKey="id"
            loading={implantLoading}
            dataSource={implantRows}
            columns={implantColumns}
            pagination={false}
            locale={{ emptyText: 'لا توجد مواعيد لهذه المرحلة في هذا اليوم' }}
          />
        </Card>
      ) : null}

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
      style={{ width: '100%', height: '100%' }}
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
  actionIcon?: React.ReactNode;
  actionTooltip?: string;
  onActionClick?: () => void;
};

function GroupedStatContainer({
  title,
  icon,
  tone,
  items,
  actionIcon,
  actionTooltip,
  onActionClick,
}: GroupedStatContainerProps) {
  return (
    <motion.div
      whileHover={{ y: -5, rotateX: 2 }}
      transition={{ type: 'spring', stiffness: 200, damping: 15 }}
      className={`stat-container stat-${tone}`}
    >
      <div className="stat-group-header">
        <div style={{ display: 'inline-flex', alignItems: 'center', gap: 10 }}>
          <div className="stat-icon-wrap">{icon}</div>
          <Typography.Text className="stat-title">{title}</Typography.Text>
        </div>
        {actionIcon && onActionClick ? (
          <Tooltip title={actionTooltip ?? ''}>
            <Button type="text" className="stat-action-btn" icon={actionIcon} onClick={onActionClick} />
          </Tooltip>
        ) : null}
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
