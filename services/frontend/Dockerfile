FROM node:24-alpine

WORKDIR /app

# Copy package files
COPY package*.json ./

# npm ci, not npm install: it installs exactly what package-lock.json pins and fails
# if the lockfile and package.json disagree. `npm install` would silently resolve new
# minor/patch versions at build time, which for a 0.x dependency like @dash0/sdk-web
# can change instrumentation behaviour without any change in this repo.
RUN npm ci

# Copy source code
COPY . .

# Build the app
RUN npm run build

# Use nginx to serve the built app
FROM nginx:alpine
COPY --from=0 /app/build /usr/share/nginx/html

# Copy nginx template and original config
COPY nginx.conf.template /etc/nginx/templates/default.conf.template
COPY nginx.conf /etc/nginx/conf.d/default.conf.backup

# Set default environment variables for docker-compose
ENV TODO_SERVICE_HOST=todo-service
ENV TODO_SERVICE_PORT=3000
ENV OTEL_COLLECTOR_HOST=otel-collector
ENV OTEL_COLLECTOR_PORT=4318

EXPOSE 80
CMD ["nginx", "-g", "daemon off;"]