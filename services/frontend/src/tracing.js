import { init } from '@dash0/sdk-web';

// Browser telemetry: page views, navigation timing, web vitals, uncaught errors, and
// a span per fetch/XHR with traceparent propagated to the backend.
//
// Telemetry is sent to this app's own origin, not the Dash0 ingress. nginx proxies it
// to the collector, so no ingest token ships in the JS bundle and browser signals go
// through the same pipeline as the backends -- reaching Jaeger and OpenSearch too.
//
// The `/telemetry` prefix is load-bearing: the SDK skips instrumenting any request
// whose URL starts with an endpoint URL (isTransportRequest), so a bare-origin
// endpoint silently suppresses spans and propagation for every same-origin call.
//
// Set REACT_APP_DASH0_URL + REACT_APP_DASH0_AUTH_TOKEN to send straight to Dash0
// instead, accepting that the token becomes public.
const url = process.env.REACT_APP_DASH0_URL || `${window.location.origin}/telemetry`;
const authToken =
  process.env.REACT_APP_DASH0_AUTH_TOKEN || 'collector-does-not-authenticate';

init({
  serviceName: 'frontend',
  // Matches the backend services so Dash0 groups all four in one namespace.
  serviceNamespace: 'default',
  serviceVersion: '1.0.0',
  endpoint: {
    // The SDK appends /v1/traces and /v1/logs, so this must exclude /v1/*.
    url,
    // Required by the SDK's types; the collector's OTLP receiver does not authenticate.
    authToken,
  },
  // No `propagators` entry: traceparent is always sent on same-origin requests, and
  // every call this app makes is same-origin through its own nginx.
});
