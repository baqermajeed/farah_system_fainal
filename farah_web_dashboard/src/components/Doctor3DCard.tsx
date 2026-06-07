import { Badge, Button, Card, Tag, Typography } from 'antd';
import { motion } from 'framer-motion';
import type { DoctorComparison, DoctorBasic } from '../types/stats';

type Doctor3DCardProps = {
  doctor: DoctorBasic | DoctorComparison;
  stats?: {
    patients?: number;
    appointments?: number;
    completed?: number;
  };
  onOpen: () => void;
};

export function Doctor3DCard({ doctor, stats, onOpen }: Doctor3DCardProps) {
  return (
    <motion.div
      whileHover={{ y: -8, rotateX: 4, rotateY: -4 }}
      transition={{ type: 'spring', stiffness: 220, damping: 16 }}
      style={{ transformStyle: 'preserve-3d', perspective: 1200 }}
      className="doctor-card-3d"
      onClick={onOpen}
      role="button"
      tabIndex={0}
      onKeyDown={(event) => {
        if (event.key === 'Enter' || event.key === ' ') {
          event.preventDefault();
          onOpen();
        }
      }}
    >
      <Card className="doctor-card-glass" styles={{ body: { padding: 16 } }}>
        <div className="doctor-image-wrap">
          <img
            src={doctor.imageUrl ?? 'https://placehold.co/600x400?text=Doctor'}
            alt={doctor.name ?? 'doctor'}
            className="doctor-image"
          />
          {'is_manager' in doctor && doctor.is_manager ? (
            <Tag className="doctor-tag" color="gold">
              طبيب مدير
            </Tag>
          ) : null}
        </div>

        <div style={{ marginTop: 12 }}>
          <Typography.Title level={5} style={{ margin: 0 }}>
            {doctor.name ?? 'طبيب'}
          </Typography.Title>
          <Typography.Text type="secondary">{doctor.phone ?? '-'}</Typography.Text>
        </div>

        <div className="doctor-mini-stats">
          <Badge color="#00A79D" text={`مرضى: ${stats?.patients ?? ('patients' in doctor ? doctor.patients.total_current : '-')}`} />
          <Badge
            color="#3b82f6"
            text={`مواعيد: ${stats?.appointments ?? ('appointments' in doctor ? doctor.appointments.this_month : '-')}`}
          />
          <Badge
            color="#22c55e"
            text={`مكتملة: ${stats?.completed ?? ('appointments' in doctor ? doctor.appointments.completed_all_time : '-')}`}
          />
        </div>

        <Button
          type="primary"
          block
          onClick={(event) => {
            event.stopPropagation();
            onOpen();
          }}
        >
          تفاصيل الطبيب
        </Button>
      </Card>
    </motion.div>
  );
}
