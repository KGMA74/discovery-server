# FlowPay — Discovery Server

Eureka service registry for the FlowPay microservices ecosystem. All services register here on startup and use it for client-side load balancing.

## Role

- Receives heartbeat registrations from all FlowPay services
- Exposes a registry dashboard at `http://localhost:8761`
- Enables Spring Cloud `LoadBalancerClient` (`lb://SERVICE-NAME`) across the stack

## Tech stack

- Kotlin / Spring Boot 3
- Spring Cloud Netflix Eureka Server

## Run locally

```bash
./gradlew bootRun
```

Dashboard available at `http://localhost:8761`.

## Build

```bash
./gradlew build       # compile + test
./gradlew bootJar     # fat JAR → build/libs/
```

## Configuration

| Property | Default | Description |
|---|---|---|
| `server.port` | `8080` | Internal HTTP port |
| `eureka.client.register-with-eureka` | `false` | Does not self-register |
| `eureka.client.fetch-registry` | `false` | Does not fetch its own registry |

## Docker

```bash
docker build -t flowpay/discovery-server .
docker run -p 8761:8080 flowpay/discovery-server
```

In docker-compose the service is exposed on port `8761` on the host.
