import { Col, Input, Row, Spin, Typography } from 'antd';
import { useEffect, useMemo, useState } from 'react';
import { useNavigate } from 'react-router-dom';
import { Doctor3DCard } from '../components/Doctor3DCard';
import { fetchDoctorsStats } from '../services/statsApi';
import type { DoctorStatsListResponse } from '../types/stats';

export function DoctorsGalleryPage() {
  const [loading, setLoading] = useState(true);
  const [doctors, setDoctors] = useState<DoctorStatsListResponse['doctors']>([]);
  const [query, setQuery] = useState('');
  const navigate = useNavigate();

  useEffect(() => {
    const load = async () => {
      try {
        setLoading(true);
        const response = await fetchDoctorsStats();
        setDoctors(response.doctors);
      } catch (error) {
        console.error('Failed to load doctors gallery', error);
        setDoctors([]);
      } finally {
        setLoading(false);
      }
    };
    void load();
  }, []);

  const filtered = useMemo(() => {
    const q = query.trim().toLowerCase();
    if (!q) return doctors;
    return doctors.filter(
      (doctor) =>
        (doctor.name ?? '').toLowerCase().includes(q) ||
        (doctor.phone ?? '').toLowerCase().includes(q),
    );
  }, [doctors, query]);

  if (loading) return <Spin size="large" />;

  return (
    <div className="page-wrap">
      <Typography.Title level={3}>عرض الأطباء (مطابق أسلوب التطبيق السابق)</Typography.Title>
      <Typography.Paragraph type="secondary">
        كروت صور الأطباء، وعند الضغط على أي طبيب تنتقل مباشرة إلى صفحة التفاصيل الكاملة.
      </Typography.Paragraph>

      <Input.Search
        placeholder="ابحث باسم الطبيب أو الهاتف..."
        allowClear
        value={query}
        onChange={(event) => setQuery(event.target.value)}
        className="premium-search"
      />

      <Row gutter={[16, 16]}>
        {filtered.map((doctor) => (
          <Col xs={24} sm={12} lg={8} xl={6} key={doctor.doctor_id}>
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
    </div>
  );
}
