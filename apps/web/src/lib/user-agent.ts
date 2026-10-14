/** Short "Chrome on macOS" label for a session user agent. */
export function describeUserAgent(agent: string | null) {
  if (!agent) return "Unknown browser or device";
  const browser = /Edg\//.test(agent)
    ? "Edge"
    : /Chrome\//.test(agent)
      ? "Chrome"
      : /Firefox\//.test(agent)
        ? "Firefox"
        : /Safari\//.test(agent)
          ? "Safari"
          : null;
  const os = /iPhone|iPad/.test(agent)
    ? "iOS"
    : /Android/.test(agent)
      ? "Android"
      : /Mac OS X/.test(agent)
        ? "macOS"
        : /Windows/.test(agent)
          ? "Windows"
          : /Linux/.test(agent)
            ? "Linux"
            : null;
  return browser || os ? [browser, os].filter(Boolean).join(" on ") : agent.slice(0, 60);
}
