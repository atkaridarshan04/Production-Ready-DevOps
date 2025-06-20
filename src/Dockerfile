# ----- Stage 1: Build Stage -----
FROM maven:3.9.6-eclipse-temurin-17 AS builder

WORKDIR /build

# Leverage Docker cache: copy pom.xml and resolve dependencies first
COPY pom.xml .
RUN mvn dependency:go-offline -B

# Copy the rest of the code
COPY src ./src

# Package the application
RUN mvn clean package -DskipTests=true

# ----- Stage 2: Runtime Stage -----
FROM eclipse-temurin:17-jre-alpine AS runner

WORKDIR /app

# Copy only the built jar from builder stage
COPY --from=builder /build/target/*.jar app.jar

# Create a non-root user
RUN addgroup -S spring && adduser -S spring -G spring
USER spring:spring

EXPOSE 8000

# Healthcheck for Spring Boot actuator
HEALTHCHECK --interval=30s --timeout=3s --retries=1 \
  CMD wget -qO- http://localhost:8000/actuator/health | grep '"status":"UP"' || exit 1

ENTRYPOINT ["java", "-jar", "app.jar"]
CMD ["--server.port=8000"]