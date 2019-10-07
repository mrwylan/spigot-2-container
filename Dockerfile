# 1. BUILD the server

FROM openjdk:13-jdk-alpine AS build-env

ARG rev
ENV BUILD_REV ${rev:-1.14.4}
ENV BUILD_HOME /build
WORKDIR ${BUILD_HOME}

# GIT is required

RUN apk update && \
    apk add --no-cache bash git openssh

# BuildTool download and execution

RUN wget -O BuildTools.jar https://hub.spigotmc.org/jenkins/job/BuildTools/lastSuccessfulBuild/artifact/target/BuildTools.jar && \
    java -Xmx2G -jar BuildTools.jar --rev ${BUILD_REV}

VOLUME ${BUILD_HOME}

# 2. Build the server image

FROM openjdk:13-jdk-alpine

ARG rev
ARG world

ENV SPIGOT_REV ${rev:-1.14.4}
ENV SPIGOT_HOME /spigot
ENV PATH "${SPIGOT_HOME}:${PATH}"
ENV JAVA_OPTS "-Xmx2G -Xms1G"

WORKDIR ${SPIGOT_HOME}

COPY level-check.sh serverdata leveldata ${SPIGOT_HOME}/
COPY --from=build-env /build/spigot-${SPIGOT_REV}.jar spigot.jar

RUN java ${JAVA_OPTS} -jar spigot.jar && \
    sed -i -r "s/false/true/g" eula.txt && \
    sed -i -r "s/(^level-name=)(.*)$/\1${world}/g" server.properties && \
    chmod +x ./level-check.sh

EXPOSE 25565
ENTRYPOINT [ "level-check.sh" ]
CMD [ "start" ]  [ ${world} ]