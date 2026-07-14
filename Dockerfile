FROM eclipse-temurin:21.0.9_10-jre-noble
ENV PORT=8080

RUN set -eux; \
	apt-get update;

COPY structurizr-application/target/structurizr-*.war /Users/anasiri2/structurizr.war
COPY structurizr-themes /Users/anasiri2/structurizr-themes

EXPOSE ${PORT}

WORKDIR /Users/anasiri2/structurizr

ENTRYPOINT ["java", "-Dserver.port=${PORT}", "-jar", "--enable-native-access=ALL-UNNAMED", "/Users/anasiri2/structurizr.war"]