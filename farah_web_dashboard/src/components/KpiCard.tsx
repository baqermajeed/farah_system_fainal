import { Card, Statistic } from 'antd';
import { motion } from 'framer-motion';

type KpiCardProps = {
  title: string;
  value: number | string;
  suffix?: string;
};

export function KpiCard({ title, value, suffix }: KpiCardProps) {
  return (
    <motion.div whileHover={{ y: -6, rotateX: 3 }} transition={{ type: 'spring', stiffness: 220, damping: 16 }}>
      <Card className="glass-card kpi-card-premium" styles={{ body: { padding: 16 } }}>
        <Statistic title={title} value={value} suffix={suffix} />
      </Card>
    </motion.div>
  );
}
