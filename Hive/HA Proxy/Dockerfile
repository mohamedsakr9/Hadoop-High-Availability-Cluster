FROM haproxy:2.4
USER root
RUN apt-get update && apt-get install -y default-jre curl wget
RUN wget https://repo1.maven.org/maven2/org/apache/hive/hive-jdbc/3.1.2/hive-jdbc-3.1.2-standalone.jar -P /opt/ && \
    wget https://repo1.maven.org/maven2/org/apache/hive/hive-beeline/3.1.2/hive-beeline-3.1.2.jar -P /opt/
ENV CLASSPATH=/opt/hive-jdbc-3.1.2-standalone.jar:/opt/hive-beeline-3.1.2.jar
COPY haproxy.cfg /usr/local/etc/haproxy/haproxy.cfg