# C2 — Local recording technical spike

Status: in progress. This document records evidence only; C2 does not ship a product feature.

## Slice 1 — Direct stream download probe

### What the current backend proves

- `backend/src/core/tiktok_api.py::get_live_url()` prefers the highest-quality
  `main.flv` URL from TikTok's `live_core_sdk_data.pull_data.stream_data`.
- The legacy fallback also prefers `flv_pull_url` variants before falling back
  to RTMP.
- `download_live_stream()` performs a streaming HTTP GET and yields 4096-byte
  chunks to the recording engine.
- The backend deliberately uses its browser-impersonated `HttpClient` for the
  stream download. Its source comment says TikTok's pull CDN blocked plain
  `requests` because it lacked the expected TLS fingerprint and produced
  zero-byte recordings.

This is strong evidence that the first mobile experiment must test FLV over
direct HTTP, and must explicitly record whether Dart/OS networking is accepted
by the CDN. It is not evidence that Dart `HttpClient` will work.

The repository does **not** currently establish:

- how long a TikTok pull URL remains valid;
- which request headers, cookies, or TLS fingerprint are strictly required on
  Android or iOS;
- whether the same URL can be resumed after an interrupted connection.

Those points require a real-device/live-stream run.

### Probe added for the experiment

`apps/mobile/tool/spike_local_recording/` contains an isolated Dart CLI. It is
not wired into the Flutter app or release build.

Example:

```bash
dart run tool/spike_local_recording/bin/record_stream.dart \
  --url '<live-pull-url>' \
  --output build/c2/sample.flv \
  --seconds 60
```

Optional headers can be supplied repeatedly:

```bash
--header 'User-Agent:...' --header 'Referer:https://www.tiktok.com/'
```

The probe records:

- HTTP status;
- transport classification (FLV/HLS/RTMP/unknown);
- bytes written;
- elapsed time;
- bytes/second;
- MiB/minute;
- response content type.

A non-2xx response or a zero-byte response remains measurable evidence and
causes the CLI to exit non-zero.

### Next device evidence

Run the same pull URL on Android first, then iOS, with no custom headers and
then only with headers justified by captured backend behavior. Record whether
the CDN rejects the native Dart TLS/client fingerprint. Do not add bypass or
production integration in C2.
