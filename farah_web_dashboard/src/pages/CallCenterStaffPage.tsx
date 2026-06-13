import { Button, Card, Col, Empty, Row, Spin, Typography } from 'antd';
import { useEffect, useState } from 'react';
import { motion } from 'framer-motion';
import { useNavigate } from 'react-router-dom';
import { fetchCallCenterStaffFromBoth } from '../services/statsApi';
import type { StaffUser } from '../types/stats';

export function CallCenterStaffPage() {
  const navigate = useNavigate();
  const [loading, setLoading] = useState(true);
  const [staff, setStaff] = useState<StaffUser[]>([]);

  useEffect(() => {
    const load = async () => {
      try {
        setLoading(true);
        const data = await fetchCallCenterStaffFromBoth();
        setStaff(data);
      } catch (error) {
        console.error('Failed to load call center staff', error);
        setStaff([]);
      } finally {
        setLoading(false);
      }
    };
    void load();
  }, []);

  if (loading) return <Spin size="large" />;

  return (
    <div className="page-wrap">
      <Typography.Title level={3}>موظفي الكول سنتر</Typography.Title>
      <Typography.Paragraph type="secondary">
        عرض جميع موظفي مركز الاتصالات المسجلين في النظام.
      </Typography.Paragraph>

      {staff.length === 0 ? (
        <Card className="glass-card">
          <Empty description="لا يوجد موظفين كول سنتر" />
        </Card>
      ) : (
        <Row gutter={[16, 16]}>
          {staff.map((member) => (
            <Col xs={24} sm={12} lg={8} xl={6} key={member.id}>
              <motion.div
                whileHover={{ y: -8, rotateX: 4, rotateY: -4 }}
                transition={{ type: 'spring', stiffness: 220, damping: 16 }}
                style={{ transformStyle: 'preserve-3d', perspective: 1200 }}
                className="doctor-card-3d"
              >
                <Card className="doctor-card-glass" styles={{ body: { padding: 16 } }}>
                  <div className="doctor-image-wrap">
                    <img
                      src={member.imageUrl ?? 'https://placehold.co/600x400?text=Call+Center'}
                      alt={member.name ?? 'call center staff'}
                      className="doctor-image"
                    />
                  </div>

                  <div style={{ marginTop: 12 }}>
                    <Typography.Title level={5} style={{ margin: 0 }}>
                      {member.name ?? 'موظف كول سنتر'}
                    </Typography.Title>
                    <Typography.Text type="secondary">{member.phone}</Typography.Text>
                  </div>

                  <Button
                    style={{ marginTop: 12 }}
                    type="primary"
                    block
                    onClick={() => navigate(`/call-center/${member.id}`, { state: { member } })}
                  >
                    عرض التفاصيل
                  </Button>
                </Card>
              </motion.div>
            </Col>
          ))}
        </Row>
      )}

    </div>
  );
}
