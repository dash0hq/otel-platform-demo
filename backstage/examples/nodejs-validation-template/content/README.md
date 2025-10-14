# ${{ values.serviceName }}

${{ values.description }}

## Overview

This is a Node.js validation service with OpenTelemetry instrumentation.

## Features

- Express.js web framework
- OpenTelemetry auto-instrumentation
- Winston logging with JSON format
- Health check endpoint
- Validation endpoint for todo names

## Running Locally

```bash
# Install dependencies
npm install

# Run without OpenTelemetry
npm start

# Run with OpenTelemetry auto-instrumentation
npm run start:otel
```

## Building Docker Image

```bash
docker build -t ${{ values.serviceName }}:v1 .
```

## Deploying to Kubernetes

```bash
kubectl apply -f manifests/
```

## API Endpoints

- `POST /validate/todo-name` - Validates todo names
- `GET /health` - Health check endpoint

## Configuration

- Port: ${{ values.port }}
- Service Name: ${{ values.serviceName }}
