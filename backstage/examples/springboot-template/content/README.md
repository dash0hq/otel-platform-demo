# ${{ values.serviceName }}

${{ values.description }}

## Overview

This is a Spring Boot REST API service with PostgreSQL database integration. The service provides a RESTful API for managing items.

## Technology Stack

- **Java 17**
- **Spring Boot 3.2.0**
- **Spring Data JPA**
- **PostgreSQL**
- **Maven**
- **Lombok**

## Prerequisites

- Java 17 or higher
- Maven 3.6+
- PostgreSQL 12 or higher
- Docker (optional, for running PostgreSQL in a container)

## Getting Started

### 1. Setup PostgreSQL Database

#### Option A: Using Docker
```bash
docker run --name postgres-db \
  -e POSTGRES_DB=${{ values.databaseName }} \
  -e POSTGRES_USER=postgres \
  -e POSTGRES_PASSWORD=postgres \
  -p ${{ values.databasePort }}:5432 \
  -d postgres:15
```

#### Option B: Local PostgreSQL Installation
Create a database named `${{ values.databaseName }}`:
```sql
CREATE DATABASE ${{ values.databaseName }};
```

### 2. Build the Application

```bash
mvn clean install
```

### 3. Run the Application

```bash
mvn spring-boot:run
```

The application will start on `http://localhost:8080`

## API Endpoints

### Health Check
```bash
GET http://localhost:8080/actuator/health
```

### Items API

#### Get All Items
```bash
GET http://localhost:8080/api/items
```

#### Search Items by Name
```bash
GET http://localhost:8080/api/items?name=search-term
```

#### Get Item by ID
```bash
GET http://localhost:8080/api/items/{id}
```

#### Create New Item
```bash
POST http://localhost:8080/api/items
Content-Type: application/json

{
  "name": "Item Name",
  "description": "Item Description"
}
```

#### Update Item
```bash
PUT http://localhost:8080/api/items/{id}
Content-Type: application/json

{
  "name": "Updated Name",
  "description": "Updated Description"
}
```

#### Delete Item
```bash
DELETE http://localhost:8080/api/items/{id}
```

## Configuration

Application configuration can be found in `src/main/resources/application.properties`:

- **Server Port**: 8080
- **Database URL**: jdbc:postgresql://localhost:${{ values.databasePort }}/${{ values.databaseName }}
- **Database Username**: postgres
- **Database Password**: postgres

### Environment-Specific Configuration

Create additional configuration files for different environments:
- `application-dev.properties` for development
- `application-prod.properties` for production

Run with specific profile:
```bash
mvn spring-boot:run -Dspring-boot.run.profiles=dev
```

## Testing

Run the tests:
```bash
mvn test
```

## Building for Production

Create a production-ready JAR:
```bash
mvn clean package -DskipTests
```

Run the JAR:
```bash
java -jar target/${{ values.serviceName }}-0.1.0.jar
```

## Docker Deployment

### Build Docker Image
```bash
docker build -t ${{ values.serviceName }}:latest .
```

### Run with Docker Compose
Create a `docker-compose.yml` file to run both the application and database.

## Project Structure

```
src/
├── main/
│   ├── java/
│   │   └── com/example/demo/
│   │       ├── Application.java           # Main application class
│   │       ├── controller/
│   │       │   └── ItemController.java    # REST controller
│   │       ├── model/
│   │       │   └── Item.java              # JPA entity
│   │       └── repository/
│   │           └── ItemRepository.java    # Data repository
│   └── resources/
│       └── application.properties         # Application configuration
└── test/
    └── java/
        └── com/example/demo/
            └── ApplicationTests.java       # Integration tests
```

## Monitoring

The application includes Spring Boot Actuator for monitoring:

- Health: `http://localhost:8080/actuator/health`
- Info: `http://localhost:8080/actuator/info`
- Metrics: `http://localhost:8080/actuator/metrics`

## Contributing

Please follow the standard Git workflow:
1. Create a feature branch
2. Make your changes
3. Submit a pull request

## License

Copyright © 2024
