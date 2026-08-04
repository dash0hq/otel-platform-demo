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
apply manifests → restart → apply dashboards), not by `00_run.sh`.

Note the restart step. The image tag is always `v1`, so on a re-deploy the
Deployment spec is byte-identical, `kubectl apply` is a no-op, and the pod keeps
running the *previous* image while the script cheerfully prints "deployed". The
script therefore records whether the Deployment already existed **before** the
apply, and restarts only in that case — a first deploy needs no restart, since the
apply itself creates the pod with the new image. If you edit `deploy.sh`, keep both
halves of that behaviour.

## Where dashboards come from

There are two paths, and they must not be confused:

| Dashboard | Applied by |
|---|---|
| `services/<name>/dashboards/` for services committed to this repo | `scripts/09_deploy_perses.sh` |
| Dashboards of services scaffolded through Backstage | that service's own `deploy.sh` |

Step 9 loops over `./services/*/dashboards`, guarded so it skips directories that
do not exist — on a fresh boot `services/validation-service/` has not been
scaffolded yet, and an unguarded glob fails the step.

If you fix a dashboard, confirm Perses actually serves it — read the query back out
of the API, not just the file:

```bash
kubectl port-forward -n default svc/perses 8000:8080
curl -s localhost:8000/api/v1/dashboards | jq '.[].metadata.name'
```

### PersesDashboard v1alpha1 vs v1alpha2 are not interchangeable

Both are served, so an old CR keeps working, but the spec shape differs — bumping
the `apiVersion` alone produces a CR rejected for a missing `config` field:

```
v1alpha1  spec: {duration, layouts, panels, display, datasources, ...}
v1alpha2  spec: {config: {<all of the above>}, instanceSelector: {...}}
```

`v1alpha2` is the storage version and everything in the repo now uses it. Copy the
structure from an existing v1alpha2 dashboard rather than hand-writing it.

## Services are discovered, not listed

`catalog.locations` in `app-config.yaml` deliberately does **not** list the services.
A custom entity provider —
`backstage/packages/backend/src/catalog/scaffoldedServicesProvider.ts`, registered in
`packages/backend/src/index.ts` — scans `services/*/catalog-info.yaml` every 10
seconds and emits one `Location` entity per file.

This is what makes the scaffolder demo work end to end: a service created in
Backstage appears in the catalog in about 10 seconds with no config edit and no
restart, and disappears again when `02_cleanup.sh` deletes the directory. Verified
in both directions. Do not "tidy up" by adding the services back to
`catalog.locations` — you would then have two sources for the same entity.

Two details matter if you touch it:

- It emits `Location` entities rather than parsed components, so Backstage's own
  file-location processor does the reading. That is why the multi-document
  `catalog-info.yaml` files (todo-service and notification-service each declare a
  Component plus APIs) work without any parsing in the provider.
- The mutation is `type: 'full'`, which is what makes deletions propagate. A
  `delta` mutation would leave removed services in the catalog forever.

Note that the backend database is `better-sqlite3` with `connection: ':memory:'`, so
anything registered only in Backstage's own DB — such as a `catalog:register`
scaffolder step — is lost on every restart. Scanning the filesystem sidesteps that
entirely.

## Infrastructure is in the catalog too

`infrastructure/catalog-info.yaml` declares the supporting infrastructure as
`Resource` entities — mysql, rabbitmq, otel-collector, dash0, opensearch,
prometheus, jaeger, perses and the kind cluster — all owned by `platform-team`.

It is registered **statically** in `catalog.locations`, unlike the services. That
split is deliberate: services appear and disappear during the demo so they are
scanned, while the deploy scripts fix what infrastructure exists. The install-time
operators (cert-manager, mysql-operator, opentelemetry-operator, RabbitMQ cluster
operator) are intentionally omitted — no service talks to them and they would just
add nodes to the dependency graph.

`spec.dependsOn` wires the graph: frontend → todo-service, notification-service,
collector; each Java service → mysql, rabbitmq, collector; todo-service →
validation-service; collector → dash0, opensearch, jaeger; jaeger and perses →
prometheus. Check for dangling references after editing, because Backstage accepts
a `dependsOn` pointing at nothing and simply renders a broken graph:

```bash
curl -s -H "Authorization: Bearer $TOKEN" \
  'http://localhost:7007/api/catalog/entities?fields=kind,metadata.name,metadata.namespace,spec.dependsOn'
```

Every component also carries a `metadata.links` entry to its Dash0 service page.
Use the `/goto/services/details?...&service_name=<name>` form, **not** a URL copied
from the browser: copied URLs carry an opaque `s=` parameter that is zlib-compressed
UI state, which cannot be generated inside a scaffolder template. The org id is
embedded in these URLs (it is an identifier, not a secret).

There is no CI/CD tab on the entity pages: with no CI in this demo it only rendered
an empty state.

## Service documentation (TechDocs)

Each service has `mkdocs.yml` plus `docs/{index,architecture,operations}.md`, and a
`backstage.io/techdocs-ref: dir:.` annotation in its `catalog-info.yaml`. The
validation-service copies live in the scaffolder template, so a freshly scaffolded
service arrives with its own docs — change them there, not only in
`services/validation-service/`.

Generation is `builder: local` + `generator.runIn: docker`, so the first docs view
pulls `spotify/techdocs` (~705 MB) and takes a while; every build after that is
sub-second. Pre-pull it before a live demo.

**Mermaid needs two independent pieces, and one without the other silently fails:**

1. `mkdocs.yml` must register the fence, because `techdocs-core` (1.6.1 in the
   image) does *not* do it by default — a ```mermaid block otherwise renders as a
   plain text code block (`<div class="language-text highlight">`):
   ```yaml
   markdown_extensions:
     - pymdownx.superfences:
         custom_fences:
           - name: mermaid
             class: mermaid
             format: !!python/name:pymdownx.superfences.fence_code_format
   ```
2. `backstage-plugin-techdocs-addon-mermaid` must be added as `<Mermaid />` in
   **both** `packages/app/src/App.tsx` and
   `packages/app/src/components/catalog/EntityPage.tsx` — the standalone docs route
   and the entity Docs tab are separate TechDocs viewers. Note the package is not
   under the `@backstage-community` scope.

To check the mkdocs half without a browser, grep the built output for
`class="mermaid"`:

```bash
grep -c 'class="mermaid"' \
  backstage/node_modules/@backstage/plugin-techdocs-backend/static/docs/default/component/todo-service/architecture/index.html
```

Also note `index.md` is served at the docs **root**, not at `/index/` — probing
`/api/techdocs/static/docs/default/component/<svc>/index/` returns 404 even when the
docs are fine.

## Ownership is spread across teams

`backstage/examples/org.yaml` defines `platform-team`, `web-team`, `todo-team`,
`notifications-team` and `quality-team` under an `engineering` group, each with a
member, so the catalog looks like a multi-team platform rather than one owner. The
`guests` group and `guest` user are kept because the guest sign-in provider resolves
to that user; deleting the group would leave a dangling `memberOf`.

Owners: frontend → web-team, todo-service (+ `todo-api`) → todo-team,
notification-service (+ `notification-api`, `rabbitmq-events`) → notifications-team,
validation-service → quality-team, and the template itself →
`group:default/platform-team`. The template's `owner` parameter is an enum of these
teams, defaulting to `quality-team`.

Each component carries exactly **one** tag (`react`, `spring-boot`, `nodejs`).

The catalog and API tables are given explicit column lists in `App.tsx`
(`catalogColumns` / `apiColumns`) to drop columns that carry no information here —
Lifecycle and System on the catalog page, System and Tags on the API page. They are
listed explicitly rather than filtered out of `defaultColumnsFunc` by title, because
those titles are translated strings and matching on them breaks silently.

## Version policy: track latest, do not pin to old

The demo intentionally tracks current upstream versions. Do not "fix" a breakage
by pinning to an older version unless there is no alternative — prefer making the
demo work with current versions.

Consequence: upstream changes break this repo over time, and the breakages tend
to be *version skew* — a floating chart or operator driving a pinned image, or a
pinned query against floating instrumentation. When something breaks, suspect skew
first.

Known deliberate pins:

- `scripts/06_deploy_observability.sh` pins the Jaeger chart to `4.12.0`. That chart
  prints `EXPERIMENTAL - NO STABILITY GUARANTEES` and warns of breaking changes in
  minor versions, so it gets bumped on purpose rather than drifting mid-demo.
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

## Browser telemetry uses the Dash0 web SDK

`services/frontend/src/tracing.js` initialises `@dash0/sdk-web` (page views, web
vitals, errors, sessions, fetch/XHR spans), exporting to the app's own origin so nginx
can proxy it to the collector: no ingest token in the JS bundle, and browser telemetry
flows through the same pipeline as the backends, reaching Jaeger and OpenSearch too.
`REACT_APP_DASH0_URL` / `REACT_APP_DASH0_AUTH_TOKEN` switch to direct ingestion and
make the token public.

Two ways it breaks silently:

- **The endpoint needs the `/telemetry` path prefix.** The SDK skips instrumenting any
  request whose URL starts with an endpoint URL, so a bare-origin endpoint suppresses
  fetch spans and `traceparent` for every same-origin call. Web events keep flowing,
  so RUM looks fine while nothing correlates with the backend.
- **nginx must proxy the whole prefix**, not just `/v1/traces` — page views, web vitals
  and errors go to `/v1/logs`, which the SPA catch-all would answer with `index.html`.
  Probe: `curl -X POST .../telemetry/v1/logs -d '{}'` returns `{"partialSuccess":{}}`
  from the collector, HTML from the SPA.

The SDK has **no manual-span API** and does not depend on `@opentelemetry/api`, so
`trace.getTracer()` yields a no-op tracer and adding a second SDK would
double-instrument `fetch`. Custom `sendEvent()` calls are avoided: they carry no
`traceId` (fired outside any span), duplicating the HTTP span without the correlation.
`reportError` is used for caught failures only.

## Semantic conventions are aligned on the stable HTTP names

Every runtime emits the **stable** HTTP attributes. Node defaults to the legacy
v1.7.0 names, so `infrastructure/instrumentations/instrumentation.yaml` sets
`OTEL_SEMCONV_STABILITY_OPT_IN=http` under `spec.nodejs.env` to match the Java agent.

| | Java (todo, notification) | Node.js (validation) |
|---|---|---|
| HTTP server | `http_server_request_duration_seconds_*` | `http_server_request_duration_seconds_*` |
| Status code label | `http_response_status_code` | `http_response_status_code` |
| Runtime memory | `jvm_memory_used_bytes` | `v8js_memory_heap_used_bytes` |

**The opt-in belongs in the Instrumentation CR, not in a service.** The SDKs are
injected by the OpenTelemetry Operator — the pods carry
`instrumentation.opentelemetry.io/inject-{java,nodejs}` and the operator sets
`NODE_OPTIONS=--require /otel-auto-instrumentation-nodejs/autoinstrumentation.js`.
So `@opentelemetry/auto-instrumentations-node` in a service's `package.json` is **not**
what instruments it at runtime (`npm start` is plain `node index.js`), and bumping
that dependency changes nothing about the emitted attributes. The injected bundle is
`autoinstrumentation-nodejs:0.78.0`, carrying `instrumentation-http` 0.220.0, which
reads the variable via `semconvStabilityFromStr()`. `http` selects stable only;
`http/dup` emits both generations.

Flipping this renames metrics rather than erroring, so dashboards go **silent**:
`http_server_duration_milliseconds_*` → `http_server_request_duration_seconds_*`, and
the unit changes from milliseconds to **seconds**, which affects panel axis units too
(the validation-service p95 panel is `unit: seconds`). After changing the opt-in,
re-run every dashboard query against Prometheus with fresh traffic — a `rate(...[5m])`
over a stale window returns 0 or NaN and looks identical to a broken query name.

Legacy series linger for a few minutes after a rollout because they are still in
Prometheus' retention from the previous pod. Check `k8s_pod_name` on the old series
before concluding the opt-in did not take.

The `frontend` agrees too, but by a different route: it uses `@dash0/sdk-web`
(see its TechDocs), which emits the stable names natively. The env-var opt-in could
never have worked there — there is no `process.env` in a browser.

The frontend emits **no HTTP metrics at all**, only spans and logs, so metric-based
dashboards will never show it.

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

### Make your probe fail loudly, not quietly

Several "bugs" found this way turned out to be broken measurements. Before
believing a negative result, check the probe:

- **`rate(...[5m])` needs several samples in the window.** One burst of traffic
  then a query minutes later returns *zero series* while the underlying counter is
  perfectly healthy. Generate traffic continuously for a minute or two, or query
  the raw counter first to see whether the data exists at all. This also means demo
  panels look empty if you click through faster than the traffic.
- **`kubectl logs --since=Nm` silently returns nothing** if the activity was
  outside the window. Cross-check with state that does not expire, e.g.
  `rabbitmqctl list_queues name messages consumers` — drained queues with a live
  consumer prove messages flowed.
- **A wrong workload or path name makes `grep -c` report 0** because the command
  errored, not because the pattern was absent. Confirm the resource exists first.
- **`{.items[0]}` after a rollout may be the terminating pod.** Reading env or files
  from it shows the *old* values, which looks exactly like a change that failed to
  apply. This one bit twice in a single session. Read the Deployment spec for intent,
  and if you need the runtime value, iterate every pod rather than indexing one:

  ```bash
  kubectl get deploy <name> -o jsonpath='{range .spec.template.spec.containers[0].env[*]}{.name}={.value}{"\n"}{end}'
  for p in $(kubectl get pods -l app.kubernetes.io/name=<name> -o jsonpath='{.items[*].metadata.name}'); do
    echo "$p: $(kubectl exec "$p" -- printenv VAR 2>/dev/null)"
  done
  ```

  The same aliasing explains phantom "duplicate env vars": iterating
  `.items[*].spec.containers[*].env[*]` across two pods mid-rollout prints both the
  old and new value and reads like one container with a duplicated key.
- **Do not let an extraction default silently.** A regex that missed its target and
  fell through to a placeholder value once made working validation code look broken.
  Assert what you extracted before using it.

Endpoint shapes matter too: `GET /todos` returns a Spring `Page` object, so
`len(response)` counts the wrapper's 11 keys, not the todos. Use `totalElements`.

## The mcp-chat plugin is patched locally

The "Ask Dash0" page is `@backstage-community/plugin-mcp-chat`, wired to the Dash0
MCP server through the `mcpChat` block in `backstage/app-config.yaml`. **Two** committed
patches live in `backstage/.yarn/patches/`, referenced by `patch:` dependencies in
`packages/app/package.json` (frontend) and `packages/backend/package.json` (backend), so
`yarn install` reapplies them. Do not "clean up" either.

### `mcpChat.systemPrompt` only works because of a patch

The Claude provider built the Anthropic request as `{model, max_tokens, messages}` and
`convertToAnthropicFormat()` filtered out `role: "system"` messages — the Messages API
takes the system prompt as a top-level `system` parameter, so the whole of
`mcpChat.systemPrompt` was **silently discarded**. Every instruction appeared to be
ignored by the model: dataset selection, time ranges, formatting. The backend patch adds
the missing `request.system`.

If prompt instructions ever stop taking effect, check that patch first. To test whether
the prompt is reaching the model at all, ask it directly — e.g. "do your instructions
mention X? YES or NO" — rather than inferring from behaviour.

The patch is one line: the plugin renders assistant replies through
`react-markdown` without passing `remarkPlugins`, so markdown tables arrived in
the chat as raw pipe characters even though the plugin already ships the CSS to
style them (`& table`, `& th, & td`). The patch adds
`remarkPlugins: [remarkGfm]`.

The dependency it imports is declared in `packageExtensions` in
`backstage/.yarnrc.yml`, not in the patch. **Yarn resolves a `patch:` package's
dependencies from the original npm manifest**, so a dependency added by the patch
itself is silently never installed — the installed manifest claims it and nothing
provides it. It must be `remark-gfm` v4: the plugin resolves its own nested
`react-markdown` 10, while the hoisted `remark-gfm` 3 belongs to
`@backstage/core-components` (paired with `react-markdown` 8) and targets the older
unified/mdast generation. After installing, both coexist — v4 hoisted, v3 nested
under `core-components`.

Note that steering the model via `systemPrompt` is not a substitute for fixing a
rendering gap — an instruction never to use tables was simply ignored.

## The chat can read the catalog too

`mcpChat.mcpServers` is a list, and the second entry points at Backstage's own
`@backstage/plugin-mcp-actions-backend`, which serves registered actions as MCP
tools at `/api/mcp-actions/v1/<server key>`. That is what lets one conversation ask
which components exist and then ask Dash0 how they are behaving —
`query-catalog-entities` and Dash0's tools land in the same tool list.

Three things about it are not obvious:

- **`mcpActions.namespacedToolNames` must be `false` for a Claude provider.** The
  default prefixes the plugin id with a dot (`catalog.query-catalog-entities`), and
  the Anthropic API rejects the request with
  `tools.<n>.custom.name: String should match pattern '^[a-zA-Z0-9_-]{1,128}$'`.
  A dot is not a legal tool-name character. Because the tool list goes out with
  every message, this 400s **all** chat, not just catalog questions.
- **Only the read-only catalog actions are exposed.** The catalog registers six;
  `register-entity` (`readOnly: false`) and `unregister-entity`
  (`destructive: true`) are kept out by the `mcpActions` filter and again by
  `disabledTools`. `exclude` is evaluated before `include`, so it wins, and the
  filter is applied on `tools/call` as well as discovery — an excluded action
  cannot be invoked by guessing its name. Expect exactly four tools:
  `query-catalog-entities`, `get-catalog-entity`, `get-catalog-model-description`,
  `validate-entity`. Set `disabledTools` names **without** the plugin prefix while
  namespacing is off.
- **The token is generated per run.** The chat calls the endpoint over HTTP even
  though both halves are the same backend, so it needs credentials;
  `01_start-demo.sh` mints `BACKSTAGE_MCP_TOKEN` with `openssl rand` unless `.env`
  sets one, and `backend.auth.externalAccess` accepts it as a static token. Nothing
  secret is stored for this. An action only becomes visible if its plugin is listed
  in `backend.actions.pluginSources`.

## Gotchas that have cost time

- Backstage reads `app-config.yaml` **at startup**. Editing it while `yarn start`
  runs either does nothing or dies in the hot reload with `write EPIPE`, leaving
  the old value live — a stale model ID or MCP URL then looks like a server-side
  404. Restart, and check the file's mtime against the backend process start time
  before believing a config change is in effect.
- `mcpChat` has no layout or rendering options — the schema is `providers`,
  `mcpServers`, `toolCallTimeout`, `systemPrompt`, `conversationHistory`. Anything
  about how replies look is in the plugin's own code.
- The backend mounts mcp-chat only when `ANTHROPIC_API_KEY` is set
  (`packages/backend/src/index.ts`). Without that guard a missing key throws at
  plugin init and takes down the **whole** backend, so the catalog and template
  vanish and it reads like a catalog problem. An unauthenticated
  `curl /api/mcp-chat/health` returning **401 means the plugin loaded**; 404 means
  it did not.

- The daemonset collector is named **`otel-collector-agent`**, not
  `otel-collector` (the chart appends `-agent` despite `fullnameOverride`). Piping
  `kubectl logs daemonset/otel-collector` into `grep -c` silently reports 0
  because the command errors — a vacuous pass that looks like a clean result.
- Jaeger v2 exposes **one** Service, `jaeger`, carrying every port. The v1 split
  services (`jaeger-collector`, `jaeger-query`, `jaeger-agent`) no longer exist, so
  the collector's `otlp/jaeger` exporter and the port-forwards target `jaeger`. The
  UI and API are at the root — `/api/services`, not the old `/jaeger/ui/api/...`.
- Jaeger v2's config lives in a ConfigMap and the chart sets **no checksum
  annotation** on the pod template, so `helm upgrade` after editing
  `infrastructure/jaeger/values.yaml` updates the ConfigMap while the running pod
  keeps the old config — silently. Step 6 restarts the Deployment when it already
  existed; keep that if you touch the script.
- Jaeger's Monitor tab (SPM) works via the `span_metrics` connector inside Jaeger:
  it derives RED metrics from the spans it receives and exposes them on `:8889`,
  the pod is annotated for Prometheus to scrape it, and `jaeger_query` reads them
  back from Prometheus. The metrics are namespaced `traces_span_metrics_*`, and
  `normalize_calls` / `normalize_duration` must stay on or Jaeger looks for
  `calls` / `duration_bucket` and finds nothing.
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
