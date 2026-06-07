import { motion } from 'framer-motion';

export function AuroraBackground() {
  return (
    <div className="aurora-bg" aria-hidden>
      <motion.span
        className="aurora-blob blob-1"
        animate={{ x: [0, 40, -20, 0], y: [0, -20, 30, 0], rotate: [0, 25, -15, 0] }}
        transition={{ duration: 18, repeat: Infinity, ease: 'easeInOut' }}
      />
      <motion.span
        className="aurora-blob blob-2"
        animate={{ x: [0, -35, 25, 0], y: [0, 30, -25, 0], rotate: [0, -20, 20, 0] }}
        transition={{ duration: 22, repeat: Infinity, ease: 'easeInOut' }}
      />
      <motion.span
        className="aurora-blob blob-3"
        animate={{ scale: [1, 1.08, 0.96, 1], x: [0, 25, -10, 0] }}
        transition={{ duration: 16, repeat: Infinity, ease: 'easeInOut' }}
      />
    </div>
  );
}
