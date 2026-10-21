// No "@/..." imports: the auth audit unit-tests this module with plain node.

/** A GET that has not answered by then is abandoned and tried once more. */
export const GET_TIMEOUT_MS = 15_000;
export const GET_TIMEOUT_RETRIES = 1;

export class RequestTimeoutError extends Error {
  readonly attempts: number;

  constructor(timeoutMs: number, attempts: number) {
    super(`Request timed out after ${attempts} × ${timeoutMs / 1000}s`);
    this.name = "RequestTimeoutError";
    this.attempts = attempts;
  }
}

type FetchLike = (input: string, init?: RequestInit) => Promise<Response>;

/**
 * fetch() with a time limit for the response headers, retried on timeout.
 *
 * QA latency report (2026-10-16): a request stalled 30 s on a dead browser
 * connection before reaching the API. Only use it for requests that are safe
 * to send twice (GET); never for POST such as the token refresh, which
 * rotates the refresh cookie.
 */
export async function fetchWithTimeout(
  fetchImpl: FetchLike,
  url: string,
  init: RequestInit = {},
  { timeoutMs = GET_TIMEOUT_MS, retries = GET_TIMEOUT_RETRIES } = {},
): Promise<Response> {
  const callerSignal = init.signal ?? undefined;
  for (let attempt = 0; ; attempt += 1) {
    if (callerSignal?.aborted)
      throw callerSignal.reason ?? new DOMException("Aborted", "AbortError");
    const controller = new AbortController();
    let timedOut = false;
    const onCallerAbort = () => controller.abort(callerSignal?.reason);
    callerSignal?.addEventListener("abort", onCallerAbort, { once: true });
    const timer = setTimeout(() => {
      timedOut = true;
      controller.abort();
    }, timeoutMs);
    try {
      return await fetchImpl(url, { ...init, signal: controller.signal });
    } catch (error) {
      if (!timedOut || callerSignal?.aborted) throw error;
      if (attempt < retries) continue;
      throw new RequestTimeoutError(timeoutMs, attempt + 1);
    } finally {
      clearTimeout(timer);
      callerSignal?.removeEventListener("abort", onCallerAbort);
    }
  }
}
