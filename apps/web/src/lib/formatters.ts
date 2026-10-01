import type { Language } from "@/lib/preferences";

export const localeFor = (language: Language) => (language === "vi" ? "vi-VN" : "en-US");

export function formatNumber(value: number, language: Language, options?: Intl.NumberFormatOptions) {
  return new Intl.NumberFormat(localeFor(language), options).format(value);
}

export function formatCurrencyUsd(value: number, language: Language) {
  return new Intl.NumberFormat(localeFor(language), {
    style: "currency",
    currency: "USD",
    minimumFractionDigits: value % 1 === 0 ? 0 : 2,
    maximumFractionDigits: 2,
  }).format(value);
}

export function formatDate(
  value: string | Date,
  language: Language,
  options: Intl.DateTimeFormatOptions = { year: "numeric", month: "short", day: "numeric" },
) {
  const date = value instanceof Date ? value : new Date(value);
  if (Number.isNaN(date.getTime())) return String(value);
  return new Intl.DateTimeFormat(localeFor(language), options).format(date);
}

export function formatDateTime(value: string | Date, language: Language) {
  return formatDate(value, language, {
    year: "numeric",
    month: "short",
    day: "numeric",
    hour: "2-digit",
    minute: "2-digit",
  });
}

export function formatStorageGb(value: number, language: Language) {
  return `${formatNumber(value, language, { maximumFractionDigits: 1 })} GB`;
}

export function formatRecordingHours(value: number, language: Language) {
  const number = formatNumber(value, language, { maximumFractionDigits: 1 });
  return language === "vi" ? `${number} giờ ghi hình` : `${number} recording hours`;
}

export function formatDurationMinutes(minutes: number, language: Language) {
  if (minutes < 60) {
    return language === "vi" ? `${formatNumber(minutes, language)} phút` : `${formatNumber(minutes, language)} min`;
  }
  const hours = Math.floor(minutes / 60);
  const remaining = minutes % 60;
  if (!remaining) {
    return language === "vi" ? `${hours} giờ` : `${hours} h`;
  }
  return language === "vi" ? `${hours} giờ ${remaining} phút` : `${hours} h ${remaining} min`;
}
