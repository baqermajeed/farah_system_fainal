import {
  CalendarOutlined,
  DeleteOutlined,
  EditOutlined,
  PlusOutlined,
  SearchOutlined,
  UnorderedListOutlined,
} from '@ant-design/icons';
import {
  Button,
  Card,
  Col,
  DatePicker,
  Form,
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
import { useEffect, useMemo, useState } from 'react';
import { KpiCard } from '../components/KpiCard';
import {
  createCallCenterAppointment,
  deleteCallCenterAppointment,
  fetchCallCenterDoctorAppointmentsFromBoth,
  fetchCallCenterMyAppointmentsFromBoth,
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

function isSameCalendarDay(a: Date, b: Date) {
  return a.getFullYear() === b.getFullYear() && a.getMonth() === b.getMonth() && a.getDate() === b.getDate();
}

function isSameCalendarMonth(a: Date, b: Date) {
  return a.getFullYear() === b.getFullYear() && a.getMonth() === b.getMonth();
}

function isWithinInclusiveDayRange(target: Date, start: Date, end: Date) {
  const s = new Date(start.getFullYear(), start.getMonth(), start.getDate(), 0, 0, 0, 0);
  const e = new Date(end.getFullYear(), end.getMonth(), end.getDate(), 23, 59, 59, 999);
  return target.getTime() >= s.getTime() && target.getTime() <= e.getTime();
}

function baseDateOf(item: CallCenterAppointmentListItem) {
  const createdAt = item.created_at ? new Date(item.created_at) : null;
  if (createdAt && !Number.isNaN(createdAt.getTime())) {
    return createdAt;
  }
  const scheduledAt = item.scheduled_at ? new Date(item.scheduled_at) : null;
  return scheduledAt && !Number.isNaN(scheduledAt.getTime()) ? scheduledAt : null;
}

function branchLabel(value: BranchKey | undefined) {
  if (value === 'kendy_baghdad') return 'الكندي بغداد';
  return 'فرح النجف';
}

function statusLabel(value: string) {
  return value?.toLowerCase() === 'accepted' ? 'مقبول' : 'قيد الانتظار';
}

export function CallCenterWorkspacePage() {
  const [loading, setLoading] = useState(true);
  const [appointments, setAppointments] = useState<CallCenterAppointmentListItem[]>([]);
  const [searchInput, setSearchInput] = useState('');
  const [searchQuery, setSearchQuery] = useState('');
  const [tableRange, setTableRange] = useState<DateRange>([null, null]);
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

  useEffect(() => {
    const timer = setTimeout(() => {
      setSearchQuery(searchInput.trim());
    }, 300);
    return () => clearTimeout(timer);
  }, [searchInput]);

  const loadAppointments = async () => {
    try {
      setLoading(true);
      const date_from = tableRange[0]?.startOf('day').toISOString();
      const date_to = tableRange[1]?.endOf('day').toISOString();
      const data = await fetchCallCenterMyAppointmentsFromBoth({
        search: searchQuery || undefined,
        date_from,
        date_to,
      });
      setAppointments(data);
    } catch (error) {
      console.error('Failed to load call center appointments', error);
      message.error('تعذر تحميل الحجوزات');
      setAppointments([]);
    } finally {
      setLoading(false);
    }
  };

  useEffect(() => {
    void loadAppointments();
  }, [searchQuery, tableRange]);

  const stats = useMemo(() => {
    const now = new Date();
    let today = 0;
    let thisMonth = 0;
    let acceptedThisMonth = 0;
    let acceptedInRange = 0;
    const acceptedFrom = acceptedRange[0]?.toDate() ?? null;
    const acceptedTo = acceptedRange[1]?.toDate() ?? null;

    for (const item of appointments) {
      const baseDate = baseDateOf(item);
      if (!baseDate) continue;

      if (isSameCalendarDay(baseDate, now)) {
        today += 1;
      }
      if (isSameCalendarMonth(baseDate, now)) {
        thisMonth += 1;
      }
      if (item.status?.toLowerCase() === 'accepted') {
        const acceptedAt = item.accepted_at ? new Date(item.accepted_at) : null;
        const acceptedDate =
          acceptedAt && !Number.isNaN(acceptedAt.getTime()) ? acceptedAt : baseDate;
        if (isSameCalendarMonth(acceptedDate, now)) {
          acceptedThisMonth += 1;
        }
        if (acceptedFrom && acceptedTo && isWithinInclusiveDayRange(acceptedDate, acceptedFrom, acceptedTo)) {
          acceptedInRange += 1;
        }
      }
    }

    return {
      total: appointments.length,
      today,
      thisMonth,
      acceptedThisMonth,
      acceptedInRange,
    };
  }, [appointments, acceptedRange]);

  const acceptedRangeLabel =
    acceptedRange[0] && acceptedRange[1]
      ? `${acceptedRange[0].format('YYYY/MM/DD')} → ${acceptedRange[1].format('YYYY/MM/DD')}`
      : 'اختر فترة';

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
      await loadAppointments();
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
      await loadAppointments();
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
      await loadAppointments();
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
    <div className="page-wrap">
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
          <KpiCard title="المواعيد المقبولة هذا الشهر" value={stats.acceptedThisMonth} />
        </Col>
        <Col xs={24} md={12} xl={6}>
          <KpiCard
            title="المواعيد المقبولة ضمن فترة محددة"
            value={stats.acceptedInRange}
            subtitle={acceptedRangeLabel}
            actionIcon={<CalendarOutlined />}
            actionTooltip="اختيار فترة"
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
              value={tableRange}
              allowEmpty={[true, true]}
              onChange={(value) => setTableRange([value?.[0] ?? null, value?.[1] ?? null])}
              style={{ width: '100%' }}
            />
          </Col>
          <Col xs={24} lg={4}>
            <Button block onClick={() => setTableRange([null, null])}>
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
              dataSource={appointments}
              columns={columns}
              pagination={{ pageSize: 20, showSizeChanger: false }}
              scroll={{ x: 1300 }}
              rowClassName={(record) => (record.status?.toLowerCase() === 'accepted' ? 'call-center-row-accepted' : '')}
              locale={{ emptyText: 'لا توجد حجوزات' }}
            />
          )}
        </div>
      </Card>

      <Modal
        title="إضافة موعد جديد"
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
            <DatePicker
              showTime={{ format: 'HH:mm', hideDisabledOptions: true }}
              disabledTime={disabledTime}
              format="YYYY-MM-DD HH:mm"
              style={{ width: '100%' }}
            />
          </Form.Item>
          <Form.Item name="note" label="ملاحظة">
            <Input.TextArea rows={3} />
          </Form.Item>
        </Form>
      </Modal>

      <Modal
        title="تعديل الموعد"
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
            <DatePicker
              showTime={{ format: 'HH:mm', hideDisabledOptions: true }}
              disabledTime={disabledTime}
              format="YYYY-MM-DD HH:mm"
              style={{ width: '100%' }}
            />
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
        width={1100}
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
            <DatePicker.RangePicker
              disabled={doctorFilterMode !== 'custom'}
              value={doctorRange}
              onChange={(value) => setDoctorRange([value?.[0] ?? null, value?.[1] ?? null])}
              style={{ width: '100%' }}
            />
          </Col>
          <Col xs={24} md={4}>
            <Button icon={<CalendarOutlined />} block onClick={() => void loadDoctorAppointments()}>
              تحديث
            </Button>
          </Col>
        </Row>

        <Table
          rowKey={(record) => `${record.branch ?? 'farah_najaf'}-${record.id}`}
          loading={doctorLoading}
          dataSource={doctorAppointments}
          columns={doctorColumns}
          pagination={{ pageSize: 10, showSizeChanger: false }}
          scroll={{ x: 900 }}
          locale={{ emptyText: 'لا توجد مواعيد' }}
        />
      </Modal>

      <Modal
        title="المواعيد المقبولة ضمن فترة محددة"
        open={acceptedRangeModalOpen}
        onCancel={() => setAcceptedRangeModalOpen(false)}
        onOk={() => setAcceptedRangeModalOpen(false)}
        okText="تطبيق"
        cancelText="إلغاء"
      >
        <DatePicker.RangePicker
          value={acceptedRange}
          onChange={(value) => setAcceptedRange([value?.[0] ?? null, value?.[1] ?? null])}
          style={{ width: '100%' }}
        />
      </Modal>
    </div>
  );
}
