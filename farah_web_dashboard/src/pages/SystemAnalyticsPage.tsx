import { Card, Col, DatePicker, Row, Select, Spin, Table, Typography } from 'antd';
import type { Dayjs } from 'dayjs';
import dayjs from 'dayjs';
import { useEffect, useMemo, useState } from 'react';
import { fetchAppointmentsStats, fetchChatStats, fetchNotificationsStats, fetchTransfersStats, fetchUsersStats } from '../services/statsApi';
import { KpiCard } from '../components/KpiCard';
import type {
  AppointmentsStatsResponse,
  ChatStatsResponse,
  NotificationStatsResponse,
  TransfersStatsResponse,
  UsersStatsResponse,
} from '../types/stats';

const { RangePicker } = DatePicker;

export function SystemAnalyticsPage() {
  const [loading, setLoading] = useState(true);
  const [dates, setDates] = useState<[Dayjs | null, Dayjs | null]>([dayjs().startOf('month'), dayjs()]);
  const [group, setGroup] = useState<'day' | 'month' | 'year'>('day');
  const [usersStats, setUsersStats] = useState<UsersStatsResponse | null>(null);
  const [appointmentsStats, setAppointmentsStats] = useState<AppointmentsStatsResponse | null>(null);
  const [chatStats, setChatStats] = useState<ChatStatsResponse | null>(null);
  const [notificationsStats, setNotificationsStats] = useState<NotificationStatsResponse | null>(null);
  const [transfersStats, setTransfersStats] = useState<TransfersStatsResponse | null>(null);

  useEffect(() => {
    const load = async () => {
      try {
        setLoading(true);
        const date_from = dates[0]?.toISOString();
        const date_to = dates[1]?.endOf('day').toISOString();
        const [users, appointments, chat, notifications, transfers] = await Promise.all([
          fetchUsersStats(),
          fetchAppointmentsStats({ date_from, date_to }),
          fetchChatStats({ date_from, date_to }),
          fetchNotificationsStats({ date_from, date_to }),
          fetchTransfersStats({ group, date_from, date_to }),
        ]);
        setUsersStats(users);
        setAppointmentsStats(appointments);
        setChatStats(chat);
        setNotificationsStats(notifications);
        setTransfersStats(transfers);
      } finally {
        setLoading(false);
      }
    };
    void load();
  }, [dates, group]);

  const rolesRows = useMemo(
    () =>
      usersStats
        ? Object.entries(usersStats.by_role).map(([role, count]) => ({
            key: role,
            role,
            count,
          }))
        : [],
    [usersStats],
  );

  const transferRows = useMemo(
    () => (transfersStats ? transfersStats.by_period.map((item) => ({ key: item.period, ...item })) : []),
    [transfersStats],
  );

  if (loading) return <Spin size="large" />;

  return (
    <div className="page-wrap">
      <Typography.Title level={3}>إحصائيات النظام التفصيلية</Typography.Title>
      <Row gutter={[12, 12]} style={{ marginBottom: 16 }}>
        <Col xs={24} md={16}>
          <RangePicker
            value={dates}
            onChange={(value) => setDates([value?.[0] ?? null, value?.[1] ?? null])}
            style={{ width: '100%' }}
          />
        </Col>
        <Col xs={24} md={8}>
          <Select
            value={group}
            onChange={(v) => setGroup(v)}
            options={[
              { label: 'يومي', value: 'day' },
              { label: 'شهري', value: 'month' },
              { label: 'سنوي', value: 'year' },
            ]}
            style={{ width: '100%' }}
          />
        </Col>
      </Row>

      <Row gutter={[16, 16]}>
        <Col xs={24} md={12} xl={6}>
          <KpiCard title="إجمالي المستخدمين" value={usersStats?.total_users ?? 0} />
        </Col>
        <Col xs={24} md={12} xl={6}>
          <KpiCard title="إجمالي المواعيد" value={appointmentsStats?.total ?? 0} />
        </Col>
        <Col xs={24} md={12} xl={6}>
          <KpiCard title="المواعيد القادمة" value={appointmentsStats?.upcoming ?? 0} />
        </Col>
        <Col xs={24} md={12} xl={6}>
          <KpiCard title="إجمالي التحويلات" value={transfersStats?.total_transfers ?? 0} />
        </Col>
        <Col xs={24} md={12} xl={6}>
          <KpiCard title="غرف المحادثة" value={chatStats?.total_rooms ?? 0} />
        </Col>
        <Col xs={24} md={12} xl={6}>
          <KpiCard title="إجمالي الرسائل" value={chatStats?.total_messages ?? 0} />
        </Col>
        <Col xs={24} md={12} xl={6}>
          <KpiCard title="الإشعارات المرسلة" value={notificationsStats?.total_notifications ?? 0} />
        </Col>
        <Col xs={24} md={12} xl={6}>
          <KpiCard title="الأجهزة النشطة" value={notificationsStats?.total_active_devices ?? 0} />
        </Col>
      </Row>

      <Row gutter={[16, 16]} style={{ marginTop: 8 }}>
        <Col xs={24} xl={12}>
          <Card className="glass-card" title="المستخدمون حسب الدور">
            <Table
              size="small"
              dataSource={rolesRows}
              pagination={false}
              columns={[
                { title: 'الدور', dataIndex: 'role' },
                { title: 'العدد', dataIndex: 'count' },
              ]}
            />
          </Card>
        </Col>
        <Col xs={24} xl={12}>
          <Card className="glass-card" title="التحويلات حسب الفترة">
            <Table
              size="small"
              dataSource={transferRows}
              pagination={{ pageSize: 8 }}
              columns={[
                { title: 'الفترة', dataIndex: 'period' },
                { title: 'عدد التحويلات', dataIndex: 'count' },
              ]}
            />
          </Card>
        </Col>
      </Row>
    </div>
  );
}
