FROM opt-ha

USER root    
COPY ./apache-hive-4.0.1-bin.tar.gz /Data/
COPY ./apache-tez-0.10.4-bin.tar.gz /tmp/
RUN mkdir -p /hive && \
    tar xzf /Data/apache-hive-4.0.1-bin.tar.gz -C /hive && \
    rm -f /Data/apache-hive-4.0.1-bin.tar.gz && \
    mv /hive/apache-hive-4.0.1-bin/* /hive/ && \
    rm -rf /hive/apache-hive-4.0.1-bin && \
    mkdir -p /tez && \
    tar -xzf /tmp/apache-tez-0.10.4-bin.tar.gz -C /tez --strip-components=1 && \
    rm -f /tmp/apache-tez-0.10.4-bin.tar.gz && \
    apt-get update && \
    apt-get install -y --no-install-recommends postgresql-client && \
    wget --no-verbose https://jdbc.postgresql.org/download/postgresql-42.7.5.jar && \
    mv postgresql-42.7.5.jar /hive/lib/ && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/* && \
    mkdir -p /home/huser && \
    chown -R huser:hadoop /hive /tez /home/huser && \
    chmod 755 /tez /hive

COPY ./hive-site.xml /hive/conf/
COPY ./metastore-site.xml /hive/conf/
COPY ./tez-site.xml /tez/conf/

RUN chown huser:hadoop /hive/conf/hive-site.xml  /hive/conf/metastore-site.xml /tez/conf/tez-site.xml
COPY ./hivepoint.sh /tmp/hivepoint.sh
RUN chmod +x /tmp/hivepoint.sh && \
    cp /tmp/hivepoint.sh /hivepoint.sh && \
    ls -la /hivepoint.sh


USER huser

ENV JAVA_HOME=/usr/lib/jvm/java-8-openjdk-amd64
ENV HADOOP_HOME=/Data/hadoop-3.3.6
ENV HADOOP_CONF_DIR=$HADOOP_HOME/etc/hadoop
ENV HADOOP_MAPRED_HOME=$HADOOP_HOME
ENV HADOOP_COMMON_HOME=$HADOOP_HOME
ENV HADOOP_HDFS_HOME=$HADOOP_HOME
ENV YARN_HOME=$HADOOP_HOME
ENV YARN_CONF_DIR=$HADOOP_CONF_DIR
ENV HIVE_HOME=/hive
ENV TEZ_HOME=/tez
ENV TEZ_CONF_DIR=$TEZ_HOME/conf
ENV PATH=$PATH:$JAVA_HOME/bin:$HADOOP_HOME/bin:$HADOOP_HOME/sbin:/zookeeper-3.5.9/bin:$HIVE_HOME/bin:$TEZ_HOME/bin
ENV HADOOP_CLASSPATH=$HADOOP_CLASSPATH:$TEZ_CONF_DIR:$TEZ_HOME/*:$TEZ_HOME/lib/*


ENTRYPOINT ["/bin/bash", "/hivepoint.sh"]
