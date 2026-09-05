import {
  CalendarOutlined,
  CheckCircleOutlined,
  ClockCircleOutlined,
  DeleteOutlined,
  EditOutlined,
  EnvironmentOutlined,
  FieldTimeOutlined,
  MoreOutlined,
  PhoneOutlined,
  PlusOutlined,
  SearchOutlined,
  UnorderedListOutlined,
} from '@ant-design/icons';
import {
  Button,
  Card,
  Col,
  DatePicker,
  Dropdown,
  Form,
  Grid,
  Input,
  Modal,
  Popconfirm,
  Row,
  Select,
  Space,
  Spin,
  Table,
  Tag,
  Typography,
  message,
} from 'antd';
import type { ColumnsType } from 'antd/es/table';
import type { Dayjs } from 'dayjs';
import dayjs from 'dayjs';
import { useEffect, useMemo, useRef, useState } from 'react';
import { AdaptiveDateRangePicker, AdaptiveDateTimePicker } from '../components/AdaptiveDateInputs';
import { KpiCard } from '../components/KpiCard';
import {
  createCallCenterAppointment,
  deleteCallCenterAppointment,
  fetchCallCenterDoctorAppointmentsFromBoth,
  fetchCallCenterMyAppointmentsFromBoth,
  fetchCallCenterMyAppointmentsPageFromBoth,
  updateCallCenterAppointment,
} from '../services/statsApi';
import type {
  CallCenterAppointmentListItem,
  CallCenterDoctorAppointmentListItem,
  CallCenterAppointmentPayload,
} from '../types/stats';

type BranchKey = 'farah_najaf' | 'kendy_baghdad';
type DateRange = [Dayjs | null, Dayjs | null];
type AppointmentFormValues = {
  patient_name: string;
  patient_phone: string;
  governorate?: string;
  platform?: string;
  note?: string;
  branch?: BranchKey;
  scheduled_at: Dayjs;
};

const IRAQ_GOVERNORATES = [
  'بغداد',
  'البصرة',
  'نينوى',
  'النجف',
  'كربلاء',
  'الأنبار',
  'ديالى',
  'واسط',
  'صلاح الدين',
  'كركوك',
  'بابل',
  'القادسية',
  'ذي قار',
  'ميسان',
  'المثنى',
  'أربيل',
  'السليمانية',
  'دهوك',
];

const BOOKING_PLATFORMS = ['انستكرام', 'واتساب', 'تيك توك', 'فيسبوك', 'اتصال'];

const BRANCH_OPTIONS: Array<{ value: BranchKey; label: string }> = [
  { value: 'farah_najaf', label: 'فرح النجف' },
  { value: 'kendy_baghdad', label: 'الكندي بغداد' },
];

function normalizeDigits(value: string) {
  return (value ?? '')
    .replace(/[٠-٩]/g, (digit) => String('٠١٢٣٤٥٦٧٨٩'.indexOf(digit)))
    .replace(/\D/g, '');
}

function sanitizePhone(value: string) {
  const digits = normalizeDigits(value);
  if (digits.length === 10 && digits.startsWith('7')) {
    return `0${digits}`;
  }
  if (digits.length === 13 && digits.startsWith('964')) {
    return `0${digits.slice(3)}`;
  }
  return digits;
}



function parseDate(value?: string | null) {
  if (!value) return null;
  const dt = new Date(value);
  return Number.isNaN(dt.getTime()) ? null : dt;
}

/** نفس منطق التطبيق: createdAt ?? scheduledAt */
function baseDateOf(item: CallCenterAppointmentListItem) {
  return parseDate(item.created_at) ?? parseDate(item.scheduled_at);
}

/** نفس منطق التطبيق للمقبول: acceptedAt ?? createdAt ?? scheduledAt */
function acceptedDateOf(item: CallCenterAppointmentListItem) {
  return parseDate(item.accepted_at) ?? parseDate(item.created_at) ?? parseDate(item.scheduled_at);
}

function isAcceptedAppointment(item: CallCenterAppointmentListItem) {
  return (item.status ?? '').toLowerCase() === 'accepted';
}

/** مطابق لـ _countToday في frontend_desktop */
function countToday(list: CallCenterAppointmentListItem[]) {
  const now = new Date();
  return list.filter((item) => {
    const dt = baseDateOf(item);
    return !!dt && dt.getFullYear() === now.getFullYear() && dt.getMonth() === now.getMonth() && dt.getDate() === now.getDate();
  }).length;
}

/** مطابق لـ _countThisMonth في frontend_desktop */
function countThisMonth(list: CallCenterAppointmentListItem[]) {
  const now = new Date();
  return list.filter((item) => {
    const dt = baseDateOf(item);
    return !!dt && dt.getFullYear() === now.getFullYear() && dt.getMonth() === now.getMonth();
  }).length;
}

/** مطابق لـ _countInRange في frontend_desktop */
function countInRange(list: CallCenterAppointmentListItem[], start: Date, end: Date) {
  const s = new Date(start.getFullYear(), start.getMonth(), start.getDate(), 0, 0, 0, 0).getTime() - 1000;
  const e = new Date(end.getFullYear(), end.getMonth(), end.getDate(), 23, 59, 59, 0).getTime() + 1000;
  return list.filter((item) => {
    const dt = baseDateOf(item);
    if (!dt) return false;
    const t = dt.getTime();
    return t > s && t < e;
  }).length;
}

/** مطابق لـ _countAcceptedThisMonth في frontend_desktop */
function countAcceptedThisMonth(list: CallCenterAppointmentListItem[]) {
  const now = new Date();
  return list.filter((item) => {
    if (!isAcceptedAppointment(item)) return false;
    const dt = acceptedDateOf(item);
    return !!dt && dt.getFullYear() === now.getFullYear() && dt.getMonth() === now.getMonth();
  }).length;
}

/** مطابق لـ _countAcceptedInRange في frontend_desktop */
function countAcceptedInRange(list: CallCenterAppointmentListItem[], start: Date, end: Date) {
  const s = new Date(start.getFullYear(), start.getMonth(), start.getDate(), 0, 0, 0, 0).getTime() - 1000;
  const e = new Date(end.getFullYear(), end.getMonth(), end.getDate(), 23, 59, 59, 0).getTime() + 1000;
  return list.filter((item) => {
    if (!isAcceptedAppointment(item)) return false;
    const dt = acceptedDateOf(item);
    if (!dt) return false;
    const t = dt.getTime();
    return t > s && t < e;
  }).length;
}

function isWithinInclusiveDayRange(target: Date, start: Date, end: Date) {
  const s = new Date(start.getFullYear(), start.getMonth(), start.getDate(), 0, 0, 0, 0);
  const e = new Date(end.getFullYear(), end.getMonth(), end.getDate(), 23, 59, 59, 999);
  return target.getTime() >= s.getTime() && target.getTime() <= e.getTime();
}

function branchLabel(value: BranchKey | undefined) {
  if (value === 'kendy_baghdad') return 'الكندي بغداد';
  return 'فرح النجف';
}

function statusLabel(value: string) {
  return value?.toLowerCase() === 'accepted' ? 'مقبول' : 'قيد الانتظار';
}

export function CallCenterWorkspacePage() {
  const screens = Grid.useBreakpoint();
  const isMobile = !screens.md;

  const [loading, setLoading] = useState(true);
  const [loadingMore, setLoadingMore] = useState(false);
  const [statsLoading, setStatsLoading] = useState(true);
  const [hasMoreAppointments, setHasMoreAppointments] = useState(true);
  const [appointments, setAppointments] = useState<CallCenterAppointmentListItem[]>([]);
  /** نفس مصدر الإحصائيات في التطبيق: كل المواعيد (من الفرعين) ثم العدّ على الجهاز */
  const [statsList, setStatsList] = useState<CallCenterAppointmentListItem[]>([]);
  const [searchInput, setSearchInput] = useState('');
  const [searchQuery, setSearchQuery] = useState('');
  const [branchSkips, setBranchSkips] = useState({ najaf: 0, kendy: 0 });
  const [tableFilterRange, setTableFilterRange] = useState<DateRange>([null, null]);
  const [statsRange, setStatsRange] = useState<DateRange>([null, null]);
  const [tableRangeModalOpen, setTableRangeModalOpen] = useState(false);
  const [acceptedRange, setAcceptedRange] = useState<DateRange>([null, null]);
  const [acceptedRangeModalOpen, setAcceptedRangeModalOpen] = useState(false);

  const [createModalOpen, setCreateModalOpen] = useState(false);
  const [editModalOpen, setEditModalOpen] = useState(false);
  const [submitting, setSubmitting] = useState(false);
  const [editingAppointment, setEditingAppointment] = useState<CallCenterAppointmentListItem | null>(null);
  const [createForm] = Form.useForm<AppointmentFormValues>();
  const [editForm] = Form.useForm<AppointmentFormValues>();

  const [doctorModalOpen, setDoctorModalOpen] = useState(false);
  const [doctorLoading, setDoctorLoading] = useState(false);
  const [doctorAppointments, setDoctorAppointments] = useState<CallCenterDoctorAppointmentListItem[]>([]);
  const [doctorFilterMode, setDoctorFilterMode] = useState<'today' | 'month' | 'custom'>('today');
  const [doctorRange, setDoctorRange] = useState<DateRange>([dayjs().startOf('day'), dayjs().endOf('day')]);
  
  const [statsModalOpen, setStatsModalOpen] = useState(false);
  const [mobileTimeFilter, setMobileTimeFilter] = useState<'all' | 'today' | 'week' | 'month'>('all');
  const loadMoreRef = useRef<HTMLDivElement | null>(null);

  const popupContainer = (trigger: HTMLElement) => trigger.parentElement ?? document.body;

  useEffect(() => {
    if (!isMobile) {
      document.body.classList.remove('call-center-mobile-active');
      return;
    }
    document.body.classList.add('call-center-mobile-active');
    return () => {
      document.body.classList.remove('call-center-mobile-active');
    };
  }, [isMobile]);

  useEffect(() => {
    const timer = setTimeout(() => {
      setSearchQuery(searchInput.trim());
    }, 300);
    return () => clearTimeout(timer);
  }, [searchInput]);

  const loadAppointments = async (reset = false) => {
    try {
      if (reset) {
        setLoading(true);
      } else {
        setLoadingMore(true);
      }

      const skipState = reset ? { najaf: 0, kendy: 0 } : branchSkips;
      const result = await fetchCallCenterMyAppointmentsPageFromBoth({
        search: searchQuery || undefined,
        najaf_skip: skipState.najaf,
        kendy_skip: skipState.kendy,
        per_branch_limit: isMobile ? 8 : 15,
      });

      setBranchSkips({
        najaf: result.next_najaf_skip,
        kendy: result.next_kendy_skip,
      });
      setHasMoreAppointments(result.has_more);

      setAppointments((prev) => {
        const base = reset ? [] : prev;
        const merged = [...base, ...result.items];
        const map = new Map<string, CallCenterAppointmentListItem>();
        for (const item of merged) {
          map.set(`${item.branch ?? ''}|${item.id}`, item);
        }
        return Array.from(map.values()).sort(
          (a, b) => new Date(b.scheduled_at).getTime() - new Date(a.scheduled_at).getTime(),
        );
      });
    } catch (error) {
      console.error('Failed to load call center appointments', error);
      message.error('تعذر تحميل الحجوزات');
      if (reset) {
        setAppointments([]);
      }
    } finally {
      setLoading(false);
      setLoadingMore(false);
    }
  };

  useEffect(() => {
    setBranchSkips({ najaf: 0, kendy: 0 });
    setHasMoreAppointments(true);
    void loadAppointments(true);
  }, [searchQuery, isMobile]);

  const handleLoadMore = () => {
    if (loadingMore || !hasMoreAppointments || loading) return;
    void loadAppointments(false);
  };

  useEffect(() => {
    const node = loadMoreRef.current;
    if (!node) return;

    const observer = new IntersectionObserver(
      (entries) => {
        const entry = entries[0];
        if (!entry?.isIntersecting) return;
        handleLoadMore();
      },
      {
        root: null,
        rootMargin: '240px 0px',
        threshold: 0,
      },
    );

    observer.observe(node);
    return () => observer.disconnect();
  }, [hasMoreAppointments, loadingMore, loading, appointments.length, searchQuery, isMobile]);

  const loadStats = async () => {
    try {
      setStatsLoading(true);
      // مثل getAppointmentsFromBoth في التطبيق: نجيب كل الصفحات من الفرعين ثم نعدّ محلياً
      const data = await fetchCallCenterMyAppointmentsFromBoth({
        search: searchQuery || undefined,
      });
      setStatsList(data);
    } catch (error) {
      console.error('Failed to load call center stats list', error);
      message.error('تعذر تحميل الإحصائيات');
      setStatsList([]);
    } finally {
      setStatsLoading(false);
    }
  };

  useEffect(() => {
    void loadStats();
  }, [searchQuery]);

  // نفس _buildStatsPanel في frontend_desktop/call_center_home_screen.dart
  const stats = useMemo(() => {
    const rangeCount =
      statsRange[0] && statsRange[1]
        ? countInRange(statsList, statsRange[0].toDate(), statsRange[1].toDate())
        : 0;
    const acceptedThisMonth = countAcceptedThisMonth(statsList);
    const acceptedInRange =
      acceptedRange[0] && acceptedRange[1]
        ? countAcceptedInRange(statsList, acceptedRange[0].toDate(), acceptedRange[1].toDate())
        : null;

    return {
      total: statsList.length,
      today: countToday(statsList),
      thisMonth: countThisMonth(statsList),
      rangeCount,
      acceptedThisMonth,
      acceptedInRange,
    };
  }, [statsList, statsRange, acceptedRange]);

  const rangeLabel =
    statsRange[0] && statsRange[1]
      ? `${statsRange[0].format('YYYY/MM/DD')} → ${statsRange[1].format('YYYY/MM/DD')}`
      : 'اختر فترة';
  const acceptedRangeLabel =
    acceptedRange[0] && acceptedRange[1]
      ? `${acceptedRange[0].format('YYYY/MM/DD')} → ${acceptedRange[1].format('YYYY/MM/DD')}`
      : 'اختر فترة';
  const acceptedValue = stats.acceptedInRange ?? stats.acceptedThisMonth;
  const acceptedSubtitle = acceptedRange[0] && acceptedRange[1] ? acceptedRangeLabel : 'هذا الشهر';
  const rangeModalPreviewCount =
    statsRange[0] && statsRange[1]
      ? countInRange(statsList, statsRange[0].toDate(), statsRange[1].toDate())
      : null;
  const acceptedModalPreviewCount =
    acceptedRange[0] && acceptedRange[1]
      ? countAcceptedInRange(statsList, acceptedRange[0].toDate(), acceptedRange[1].toDate())
      : null;
  const tableFilteredAppointments = useMemo(() => {
    const from = tableFilterRange[0]?.toDate() ?? null;
    const to = tableFilterRange[1]?.toDate() ?? null;

    let filtered = appointments;
    if (from && to) {
      filtered = filtered.filter((item) => {
        const baseDate = baseDateOf(item);
        return baseDate ? isWithinInclusiveDayRange(baseDate, from, to) : false;
      });
    }

    if (isMobile && mobileTimeFilter !== 'all') {
      const now = dayjs();
      filtered = filtered.filter((item) => {
        const dt = dayjs(item.scheduled_at);
        if (!dt.isValid()) return false;
        if (mobileTimeFilter === 'today') return dt.isSame(now, 'day');
        if (mobileTimeFilter === 'week') return dt.isSame(now, 'week');
        if (mobileTimeFilter === 'month') return dt.isSame(now, 'month');
        return true;
      });
    }

    return filtered;
  }, [appointments, tableFilterRange, isMobile, mobileTimeFilter]);

  const openEdit = (item: CallCenterAppointmentListItem) => {
    if (item.status?.toLowerCase() === 'accepted') return;
    setEditingAppointment(item);
    editForm.setFieldsValue({
      patient_name: item.patient_name,
      patient_phone: item.patient_phone,
      governorate: item.governorate || undefined,
      platform: item.platform || undefined,
      note: item.note || undefined,
      scheduled_at: dayjs(item.scheduled_at),
      branch: item.branch,
    });
    setEditModalOpen(true);
  };

  const loadDoctorAppointments = async () => {
    try {
      setDoctorLoading(true);
      const params: {
        day?: 'today' | 'month';
        date_from?: string;
        date_to?: string;
      } = {};

      if (doctorFilterMode === 'today') {
        params.day = 'today';
      } else if (doctorFilterMode === 'month') {
        params.day = 'month';
      } else if (doctorRange[0] && doctorRange[1]) {
        params.date_from = doctorRange[0].startOf('day').toISOString();
        params.date_to = doctorRange[1].endOf('day').toISOString();
      }

      const data = await fetchCallCenterDoctorAppointmentsFromBoth(params);
      setDoctorAppointments(data);
    } catch (error) {
      console.error('Failed to load doctor appointments for call center', error);
      message.error('تعذر تحميل مواعيد العيادة');
      setDoctorAppointments([]);
    } finally {
      setDoctorLoading(false);
    }
  };

  useEffect(() => {
    if (!doctorModalOpen) return;
    void loadDoctorAppointments();
  }, [doctorModalOpen, doctorFilterMode, doctorRange]);

  const disabledTime = () => ({
    disabledHours: () => {
      const blocked: number[] = [];
      for (let hour = 0; hour <= 23; hour += 1) {
        if (hour < 8 || hour > 20) {
          blocked.push(hour);
        }
      }
      return blocked;
    },
    disabledMinutes: (hour: number) => (hour >= 8 && hour <= 20 ? Array.from({ length: 60 }, (_, m) => m).filter((m) => m !== 0) : []),
  });

  const validateAndBuildPayload = (values: AppointmentFormValues): CallCenterAppointmentPayload | null => {
    const phone = sanitizePhone(values.patient_phone);
    if (!(phone.length === 11 && phone.startsWith('07'))) {
      message.error('رقم الهاتف يجب أن يكون 11 رقم ويبدأ بـ 07');
      return null;
    }

    const selectedHour = values.scheduled_at.hour();
    if (selectedHour < 8 || selectedHour > 20 || values.scheduled_at.minute() !== 0) {
      message.error('الوقت المسموح من 08:00 إلى 20:00 وبفواصل ساعة كاملة');
      return null;
    }

    return {
      patient_name: values.patient_name.trim(),
      patient_phone: phone,
      scheduled_at: values.scheduled_at.toISOString(),
      governorate: values.governorate ?? '',
      platform: values.platform ?? '',
      note: values.note?.trim() ?? '',
    };
  };

  const submitCreate = async () => {
    try {
      const values = await createForm.validateFields();
      const payload = validateAndBuildPayload(values);
      if (!payload) return;
      if (!values.branch) {
        message.error('اختر الفرع');
        return;
      }

      setSubmitting(true);
      await createCallCenterAppointment(values.branch, payload);
      message.success('تم إنشاء الحجز بنجاح');
      setCreateModalOpen(false);
      createForm.resetFields();
      await Promise.all([loadAppointments(true), loadStats()]);
    } catch (error) {
      if (error instanceof Error) {
        console.error(error);
      }
      if ((error as { errorFields?: unknown })?.errorFields) return;
      message.error('فشل إنشاء الحجز');
    } finally {
      setSubmitting(false);
    }
  };

  const submitEdit = async () => {
    if (!editingAppointment) return;
    if (editingAppointment.status?.toLowerCase() === 'accepted') {
      message.warning('لا يمكن تعديل حجز مقبول');
      return;
    }
    try {
      const values = await editForm.validateFields();
      const payload = validateAndBuildPayload(values);
      if (!payload) return;
      const branch = editingAppointment.branch ?? 'farah_najaf';

      setSubmitting(true);
      await updateCallCenterAppointment(branch, editingAppointment.id, payload);
      message.success('تم تعديل الحجز بنجاح');
      setEditModalOpen(false);
      setEditingAppointment(null);
      await Promise.all([loadAppointments(true), loadStats()]);
    } catch (error) {
      if ((error as { errorFields?: unknown })?.errorFields) return;
      console.error(error);
      message.error('فشل تعديل الحجز');
    } finally {
      setSubmitting(false);
    }
  };

  const handleDelete = async (item: CallCenterAppointmentListItem) => {
    if (item.status?.toLowerCase() === 'accepted') {
      message.warning('لا يمكن حذف حجز مقبول');
      return;
    }
    try {
      const branch = item.branch ?? 'farah_najaf';
      await deleteCallCenterAppointment(branch, item.id);
      message.success('تم حذف الحجز');
      await Promise.all([loadAppointments(true), loadStats()]);
    } catch (error) {
      console.error(error);
      message.error('فشل حذف الحجز');
    }
  };

  const columns: ColumnsType<CallCenterAppointmentListItem> = [
    {
      title: 'المريض',
      dataIndex: 'patient_name',
      render: (value: string) => value || '-',
    },
    {
      title: 'اليوم والوقت',
      dataIndex: 'scheduled_at',
      render: (value: string) => dayjs(value).format('dddd - hh:mm A'),
    },
    {
      title: 'التاريخ',
      dataIndex: 'scheduled_at',
      render: (value: string) => dayjs(value).format('YYYY-MM-DD'),
    },
    {
      title: 'رقم الهاتف',
      dataIndex: 'patient_phone',
      render: (value: string) => value || '-',
    },
    {
      title: 'المنصة',
      dataIndex: 'platform',
      render: (value: string) => value || '-',
    },
    {
      title: 'المحافظة',
      dataIndex: 'governorate',
      render: (value: string) => value || '-',
    },
    {
      title: 'ملاحظة',
      dataIndex: 'note',
      render: (value: string) => value || '-',
    },
    {
      title: 'الفرع',
      dataIndex: 'branch',
      render: (value: BranchKey | undefined) => branchLabel(value),
    },
    {
      title: 'الموظف',
      dataIndex: 'created_by_username',
      render: (value: string) => value || '-',
    },
    {
      title: 'الحالة',
      dataIndex: 'status',
      render: (value: string) =>
        value?.toLowerCase() === 'accepted' ? <Tag color="green">مقبول</Tag> : <Tag color="gold">قيد الانتظار</Tag>,
    },
    {
      title: 'إجراءات',
      key: 'actions',
      render: (_, record) => (
        <Space size="small">
          <Button
            size="small"
            icon={<EditOutlined />}
            onClick={() => openEdit(record)}
            disabled={record.status?.toLowerCase() === 'accepted'}
          >
            تعديل
          </Button>
          <Popconfirm
            title="حذف الحجز"
            description="هل تريد حذف هذا الحجز؟"
            okText="نعم"
            cancelText="إلغاء"
            onConfirm={() => void handleDelete(record)}
            disabled={record.status?.toLowerCase() === 'accepted'}
          >
            <Button danger size="small" icon={<DeleteOutlined />} disabled={record.status?.toLowerCase() === 'accepted'}>
              حذف
            </Button>
          </Popconfirm>
        </Space>
      ),
    },
  ];

  const doctorColumns: ColumnsType<CallCenterDoctorAppointmentListItem> = [
    {
      title: 'المريض',
      dataIndex: 'patient_name',
      render: (value: string | null) => value ?? '-',
    },
    {
      title: 'الهاتف',
      dataIndex: 'patient_phone',
      render: (value: string | null | undefined) => value ?? '-',
    },
    {
      title: 'الطبيب',
      dataIndex: 'doctor_name',
      render: (value: string | null | undefined) => value ?? '-',
    },
    {
      title: 'اليوم والوقت',
      dataIndex: 'scheduled_at',
      render: (value: string) => dayjs(value).format('YYYY-MM-DD hh:mm A'),
    },
    {
      title: 'الحالة',
      dataIndex: 'status',
      render: (value: string) => statusLabel(value),
    },
    {
      title: 'الفرع',
      dataIndex: 'branch',
      render: (value: BranchKey | undefined) => branchLabel(value),
    },
  ];

  return (
    <div className={`page-wrap ${isMobile ? 'cc-mobile-shell' : ''}`}>
      {isMobile ? (
        <div className="cc-mobile">
          <div className="cc-mobile-stats" style={{ opacity: statsLoading ? 0.55 : 1, transition: 'opacity 0.2s ease' }}>
            <div className="cc-mobile-stats-primary">
              <button type="button" className="cc-stat-card-figma" onClick={() => setStatsModalOpen(true)}>
                <span className="cc-stat-icon-wrap cc-stat-icon-total">
                  <UnorderedListOutlined />
                </span>
                <div className="cc-stat-figma-copy">
                  <div className="cc-stat-figma-value">{stats.total}</div>
                  <div className="cc-stat-figma-label">كل المواعيد</div>
                </div>
              </button>
              <button type="button" className="cc-stat-card-figma" onClick={() => setStatsModalOpen(true)}>
                <span className="cc-stat-icon-wrap cc-stat-icon-month">
                  <CalendarOutlined />
                </span>
                <div className="cc-stat-figma-copy">
                  <div className="cc-stat-figma-value">{stats.thisMonth}</div>
                  <div className="cc-stat-figma-label">مواعيد هذا الشهر</div>
                </div>
              </button>
              <button type="button" className="cc-stat-card-figma" onClick={() => setStatsModalOpen(true)}>
                <span className="cc-stat-icon-wrap cc-stat-icon-today">
                  <ClockCircleOutlined />
                </span>
                <div className="cc-stat-figma-copy">
                  <div className="cc-stat-figma-value">{stats.today}</div>
                  <div className="cc-stat-figma-label">مواعيد اليوم</div>
                </div>
              </button>
            </div>
            <div className="cc-mobile-stats-secondary">
              <button type="button" className="cc-stat-card-figma-wide" onClick={() => setTableRangeModalOpen(true)}>
                <span className="cc-stat-icon-wrap cc-stat-icon-range">
                  <FieldTimeOutlined />
                </span>
                <div className="cc-stat-figma-copy">
                  <div className="cc-stat-figma-value">{stats.rangeCount}</div>
                  <div className="cc-stat-figma-label">ضمن فترة محددة</div>
                  <div className="cc-stat-figma-sub">{rangeLabel}</div>
                </div>
              </button>
              <button type="button" className="cc-stat-card-figma-wide" onClick={() => setAcceptedRangeModalOpen(true)}>
                <span className="cc-stat-icon-wrap cc-stat-icon-accepted">
                  <CheckCircleOutlined />
                </span>
                <div className="cc-stat-figma-copy">
                  <div className="cc-stat-figma-value">{acceptedValue}</div>
                  <div className="cc-stat-figma-label">المواعيد المقبولة</div>
                  <div className="cc-stat-figma-sub">{acceptedSubtitle}</div>
                </div>
              </button>
            </div>
          </div>

          <Button
            type="primary"
            block
            size="large"
            icon={<PlusOutlined />}
            className="cc-mobile-add-btn"
            onClick={() => setCreateModalOpen(true)}
          >
            اضافة موعد جديد
          </Button>

          <div className="cc-mobile-search-row">
            <Input
              allowClear
              value={searchInput}
              onChange={(event) => setSearchInput(event.target.value)}
              placeholder="ابحث عن اسم المريض أو رقم الهاتف..."
              prefix={<SearchOutlined />}
              className="cc-mobile-search"
            />
          </div>

          <div className="cc-mobile-chips">
            {[
              { key: 'all', label: 'الكل' },
              { key: 'today', label: 'اليوم' },
              { key: 'week', label: 'هذا الأسبوع' },
              { key: 'month', label: 'هذا الشهر' },
            ].map((chip) => (
              <button
                key={chip.key}
                type="button"
                className={`cc-chip ${mobileTimeFilter === chip.key ? 'active' : ''}`}
                onClick={() => setMobileTimeFilter(chip.key as 'all' | 'today' | 'week' | 'month')}
              >
                {chip.label}
              </button>
            ))}
          </div>

          <div className="cc-mobile-list">
            {loading ? (
              <div className="call-center-loading-wrap">
                <Spin />
              </div>
            ) : tableFilteredAppointments.length === 0 ? (
              <div className="cc-mobile-empty">لا توجد حجوزات</div>
            ) : (
              tableFilteredAppointments.map((item) => {
                const isAccepted = item.status?.toLowerCase() === 'accepted';
                const phone = item.patient_phone || '';
                return (
                  <div
                    key={`${item.branch ?? 'farah_najaf'}-${item.id}`}
                    className={`cc-booking-card ${isAccepted ? 'accepted' : ''}`}
                  >
                    <a
                      className="cc-call-btn"
                      href={phone ? `tel:${phone}` : undefined}
                      onClick={(event) => {
                        if (!phone) event.preventDefault();
                      }}
                      aria-label="اتصال"
                    >
                      <PhoneOutlined />
                    </a>

                    <div className="cc-booking-main">
                      <div className="cc-booking-name">{item.patient_name || '-'}</div>
                      <div className="cc-booking-clinic">
                        <EnvironmentOutlined />
                        <span>{item.branch === 'kendy_baghdad' ? 'عيادة الكندي بغداد' : 'عيادة فرح النجف'}</span>
                      </div>
                      <div className="cc-booking-phone">{phone || '-'}</div>
                    </div>

                    <div className="cc-booking-meta">
                      <Dropdown
                        menu={{
                          items: [
                            {
                              key: 'edit',
                              label: 'تعديل',
                              icon: <EditOutlined />,
                              disabled: isAccepted,
                              onClick: () => openEdit(item),
                            },
                            {
                              key: 'delete',
                              label: 'حذف',
                              icon: <DeleteOutlined />,
                              danger: true,
                              disabled: isAccepted,
                              onClick: () => {
                                Modal.confirm({
                                  title: 'حذف الحجز',
                                  content: 'هل تريد حذف هذا الحجز؟',
                                  okText: 'نعم',
                                  cancelText: 'إلغاء',
                                  onOk: () => handleDelete(item),
                                });
                              },
                            },
                          ],
                        }}
                        trigger={['click']}
                        placement="bottomLeft"
                      >
                        <button type="button" className="cc-more-btn" aria-label="المزيد">
                          <MoreOutlined />
                        </button>
                      </Dropdown>
                      <div className="cc-booking-time">{dayjs(item.scheduled_at).format('h:mm A')}</div>
                      <div className="cc-booking-date">{dayjs(item.scheduled_at).format('YYYY/MM/DD')}</div>
                    </div>
                  </div>
                );
              })
            )}
          </div>

          <div ref={loadMoreRef} className="cc-infinite-sentinel" aria-hidden={!loadingMore}>
            {loadingMore ? <Spin size="small" /> : null}
          </div>
        </div>
      ) : (
        <>
          <div className="call-center-toolbar">
            <div>
              <Typography.Title level={3} style={{ marginBottom: 0 }}>
                منصة موظف الكول سنتر
              </Typography.Title>
              <Typography.Text type="secondary">
                إدارة الحجوزات الأولية ومتابعة الإحصائيات اليومية والشهرية.
              </Typography.Text>
            </div>
            <Space wrap>
              <Button icon={<UnorderedListOutlined />} onClick={() => setDoctorModalOpen(true)}>
                مواعيد الأطباء
              </Button>
              <Button type="primary" icon={<PlusOutlined />} onClick={() => setCreateModalOpen(true)}>
                موعد جديد
              </Button>
            </Space>
          </div>

          <Row gutter={[12, 12]}>
            <Col xs={24} md={12} xl={6}>
              <KpiCard title="مواعيد اليوم" value={stats.today} />
            </Col>
            <Col xs={24} md={12} xl={6}>
              <KpiCard title="مواعيد هذا الشهر" value={stats.thisMonth} />
            </Col>
            <Col xs={24} md={12} xl={6}>
              <KpiCard title="كل المواعيد" value={stats.total} />
            </Col>
            <Col xs={24} md={12} xl={6}>
              <KpiCard
                title="ضمن فترة محددة"
                value={stats.rangeCount}
                subtitle={rangeLabel}
                actionIcon={<CalendarOutlined />}
                actionTooltip="اختيار فترة"
                onActionClick={() => setTableRangeModalOpen(true)}
              />
            </Col>
            <Col xs={24} md={12} xl={6}>
              <KpiCard
                title="المواعيد المقبولة"
                value={acceptedValue}
                subtitle={acceptedSubtitle}
                actionIcon={<CalendarOutlined />}
                actionTooltip="اختيار فترة المقبول"
                onActionClick={() => setAcceptedRangeModalOpen(true)}
              />
            </Col>
          </Row>

          <Card className="glass-card">
            <Row gutter={[12, 12]}>
              <Col xs={24} lg={10}>
                <Input
                  value={searchInput}
                  allowClear
                  prefix={<SearchOutlined />}
                  onChange={(event) => setSearchInput(event.target.value)}
                  placeholder="ابحث عن اسم المريض أو رقم الهاتف..."
                />
              </Col>
              <Col xs={24} lg={10}>
                <DatePicker.RangePicker
                  getPopupContainer={popupContainer}
                  value={tableFilterRange}
                  allowEmpty={[true, true]}
                  onChange={(value) => setTableFilterRange([value?.[0] ?? null, value?.[1] ?? null])}
                  style={{ width: '100%' }}
                />
              </Col>
              <Col xs={24} lg={4}>
                <Button block onClick={() => setTableFilterRange([null, null])}>
                  مسح الفترة
                </Button>
              </Col>
            </Row>

            <div style={{ marginTop: 14 }}>
              {loading ? (
                <div className="call-center-loading-wrap">
                  <Spin />
                </div>
              ) : (
                <Table
                  rowKey={(record) => `${record.branch ?? 'farah_najaf'}-${record.id}`}
                  dataSource={tableFilteredAppointments}
                  columns={columns}
                  pagination={false}
                  scroll={{ x: 1300 }}
                  rowClassName={(record) =>
                    record.status?.toLowerCase() === 'accepted' ? 'call-center-row-accepted' : ''
                  }
                  locale={{ emptyText: 'لا توجد حجوزات' }}
                />
              )}

              <div ref={loadMoreRef} className="cc-infinite-sentinel" aria-hidden={!loadingMore}>
                {loadingMore ? <Spin size="small" /> : null}
              </div>
            </div>
          </Card>
        </>
      )}

      <Modal
        title="إضافة موعد جديد"
        width={isMobile ? '95vw' : 520}
        centered
        open={createModalOpen}
        onCancel={() => setCreateModalOpen(false)}
        onOk={() => void submitCreate()}
        okText="حفظ"
        cancelText="إلغاء"
        confirmLoading={submitting}
      >
        <Form<AppointmentFormValues> form={createForm} layout="vertical">
          <Form.Item name="patient_name" label="اسم المريض" rules={[{ required: true, message: 'الحقل مطلوب' }]}>
            <Input />
          </Form.Item>
          <Form.Item name="patient_phone" label="رقم الهاتف" rules={[{ required: true, message: 'الحقل مطلوب' }]}>
            <Input maxLength={14} />
          </Form.Item>
          <Form.Item name="governorate" label="المحافظة">
            <Select allowClear options={IRAQ_GOVERNORATES.map((value) => ({ value, label: value }))} />
          </Form.Item>
          <Form.Item name="platform" label="المنصة">
            <Select allowClear options={BOOKING_PLATFORMS.map((value) => ({ value, label: value }))} />
          </Form.Item>
          <Form.Item name="branch" label="الفرع" rules={[{ required: true, message: 'الحقل مطلوب' }]}>
            <Select options={BRANCH_OPTIONS} />
          </Form.Item>
          <Form.Item name="scheduled_at" label="التاريخ والوقت" rules={[{ required: true, message: 'الحقل مطلوب' }]}>
            <AdaptiveDateTimePicker getPopupContainer={popupContainer} disabledTime={disabledTime} />
          </Form.Item>
          <Form.Item name="note" label="ملاحظة">
            <Input.TextArea rows={3} />
          </Form.Item>
        </Form>
      </Modal>

      <Modal
        title="تعديل الموعد"
        width={isMobile ? '95vw' : 520}
        centered
        open={editModalOpen}
        onCancel={() => {
          setEditModalOpen(false);
          setEditingAppointment(null);
        }}
        onOk={() => void submitEdit()}
        okText="حفظ"
        cancelText="إلغاء"
        confirmLoading={submitting}
      >
        <Form<AppointmentFormValues> form={editForm} layout="vertical">
          <Form.Item name="patient_name" label="اسم المريض" rules={[{ required: true, message: 'الحقل مطلوب' }]}>
            <Input />
          </Form.Item>
          <Form.Item name="patient_phone" label="رقم الهاتف" rules={[{ required: true, message: 'الحقل مطلوب' }]}>
            <Input maxLength={14} />
          </Form.Item>
          <Form.Item name="governorate" label="المحافظة">
            <Select allowClear options={IRAQ_GOVERNORATES.map((value) => ({ value, label: value }))} />
          </Form.Item>
          <Form.Item name="platform" label="المنصة">
            <Select allowClear options={BOOKING_PLATFORMS.map((value) => ({ value, label: value }))} />
          </Form.Item>
          <Form.Item name="scheduled_at" label="التاريخ والوقت" rules={[{ required: true, message: 'الحقل مطلوب' }]}>
            <AdaptiveDateTimePicker getPopupContainer={popupContainer} disabledTime={disabledTime} />
          </Form.Item>
          <Form.Item name="note" label="ملاحظة">
            <Input.TextArea rows={3} />
          </Form.Item>
        </Form>
      </Modal>

      <Modal
        title="مواعيد الأطباء"
        open={doctorModalOpen}
        onCancel={() => setDoctorModalOpen(false)}
        footer={[
          <Button key="close" onClick={() => setDoctorModalOpen(false)}>
            إغلاق
          </Button>,
        ]}
        width={isMobile ? '95vw' : 1100}
      >
        <Row gutter={[10, 10]} style={{ marginBottom: 12 }}>
          <Col xs={24} md={8}>
            <Select
              value={doctorFilterMode}
              onChange={(value: 'today' | 'month' | 'custom') => setDoctorFilterMode(value)}
              style={{ width: '100%' }}
              options={[
                { value: 'today', label: 'اليوم' },
                { value: 'month', label: 'هذا الشهر' },
                { value: 'custom', label: 'فترة مخصصة' },
              ]}
            />
          </Col>
          <Col xs={24} md={12}>
            <AdaptiveDateRangePicker
              getPopupContainer={popupContainer}
              disabled={doctorFilterMode !== 'custom'}
              value={doctorRange}
              onChange={(value) => setDoctorRange(value)}
              style={{ width: '100%' }}
            />
          </Col>
          <Col xs={24} md={4}>
            <Button icon={<CalendarOutlined />} block onClick={() => void loadDoctorAppointments()}>
              تحديث
            </Button>
          </Col>
        </Row>

        {isMobile ? (
          <div className="mobile-appointment-list" style={{ marginTop: 16 }}>
            {doctorLoading ? (
              <div style={{ textAlign: 'center', padding: '40px 0' }}><Spin /></div>
            ) : doctorAppointments.length === 0 ? (
              <div style={{ textAlign: 'center', padding: '40px 0', color: '#64748b' }}>لا توجد مواعيد</div>
            ) : (
              doctorAppointments.map((item) => (
                <div key={`${item.branch ?? 'farah_najaf'}-${item.id}`} className="mobile-appointment-card">
                  <div className="mobile-appointment-header">
                    <div>
                      <h3 className="mobile-appointment-title">{item.patient_name || '-'}</h3>
                      <div className="mobile-appointment-phone">{item.patient_phone || '-'}</div>
                    </div>
                    <Tag color="blue">{statusLabel(item.status)}</Tag>
                  </div>
                  <div className="mobile-appointment-details">
                    <div className="mobile-appointment-detail-item">
                      <span className="mobile-appointment-detail-label">الطبيب</span>
                      <span className="mobile-appointment-detail-value">{item.doctor_name || '-'}</span>
                    </div>
                    <div className="mobile-appointment-detail-item">
                      <span className="mobile-appointment-detail-label">التاريخ والوقت</span>
                      <span className="mobile-appointment-detail-value">{dayjs(item.scheduled_at).format('YYYY-MM-DD hh:mm A')}</span>
                    </div>
                    <div className="mobile-appointment-detail-item">
                      <span className="mobile-appointment-detail-label">الفرع</span>
                      <span className="mobile-appointment-detail-value">{branchLabel(item.branch)}</span>
                    </div>
                  </div>
                </div>
              ))
            )}
          </div>
        ) : (
          <Table
            rowKey={(record) => `${record.branch ?? 'farah_najaf'}-${record.id}`}
            loading={doctorLoading}
            dataSource={doctorAppointments}
            columns={doctorColumns}
            pagination={{ pageSize: 10, showSizeChanger: false }}
            scroll={{ x: 900 }}
            locale={{ emptyText: 'لا توجد مواعيد' }}
          />
        )}
      </Modal>

      <Modal
        title="المواعيد ضمن فترة محددة"
        width={isMobile ? '95vw' : 460}
        centered
        open={tableRangeModalOpen}
        onCancel={() => setTableRangeModalOpen(false)}
        onOk={() => setTableRangeModalOpen(false)}
        okText="تطبيق"
        cancelText="إلغاء"
      >
        <Space direction="vertical" style={{ width: '100%' }} size={12}>
          <AdaptiveDateRangePicker
            getPopupContainer={popupContainer}
            value={statsRange}
            onChange={setStatsRange}
            style={{ width: '100%' }}
          />
          {rangeModalPreviewCount != null ? (
            <Typography.Text>عدد المواعيد: {rangeModalPreviewCount}</Typography.Text>
          ) : null}
        </Space>
      </Modal>

      <Modal
        title="المواعيد المقبولة ضمن فترة"
        width={isMobile ? '95vw' : 460}
        centered
        open={acceptedRangeModalOpen}
        onCancel={() => setAcceptedRangeModalOpen(false)}
        onOk={() => setAcceptedRangeModalOpen(false)}
        okText="تطبيق"
        cancelText="إلغاء"
      >
        <Space direction="vertical" style={{ width: '100%' }} size={12}>
          <AdaptiveDateRangePicker
            getPopupContainer={popupContainer}
            value={acceptedRange}
            onChange={setAcceptedRange}
            style={{ width: '100%' }}
          />
          {acceptedModalPreviewCount != null ? (
            <Typography.Text>عدد المواعيد المقبولة: {acceptedModalPreviewCount}</Typography.Text>
          ) : null}
        </Space>
      </Modal>

      <Modal
        title="إحصائيات الكول سنتر"
        open={statsModalOpen}
        onCancel={() => setStatsModalOpen(false)}
        footer={[
          <Button key="close" onClick={() => setStatsModalOpen(false)}>
            إغلاق
          </Button>
        ]}
        width="100%"
        style={{ top: 20, padding: 0 }}
        bodyStyle={{ padding: '16px 8px', maxHeight: 'calc(100vh - 120px)', overflowY: 'auto' }}
      >
        <div style={{ display: 'flex', flexDirection: 'column', gap: '16px' }}>
          <KpiCard title="مواعيد اليوم" value={stats.today} />
          <KpiCard title="مواعيد هذا الشهر" value={stats.thisMonth} />
          <KpiCard title="كل المواعيد" value={stats.total} />
          <KpiCard
            title="ضمن فترة محددة"
            value={stats.rangeCount}
            subtitle={rangeLabel}
            actionIcon={<CalendarOutlined />}
            actionTooltip="اختيار فترة"
            onActionClick={() => setTableRangeModalOpen(true)}
          />
          <KpiCard
            title="المواعيد المقبولة"
            value={acceptedValue}
            subtitle={acceptedSubtitle}
            actionIcon={<CalendarOutlined />}
            actionTooltip="اختيار فترة المقبول"
            onActionClick={() => setAcceptedRangeModalOpen(true)}
          />
        </div>
      </Modal>
    </div>
  );
}
