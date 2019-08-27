FROM alpine/git as clone

# Define branch
ARG BRANCH 
ENV BRANCH=${BRANCH}

# Clone repos
WORKDIR /app
RUN git clone https://github.com/aquality-automation/aquality-tracking-api.git
RUN cd aquality-tracking-api && git fetch origin && git checkout ${BRANCH} || git checkout -b ${BRANCH} origin/${BRANCH}
RUN git clone https://github.com/aquality-automation/aquality-tracking-ui.git
RUN cd aquality-tracking-ui && git fetch origin && git checkout ${BRANCH} || git checkout -b ${BRANCH} origin/${BRANCH}

FROM maven:3.5-jdk-8-alpine as build-back
COPY --from=clone /app/aquality-tracking-api /app
WORKDIR /app
ARG DB_USER=root
ARG DB_HOST=db
ARG DB_PORT=3306
ARG DB_PASS
RUN mvn package -f pom.xml  -P !run-migration -Ddb.username="$DB_USER" -Ddb.password="$DB_PASS" -Ddb.host="$DB_HOST" -Ddb.publicPort="$DB_PORT" -Ddb.port="$DB_PORT" -Ddb.publicHost="$DB_HOST"

FROM node:10-alpine as build-front
WORKDIR /app
COPY --from=clone /app/aquality-tracking-ui /app
RUN apk add --no-cache git
RUN npm i
RUN npm run build:prod

FROM maven:3.5-jdk-8-alpine as results
WORKDIR /result/back
COPY --from=build-back /app /result/back/
COPY --from=build-back /app/target/api.war /result/webapps/
COPY --from=build-front /app/dist/ /result/webapps/ROOT/
ARG DB_USER=root
ARG DB_PASS
ARG DB_HOST=db
ARG DB_PORT=3306
ENV DB_USER ${DB_USER}
ENV DB_PASS ${DB_PASS}
ENV DB_HOST ${DB_HOST}
ENV DB_PORT ${DB_PORT}
CMD mvn resources:resources liquibase:update -Ddb.username=${DB_USER} -Ddb.password=${DB_PASS} -Ddb.host=${DB_HOST} -Ddb.publicPort=${DB_PORT} -Ddb.port=${DB_PORT} -Ddb.publicHost=${DB_HOST} ; cp -r /result/webapps/ /app
