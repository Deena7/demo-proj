# Use OpenJDK
FROM openjdk:11
WORKDIR /app
COPY my-app.jar /app/my-app.jar
EXPOSE 8080
CMD ["java", "-jar", "my-app.jar"]

