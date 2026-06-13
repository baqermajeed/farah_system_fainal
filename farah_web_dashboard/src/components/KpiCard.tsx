import { Button, Card, Statistic, Tooltip } from 'antd';
import { motion } from 'framer-motion';

type KpiCardProps = {
  title: string;
  value: number | string;
  suffix?: string;
  actionIcon?: React.ReactNode;
  actionTooltip?: string;
  onActionClick?: () => void;
};

export function KpiCard({ title, value, suffix, actionIcon, actionTooltip, onActionClick }: KpiCardProps) {
  return (
    <motion.div whileHover={{ y: -6, rotateX: 3 }} transition={{ type: 'spring', stiffness: 220, damping: 16 }}>
      <Card className="glass-card kpi-card-premium" styles={{ body: { padding: 16 } }}>
        <div style={{ position: 'relative' }}>
          {actionIcon && onActionClick ? (
            <Tooltip title={actionTooltip ?? ''}>
              <Button
                type="text"
                className="stat-action-btn"
                icon={actionIcon}
                onClick={onActionClick}
                style={{ position: 'absolute', top: -6, left: -6, zIndex: 1 }}
              />
            </Tooltip>
          ) : null}
          <Statistic title={title} value={value} suffix={suffix} />
        </div>
      </Card>
    </motion.div>
  );
}
