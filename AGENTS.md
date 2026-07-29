# Agent instructions

Context for coding agents working in this repo. `README.md` covers how to run the
demo; this file covers what you need to know before changing it.

## What this is

A demo of platform engineering with OpenTelemetry, running on a local kind
cluster. The narrative is self-service observability: a developer scaffolds a new
service through Backstage and it arrives instrumented, with logs, metrics, traces
and a dashboard, without touching any observability config by hand.

Telemetry goes to Dash0 (via OTLP) and, in parallel, to local sinks so the demo
works offline and the pipeline is inspectable: Prometheus (metrics), Jaeger
(traces), OpenSearch (logs), Perses (dashboards).

Because it is a demo, the audience-facing moments matter more than internal
tidiness. A dashboard panel rendering "no data" in front of a room is a worse
failure than an ugly config.

## Layout

| Path | What it is |
|---|---|
| `00_run.sh` | Full setup, 9 numbered steps, delegates to `scripts/0N_*.sh` |
| `01_start-demo.sh` | Port-forwards + starts Backstage (`yarn start`) |
| `02_cleanup.sh` | Deletes the kind cluster and removes scaffolded services |
| `scripts/` | Numbered step scripts; unnumbered = shared helper (e.g. `deploy_cert_manager.sh`) |
| `infrastructure/` | Helm values and manifests for the platform components |
| `services/` | Application services (frontend, todo-service, notification-service) |
| `backstage/` | Backstage app, including the scaffolder templates |
| `cluster/kind/` | kind cluster topology |

`00_run.sh --skip-completed` skips steps whose resources already exist. Step
scripts are expected to be idempotent and are run from the repo root.

## The scaffolder is the source of truth

`services/validation-service/` is **generated output and is gitignored**. It is
created live during the demo by the Backstage scaffolder and deliberately removed
by `02_cleanup.sh` so the repo is clean for the next run.

The source is the template:

```
backstage/examples/nodejs-validation-template/
├── template.yaml
└── content/            <- skeleton, this is what you edit
    ├── manifests/
    ├── dashboards/
    └── deploy.sh
```

**Any fix that should apply to scaffolded services must go in the template.**
Fixing only `services/validation-service/` is worthless — it is wiped on cleanup
and regenerated from the template. If you fix a bug in a scaffolded service, ask
whether the template has the same bug; it usually does.

Backstage reads the template from the local working tree, so template edits take
effect on the next scaffold without pushing anywhere.

The scaffolded service is deployed by its own `deploy.sh` (build → `kind load` →
apply manifests → apply dashboards), not by `00_run.sh`.

## Version policy: track latest, do not pin to old

The demo intentionally tracks current upstream versions. Do not "fix" a breakage
by pinning to an older version unless there is no alternative — prefer making the
demo work with current versions.

Consequence: upstream changes break this repo over time, and the breakages tend
to be *version skew* — a floating chart or operator driving a pinned image, or a
pinned query against floating instrumentation. When something breaks, suspect skew
first.

Known deliberate pins:

- `scripts/06_deploy_observability.sh` pins the Jaeger chart to `3.4.1`. Moving to
  4.x is a Jaeger v1 → v2 migration: the values schema was rewritten (`allInOne`,
  `agent`, `collector`, `query` all replaced by a single `jaeger` block) and the
  config model changed. This needs a real migration, not a version bump.
- `scripts/09_deploy_perses.sh` pins the perses-operator kustomize ref.

Where a chart's `appVersion` should drive the image, do not override the image
tag. `infrastructure/opensearch/values.yaml` deliberately has no `image.tag` for
this reason — an override there previously held OpenSearch at 2.14.0 under a 3.x
chart.

## Dash0 gets full fidelity; workarounds belong at the sink

**Principle: never degrade what the pipeline collects to accommodate a local demo
sink.** Dash0 is the primary, OTel-native destination. Prometheus, Jaeger and
OpenSearch are secondary sinks that exist so the demo works offline and the
pipeline is inspectable. If a sink cannot represent the data, fix it on that
sink's branch — do not reduce what is extracted.

The worked example is the logs pipeline. OpenSearch splits attribute names on `.`
into nested objects, so a pod labelled `app` and a pod labelled
`app.kubernetes.io/name` both map to `resource.app` — once as a value, once as an
object. Whichever indexes first wins the dynamic mapping and the other shape is
rejected permanently with `mapper_parsing_exception`, silently dropping those
pods' logs. Third-party charts using a bare `app` label (cert-manager, kindnet,
local-path-provisioner) make this unavoidable.

Things that do **not** work, all verified empirically — don't spend time
re-deriving them:

- Turning off `extractAllPodLabels` fixes OpenSearch but strips the labels from
  Dash0 too, because both exporters shared one pipeline. Wrong trade.
- Renaming to `k8s.pod.label.<key>` (the stable semantic convention) just
  relocates the collision to `resource.k8s.pod.label.app`.
- OpenSearch does not support `subobjects: false` (an Elasticsearch 8.x feature
  added after the fork).
- OpenSearch's `flat_object` accepts both shapes, but terms aggregations on its
  subfields return corrupted buckets (`java.lang.Object@69635469`), which breaks
  querying logs by pod.

What is in place instead: the logs pipeline forks with a `forward` connector.

```
logs             -> otlp/dash0, forward/opensearch     (full resource)
logs/opensearch  -> resource/opensearch-compat -> opensearch/log
```

`resource/opensearch-compat` deletes only the bare `app` key, on the OpenSearch
branch only. Dash0 receives every label and annotation untouched.

Two things to preserve when editing this:

- **Keep `logs` as the primary pipeline.** The chart's presets inject extra
  receivers (`filelog` on the daemonset, `k8sobjects` on the deployment) and the
  `k8s_attributes` processor into it. A hand-declared second pipeline does *not*
  get them, which silently stops file-based pod logs reaching that branch and
  drops all `k8s.*` enrichment. The connector exists specifically so the
  OpenSearch branch inherits whatever the presets add.
- **Never add `resource/opensearch-compat` to the Dash0 pipeline.**

If a new collision appears, add the offending bare key to that processor.

## Two semantic-convention generations coexist

The Java and Node.js auto-instrumentations are at different semconv versions.
This is real and load-bearing for dashboards — do not "normalise" query names
across runtimes:

| | Java (todo, notification) | Node.js (validation) |
|---|---|---|
| HTTP server | `http_server_request_duration_seconds_*` | `http_server_duration_milliseconds_*` |
| Status code label | `http_response_status_code` | `http_status_code` |
| Runtime memory | `jvm_memory_used_bytes` | `v8js_memory_heap_used_bytes` |

Note the unit difference (seconds vs milliseconds) — it affects panel units, not
just names.

## Verify against the cluster, never from memory

Metric names, label names and API paths in this repo have all drifted from what
the code assumes at least once. Before claiming a query, dashboard or metric
works, confirm it against the running cluster.

```bash
# metric exists / how many series
kubectl port-forward -n default svc/prometheus 9090:9090
curl -s 'localhost:9090/api/v1/query?query=<metric>'
curl -s 'localhost:9090/api/v1/label/__name__/values'   # all metric names

# logs actually landing, by pod
kubectl exec -n default opensearch-cluster-master-0 -- curl -sk \
  -u admin:'SecureP@ssw0rd123' \
  'https://localhost:9200/ss4o_logs-default-namespace/_search?size=0' \
  -H 'Content-Type: application/json' \
  -d '{"aggs":{"pods":{"terms":{"field":"resource.k8s.pod.name.keyword","size":30}}}}'

# collector export failures (see gotchas for the workload name)
kubectl logs -n opentelemetry daemonset/otel-collector-agent --all-containers \
  | grep -E 'mapper_parsing_exception|Exporting failed'
```

A dashboard "fix" is not done until every query on it returns a non-zero series
count against live data.

## Gotchas that have cost time

- The daemonset collector is named **`otel-collector-agent`**, not
  `otel-collector` (the chart appends `-agent` despite `fullnameOverride`). Piping
  `kubectl logs daemonset/otel-collector` into `grep -c` silently reports 0
  because the command errors — a vacuous pass that looks like a clean result.
- Jaeger's API is under a base path: `/jaeger/ui/api/services`, not `/api/services`.
- The Prometheus service is `prometheus:9090` (not `prometheus-server:80`).
- `todo-service` listens on `3000`, path `/todos`, and the field is `name` (not
  `title`). `validation-service` listens on `3001`.
- Operators here front admission webhooks whose readiness probes cover a health
  port, not the webhook port — so `kubectl wait --for=condition=available` can
  return before the webhook accepts connections. Poll the actual apply rather than
  sleeping a fixed amount.
- cert-manager must exist before the RabbitMQ operator (its manifest ships
  `Certificate`/`Issuer` since v2.22.0) and before the OpenTelemetry operator.
  `scripts/deploy_cert_manager.sh` is idempotent and called by both steps.
- On macOS, `sed -i ''` and BSD `sed` has no `\s` — use `[[:space:]]`.

## Cleanup

```bash
./02_cleanup.sh                     # cluster + scaffolded services
./02_cleanup.sh --keep-scaffolded   # cluster only, keep scaffolded code on disk
```

**Never use `git clean -fdX` to reset this repo.** `services/validation-service`
is gitignored, which makes it tempting, but the same command also deletes `.env`
(your Dash0 credentials), `backstage/node_modules/`,
`backstage/app-config.local.yaml`, and the Gradle wrapper jar.

Deleting the cluster removes the scaffolded workloads with it — Deployment,
Service and `PersesDashboard` all live in the cluster. The Backstage catalog entry
lives in Backstage's own database, not the repo, and is not removed.
