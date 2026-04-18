import logging
import sys
from pathlib import Path
from logging.handlers import RotatingFileHandler
from app.config import get_settings

settings = get_settings()

# Create logs directory if it doesn't exist
logs_dir = Path("logs")
logs_dir.mkdir(exist_ok=True)

# Configure root logger
logger = logging.getLogger("clinic_api")
logger.setLevel(logging.DEBUG if settings.APP_DEBUG else logging.INFO)

# Prevent duplicate logs
if logger.handlers:
    logger.handlers.clear()

# Console handler with colored output
console_handler = logging.StreamHandler(sys.stdout)
console_handler.setLevel(logging.DEBUG if settings.APP_DEBUG else logging.INFO)
console_format = logging.Formatter(
    '%(asctime)s - %(name)s - %(levelname)s - %(message)s',
    datefmt='%Y-%m-%d %H:%M:%S'
)
console_handler.setFormatter(console_format)
logger.addHandler(console_handler)

# File handler with rotation
file_handler = RotatingFileHandler(
    logs_dir / "app.log",
    maxBytes=10 * 1024 * 1024,  # 10MB
    backupCount=5
)
file_handler.setLevel(logging.INFO)
file_format = logging.Formatter(
    '%(asctime)s - %(name)s - %(levelname)s - %(funcName)s:%(lineno)d - %(message)s',
    datefmt='%Y-%m-%d %H:%M:%S'
)
file_handler.setFormatter(file_format)
logger.addHandler(file_handler)

# Error file handler
error_handler = RotatingFileHandler(
    logs_dir / "errors.log",
    maxBytes=10 * 1024 * 1024,  # 10MB
    backupCount=5
)
error_handler.setLevel(logging.ERROR)
error_handler.setFormatter(file_format)
logger.addHandler(error_handler)

def get_logger(name: str = None) -> logging.Logger:
    """Get a logger instance. If name is provided, returns a child logger."""
    if name:
        return logger.getChild(name)
    return logger

