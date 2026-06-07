import { Card, DatePicker, Row, Col, Spin, Table, Typography, Tag } from 'antd';
import type { Dayjs } from 'dayjs';
import dayjs from 'dayjs';
import { useEffect, useMemo, useState } from 'react';
import { useNavigate } from 'react-router-dom';
import { fetchDoctorsComparison } from '../services/statsApi';
import type { DoctorComparison } from '../types/stats';

const { RangePicker } = DatePicker;

export function DoctorsComparisonPage() {
  const [loading, setLoading] = useState(true);
  const [rows, setRows] = useState<DoctorComparison[]>([]);
  const [dates, setDates] = useState<[Dayjs | null, Dayjs | null]>([dayjs().startOf('month'), dayjs()]);
  const navigate = useNavigate();

  useEffect(() => {
    const load = async () => {
      try {
        setLoading(true);
        const data = await fetchDoctorsComparison({
          date_from: dates[0]?.toISOString(),
          date_to: dates[1]?.endOf('day').toISOString(),
        });
        setRows(data.doctors);
      } finally {
        setLoading(false);
      }
    };
    void load();
  }, [dates]);

  const columns = useMemo(
    () => [
      { title: 'الطبيب', dataIndex: 'name', render: (value: string) => value ?? 'بدون اسم' },
      {
        title: 'الحالة',
        render: (_: unknown, row: DoctorComparison) =>
          row.is_manager ? <Tag color="gold">طبيب مدير</Tag> : <Tag color="blue">طبيب</Tag>,
      },
      { title: 'مرضى حاليون', render: (_: unknown, row: DoctorComparison) => row.patients.total_current },
      { title: 'نشطين', render: (_: unknown, row: DoctorComparison) => row.patients.active_current },
      { title: 'غير نشطين', render: (_: unknown, row: DoctorComparison) => row.patients.inactive_current },
      { title: 'تحويلات اليوم', render: (_: unknown, row: DoctorComparison) => row.transfers.today },
      { title: 'تحويلات الشهر', render: (_: unknown, row: DoctorComparison) => row.transfers.this_month },
      { title: 'مواعيد اليوم', render: (_: unknown, row: DoctorComparison) => row.appointments.today },
      { title: 'مواعيد الشهر', render: (_: unknown, row: DoctorComparison) => row.appointments.this_month },
      { title: 'مكتملة', render: (_: unknown, row: DoctorComparison) => row.appointments.completed_all_time },
      { title: 'سجلات علاجية', dataIndex: 'treatment_notes' },
    ],
    [],
  );

  if (loading) return <Spin size="large" />;

  return (
    <div className="page-wrap">
      <Typography.Title level={3}>مقارنة شاملة بين الأطباء</Typography.Title>
      <Row gutter={[12, 12]} style={{ marginBottom: 12 }}>
        <Col xs={24} md={14}>
          <RangePicker
            value={dates}
            onChange={(value) => setDates([value?.[0] ?? null, value?.[1] ?? null])}
            style={{ width: '100%' }}
          />
        </Col>
      </Row>
      <Card className="glass-card">
        <Table
          rowKey="doctor_id"
          dataSource={rows}
          columns={columns}
          scroll={{ x: 1300 }}
          onRow={(record) => ({
            onClick: () => navigate(`/doctor-details?doctorId=${record.doctor_id}`),
          })}
        />
      </Card>
    </div>
  );
}
