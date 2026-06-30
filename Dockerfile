# syntax=docker/dockerfile:1

# ── Stage 1 : Build ──────────────────────────────────────────────────────────
FROM eclipse-temurin:24-jdk AS build
WORKDIR /workspace

COPY gradlew settings.gradle.kts build.gradle.kts ./
COPY gradle ./gradle
RUN sed -i 's/\r$//' gradlew && chmod +x gradlew

RUN --mount=type=cache,id=gradle-discovery-svc,target=/root/.gradle,sharing=locked \
    ./gradlew dependencies --no-daemon -q || \
    (sleep 20 && ./gradlew dependencies --no-daemon -q) || \
    (sleep 40 && ./gradlew dependencies --no-daemon -q)

COPY src ./src

RUN --mount=type=cache,id=gradle-discovery-svc,target=/root/.gradle,sharing=locked \
    ./gradlew bootJar --no-daemon -q && \
    mv build/libs/*.jar app.jar

# ── Stage 2 : Extraction des couches Spring Boot ─────────────────────────────
FROM eclipse-temurin:24-jre AS extract
WORKDIR /workspace
COPY --from=build /workspace/app.jar .
RUN java -Djarmode=layertools -jar app.jar extract --destination layers

# ── Stage 3 : Image de production ────────────────────────────────────────────
FROM eclipse-temurin:24-jre
WORKDIR /app

RUN useradd -u 1001 -m -s /sbin/nologin appuser && \
    apt-get update && \
    apt-get install -y --no-install-recommends curl && \
    rm -rf /var/lib/apt/lists/*

COPY --from=extract --chown=appuser:appuser /workspace/layers/dependencies           ./
COPY --from=extract --chown=appuser:appuser /workspace/layers/spring-boot-loader     ./
COPY --from=extract --chown=appuser:appuser /workspace/layers/snapshot-dependencies  ./
COPY --from=extract --chown=appuser:appuser /workspace/layers/application            ./

USER 1001

ENV JAVA_TOOL_OPTIONS="\
  -XX:+UseContainerSupport \
  -XX:MaxRAMPercentage=75.0 \
  -XX:+ExitOnOutOfMemoryError \
  -XX:+UseZGC \
  -Djava.security.egd=file:/dev/./urandom"

EXPOSE 8080

HEALTHCHECK --interval=30s --timeout=5s --start-period=45s --retries=3 \
  CMD curl -sf http://localhost:8080/actuator/health | grep -q '"status":"UP"' || exit 1

ENTRYPOINT ["java", "org.springframework.boot.loader.launch.JarLauncher"]
