import { DatePicker, Select } from 'antd';
import dayjs from 'dayjs';
import type { Dayjs } from 'dayjs';
import type { CSSProperties } from 'react';
import { useEffect, useState } from 'react';

const BOOKING_HOURS = Array.from({ length: 13 }, (_, index) => index + 8);

function formatHour12(hour: number) {
  return dayjs().hour(hour).minute(0).format('h:mm A');
}

type DateRangeValue = [Dayjs | null, Dayjs | null];

function toDateInputValue(value: Dayjs | null): string {
  return value ? value.format('YYYY-MM-DD') : '';
}

function fromDateInputValue(value: string): Dayjs | null {
  return value ? dayjs(value) : null;
}

export function useIsMobileViewport() {
  const [isMobile, setIsMobile] = useState(false);

  useEffect(() => {
    if (typeof window === 'undefined') return;

    const media = window.matchMedia('(max-width: 767px)');
    const sync = () => setIsMobile(media.matches);
    sync();
    media.addEventListener('change', sync);

    return () => {
      media.removeEventListener('change', sync);
    };
  }, []);

  return isMobile;
}

type AdaptiveDateRangePickerProps = {
  value: DateRangeValue;
  onChange: (value: DateRangeValue) => void;
  allowEmpty?: [boolean, boolean];
  style?: CSSProperties;
  disabled?: boolean;
  getPopupContainer?: (trigger: HTMLElement) => HTMLElement;
};

export function AdaptiveDateRangePicker({
  value,
  onChange,
  allowEmpty,
  style,
  disabled,
  getPopupContainer,
}: AdaptiveDateRangePickerProps) {
  const isMobile = useIsMobileViewport();

  if (!isMobile) {
    return (
      <DatePicker.RangePicker
        value={value}
        onChange={(next) => onChange([next?.[0] ?? null, next?.[1] ?? null])}
        allowEmpty={allowEmpty}
        style={style}
        disabled={disabled}
        getPopupContainer={getPopupContainer}
      />
    );
  }

  return (
    <div className="adaptive-date-range-mobile" style={style}>
      <input
        className="adaptive-date-input"
        type="date"
        disabled={disabled}
        value={toDateInputValue(value[0])}
        onChange={(event) => {
          const nextStart = fromDateInputValue(event.target.value);
          const currentEnd = value[1];
          const nextEnd = currentEnd && nextStart && nextStart.isAfter(currentEnd, 'day') ? nextStart : currentEnd;
          onChange([nextStart, nextEnd]);
        }}
      />
      <input
        className="adaptive-date-input"
        type="date"
        disabled={disabled}
        value={toDateInputValue(value[1])}
        onChange={(event) => {
          const nextEnd = fromDateInputValue(event.target.value);
          const currentStart = value[0];
          const nextStart = currentStart && nextEnd && nextEnd.isBefore(currentStart, 'day') ? nextEnd : currentStart;
          onChange([nextStart, nextEnd]);
        }}
      />
    </div>
  );
}

type AdaptiveDatePickerProps = {
  value: Dayjs | null;
  onChange: (value: Dayjs | null) => void;
  style?: CSSProperties;
};

export function AdaptiveDatePicker({ value, onChange, style }: AdaptiveDatePickerProps) {
  const isMobile = useIsMobileViewport();

  if (!isMobile) {
    return <DatePicker value={value} onChange={(next) => onChange(next)} style={style} />;
  }

  return (
    <input
      className="adaptive-date-input"
      type="date"
      style={style}
      value={toDateInputValue(value)}
      onChange={(event) => {
        onChange(fromDateInputValue(event.target.value));
      }}
    />
  );
}

type AdaptiveDateTimePickerProps = {
  value?: Dayjs | null;
  onChange?: (value: Dayjs | null) => void;
  style?: CSSProperties;
  getPopupContainer?: (trigger: HTMLElement) => HTMLElement;
  disabledTime?: () => {
    disabledHours?: () => number[];
    disabledMinutes?: (hour: number) => number[];
  };
  format?: string;
  showTime?: unknown;
};

/** على الموبايل: تاريخ أصلي + قائمة ساعات (08–20) بدل دايلوك Ant العريض */
export function AdaptiveDateTimePicker({
  value = null,
  onChange,
  style,
  getPopupContainer,
  disabledTime,
  format = 'YYYY-MM-DD h:mm A',
}: AdaptiveDateTimePickerProps) {
  const isMobile = useIsMobileViewport();

  if (!isMobile) {
    return (
      <DatePicker
        value={value}
        onChange={(next) => onChange?.(next)}
        showTime={{ format: 'h:mm A', use12Hours: true, hideDisabledOptions: true }}
        disabledTime={disabledTime}
        format={format}
        style={{ width: '100%', ...style }}
        getPopupContainer={getPopupContainer}
      />
    );
  }

  const dateValue = toDateInputValue(value);
  const hourValue = value?.isValid() ? value.hour() : undefined;

  const mergeDateAndHour = (nextDate: Dayjs | null, nextHour: number | undefined) => {
    if (!nextDate) {
      onChange?.(null);
      return;
    }
    const hour = nextHour ?? (hourValue != null && hourValue >= 8 && hourValue <= 20 ? hourValue : 9);
    onChange?.(nextDate.hour(hour).minute(0).second(0).millisecond(0));
  };

  return (
    <div className="adaptive-datetime-mobile" style={style}>
      <input
        className="adaptive-date-input"
        type="date"
        value={dateValue}
        onChange={(event) => {
          mergeDateAndHour(fromDateInputValue(event.target.value), hourValue);
        }}
      />
      <Select
        className="adaptive-time-select"
        placeholder="اختر الوقت"
        value={hourValue != null && hourValue >= 8 && hourValue <= 20 ? hourValue : undefined}
        options={BOOKING_HOURS.map((hour) => ({
          value: hour,
          label: formatHour12(hour),
        }))}
        onChange={(hour) => {
          const base = value?.isValid() ? value : dayjs().startOf('day');
          mergeDateAndHour(base, hour);
        }}
        getPopupContainer={getPopupContainer}
      />
    </div>
  );
}
