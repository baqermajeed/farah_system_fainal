import { Card, Spin, Table, Typography, Tag } from 'antd';
import { useEffect, useMemo, useState } from 'react';
import { useNavigate } from 'react-router-dom';
import { fetchDoctorsComparison } from '../services/statsApi';
import type { DoctorComparison } from '../types/stats';

export function DoctorsComparisonPage() {
  const [loading, setLoading] = useState(true);
  const [refreshing, setRefreshing] = useState(false);
  const [rows, setRows] = useState<DoctorComparison[]>([]);
  const navigate = useNavigate();

  useEffect(() => {
    const load = async () => {
      try {
        const isInitialLoad = rows.length === 0;
        if (isInitialLoad) {
          setLoading(true);
        } else {
          setRefreshing(true);
        }
        const data = await fetchDoctorsComparison({});
        setRows(data.doctors);
      } finally {
        setLoading(false);
        setRefreshing(false);
      }
    };
    void load();
  }, []);

  const columns = useMemo(
    () => [
      {
        title: 'الطبيب',
        dataIndex: 'name',
        width: 170,
        ellipsis: true,
        render: (value: string) => value ?? 'بدون اسم',
      },
      {
        title: 'الحالة',
        width: 120,
        render: (_: unknown, row: DoctorComparison) =>
          row.is_manager ? <Tag color="gold">طبيب مدير</Tag> : <Tag color="blue">طبيب</Tag>,
      },
      { title: 'مرضى حاليون', width: 110, render: (_: unknown, row: DoctorComparison) => row.patients.total_current },
      { title: 'نشطين', width: 95, render: (_: unknown, row: DoctorComparison) => row.patients.active_current },
      { title: 'غير نشطين', width: 110, render: (_: unknown, row: DoctorComparison) => row.patients.inactive_current },
      { title: 'تحويلات اليوم', width: 110, render: (_: unknown, row: DoctorComparison) => row.transfers.today },
      { title: 'تحويلات الشهر', width: 110, render: (_: unknown, row: DoctorComparison) => row.transfers.this_month },
    ],
    [],
  );

  if (loading && rows.length === 0) return <Spin size="large" />;

  return (
    <div className="page-wrap">
      <Typography.Title level={3}>مقارنة شاملة بين الأطباء</Typography.Title>
      {refreshing ? (
        <div style={{ display: 'flex', justifyContent: 'center', marginBottom: 12 }}>
          <Spin size="small" />
        </div>
      ) : null}
      <Card className="glass-card">
        <Table
          size="small"
          tableLayout="fixed"
          rowKey="doctor_id"
          dataSource={rows}
          columns={columns}
          pagination={false}
          onRow={(record) => ({
            onClick: () => navigate(`/doctor-details?doctorId=${record.doctor_id}`),
          })}
        />
      </Card>
    </div>
  );
}
