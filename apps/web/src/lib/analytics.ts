import { appMode } from "@/lib/app-config";
import {
  buildAnalyticsEnvelope,
  type AnalyticsEnvelope,
  type AnalyticsEventName,
  type AnalyticsPropertyMap,
} from "@/lib/analytics-schema";

export type AnalyticsSink = (event: AnalyticsEnvelope) => void;

let sink: AnalyticsSink = (event) => {
  if (typeof window !== "undefined") {
    window.dispatchEvent(new CustomEvent("savestream:analytics", { detail: event }));
  }
};

export function setAnalyticsSink(next: AnalyticsSink) {
  sink = next;
}

export function trackEvent<Name extends AnalyticsEventName>(
  event: Name,
  properties: AnalyticsPropertyMap[Name],
) {
  sink(buildAnalyticsEnvelope(appMode, event, properties));
}
