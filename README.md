![This tutorial is courtesy of Dash0](./images/dash0-logo.png)

# Platform Engineering Day NA 2025 Demo

A demonstration of a modern platform engineering workflow featuring Backstage developer portal with OpenTelemetry-instrumented microservices. This demo showcases how platform teams can provide self-service capabilities for developers to create new services with built-in observability, complete with automatic telemetry pipeline including metrics, traces, and logs exported to both local observability tools and Dash0.

## Quick Start

### Prerequisites
- Docker
- Kind
- kubectl
- Helm
- Node.js and Yarn (for Backstage)
- Dash0 account and authorization token

### 1. Configure Dash0 Credentials

Copy the template and configure your Dash0 settings:

```bash
cp .env.template .env
```

Edit `.env` and add your Dash0 credentials:
```bash
DASH0_AUTH_TOKEN="your-dash0-token"
DASH0_DATASET="default"
DASH0_ENDPOINT_OTLP_GRPC_HOSTNAME="ingress.eu-west-1.aws.dash0.com"
DASH0_ENDPOINT_OTLP_GRPC_PORT="4317"
```

### 2. Run the Complete Setup

Execute the main orchestration script:

```bash
./00_run.sh
```

### 3. Start Backstage

Start the Backstage developer portal:

```bash
./01_backstage.sh
# Visit: http://localhost:3000
```

### 4. Access the Application

After deployment completes, access the frontend:

```bash
# Frontend
kubectl port-forward -n default svc/frontend 3001:80
# Visit: http://localhost:3001
```

### 5. Access Observability Tools

#### Local Observability Stack

```bash
# Jaeger UI
kubectl port-forward -n default svc/jaeger-query 16686:16686
# Visit: http://localhost:16686

# Prometheus
kubectl port-forward -n default svc/prometheus 9090:9090
# Visit: http://localhost:9090

# OpenSearch Dashboards
kubectl port-forward -n default svc/opensearch-dashboards 5601:5601
# Visit: http://localhost:5601
# Username: admin, Password: SecureP@ssw0rd123
```

#### Dash0

All telemetry data (metrics, traces, and logs) is also exported to Dash0. Visit your Dash0 dashboard at https://app.dash0.com to see:
- Distributed traces from all services
- Application metrics
- Structured logs with correlation

## Cleanup

Delete the entire cluster and all resources:

```bash
./02_cleanup.sh
```

## Demo: Self-Service Observability with Backstage

This demo showcases how platform teams can enable developers to create fully observable services without writing instrumentation code. Using Backstage templates and OpenTelemetry auto-instrumentation, developers get distributed tracing, metrics, and logs automatically.

### Demo Flow

#### 1. Show the Current State

First, show what's running in the cluster:

```bash
kubectl get pods -A
```

You'll see the running services: frontend, todo-service, notification-service, and the observability stack.

#### 2. Demonstrate the Todo Application

Open the frontend application:

```bash
# Already port-forwarded from setup
# Visit: http://localhost:3001
```

**Create a new todo** (e.g., "Buy groceries") and show that it works.

#### 3. Show Distributed Tracing in Jaeger

Open Jaeger UI:

```bash
# Already port-forwarded from setup
# Visit: http://localhost:16686
```

- Select service: `todo-service`
- Find traces and click on one
- **Show the distributed trace** spanning:
  - HTTP request to todo-service
  - Database insert operation
  - **Publisher span** - todo-service publishing event to RabbitMQ
  - **Consumer span** - notification-service consuming the event from RabbitMQ
- Highlight that the entire flow is automatically traced with no code changes
- **Show span attributes** including `user.email` - note that it's been **hashed by the collector** to protect sensitive data

#### 4. Create a Validation Service via Backstage

Now we'll add a new service that validates todo names, showcasing the self-service platform.

**Open Backstage:**
```bash
# Visit: http://localhost:3000
```

**Create the validation service:**
1. Click "Create" in the sidebar
2. Select "Node.js Validation Service" template
3. Fill in the details:
   - **Service Name**: `validation-service`
   - **Port**: `3001`
   - **Description**: `Validates todo names for inappropriate content`
4. Click "Create"

**Follow the instructions shown in Backstage:**

```bash
# Navigate to the service directory
cd validation-service

# Build the Docker image
docker build -t validation-service:v1 .

# Load image into Kind cluster
kind load docker-image --name plat-eng-day validation-service:v1

# Deploy to Kubernetes
kubectl apply -f manifests/

# Enable validation in todo-service
kubectl set env deployment/todo-service \
  VALIDATION_SERVICE_ENABLED=true \
  VALIDATION_SERVICE_URL=http://validation-service:3001
```

#### 5. Verify the Service is Running

```bash
kubectl get pods -n default | grep validation-service
```

The pod should be running with OpenTelemetry auto-instrumentation enabled.

#### 6. Test Validation with a Bad Word

Go back to the frontend (http://localhost:3001) and **create a todo with "bad" in the name** (e.g., "This is bad"):

- The request should **fail with a validation error**
- Show the error message in the UI

#### 7. Show the Complete Distributed Trace

Return to Jaeger (http://localhost:16686):

1. Refresh and find the latest trace with an error
2. Click on it and **expand the full trace**
3. **Highlight the new service** appearing in the trace:
   - HTTP request to todo-service
   - **Call to validation-service** (new!)
   - Validation service processing the request
   - Error returned to todo-service
   - No database insert (validation failed)

**Key point**: The validation-service is now **automatically part of the distributed trace** with:
- No instrumentation code written
- Context propagation working automatically
- HTTP spans captured automatically
- All enabled by the OpenTelemetry operator annotation

#### 8. Deploy the Dashboard

The Backstage template also generated a Perses dashboard for monitoring the service:

```bash
kubectl apply -f ./validation-service/dashboards/validation-service-dashboard.yaml
```

Open Perses (http://localhost:8080) and view real-time metrics:
- HTTP Request Rate
- Validation Results (valid vs invalid)
- Response Time (p95)
- Event Loop & CPU utilization

**Note**: In a production setup, this dashboard would be automatically applied by a GitOps tool (ArgoCD, Flux, etc.) as part of the deployment pipeline.

#### 9. Show Dash0 (Optional)

Open your Dash0 dashboard at https://app.dash0.com to show:
- All services including validation-service appearing automatically
- Distributed traces with full context
- Service map showing the relationships
- Metrics and logs correlated together

### Key Takeaways

This demo shows:

1. **Self-Service**: Developers create services via Backstage templates
2. **Zero-Code Observability**: OpenTelemetry auto-instrumentation via operator annotations
3. **Distributed Tracing**: Automatic context propagation across services
4. **Data Protection**: OpenTelemetry Collector automatically redacts sensitive data (like email addresses) before export
5. **Golden Path**: Platform team provides the infrastructure, developers focus on business logic
6. **Consistency**: Every service gets the same observability capabilities automatically

### Architecture Highlights

#### Data Redaction in the Collector

The OpenTelemetry Collector is configured to automatically hash sensitive span attributes:

```yaml
processors:
  attributes/redact:
    actions:
      - key: user.email
        action: hash
```

This ensures that sensitive data added to spans (like `user.email` in the todo-service) is automatically protected before being exported to Jaeger, Prometheus, or Dash0. This centralized approach means:
- Developers can instrument freely without worrying about accidentally exposing PII
- Security team controls data redaction policies at the collector level
- No need to modify application code for compliance