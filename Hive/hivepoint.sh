#!/bin/bash
echo "$(date) Starting SSH service..."
sudo service ssh start || true

# Check if Hadoop services are running (for containers that depend on external Hadoop cluster)
wait_for_hadoop() {
    echo "$(date) Waiting for Hadoop services..."
    local max_attempts=30
    local attempt=1
    
    while [ $attempt -le $max_attempts ]; do
        if hdfs dfs -ls / &>/dev/null; then
            echo "$(date) HDFS is available!"
            return 0
        fi
        echo "$(date) Waiting for HDFS to become available (attempt $attempt/$max_attempts)..."
        sleep 10
        ((attempt++))
    done
    
    echo "$(date) WARNING: HDFS is not available after $max_attempts attempts. Continuing anyway..."
    return 0
}

if [ "$(hostname)" == "metastore" ]; then
    echo "$(date) This is the Metastore container. Waiting for Hadoop services..."
    wait_for_hadoop
    
    echo "$(date) Starting Metastore services..."
    if [ ! -f "/tmp/.hive_metastore_initialized" ]; then
        echo "$(date) Initializing Hive Metastore schema with PostgreSQL..."
        schematool -dbType postgres -initSchema
        touch /tmp/.hive_metastore_initialized
    else
        echo "$(date) Hive Metastore schema already initialized. Skipping..."
    fi
    echo "$(date) Starting Hive Metastore service..."
    mkdir -p $HIVE_HOME/logs
    nohup hive --service metastore > $HIVE_HOME/logs/metastore.log 2>&1 &
    sleep 5
    
    # Setup Tez only if HDFS is available
    if hdfs dfs -ls / &>/dev/null; then
        echo "$(date) Setting up Tez directories and files..."
        hdfs dfs -mkdir -p /apps/tez/lib
        hdfs dfs -chmod g+wx /apps
        hdfs dfs -chmod -R 755 /apps/tez
        mkdir -p $TEZ_HOME/share
        if [ ! -f "$TEZ_HOME/share/tez.tar.gz" ]; then
            echo "$(date) Creating tez.tar.gz package..."
            cd $TEZ_HOME
            tar -czf $TEZ_HOME/share/tez.tar.gz lib/*.jar conf/*
        fi
        echo "$(date) Uploading Tez to HDFS..."
        hdfs dfs -put -f $TEZ_HOME/share/tez.tar.gz /apps/tez/
        hdfs dfs -put $TEZ_HOME/*.jar /apps/tez/lib 2>/dev/null || true
        hdfs dfs -put $TEZ_HOME/lib/*.jar /apps/tez/lib 2>/dev/null || true
    else
        echo "$(date) Skipping Tez setup - HDFS not available"
    fi
    
    echo "$(date) Metastore started. Tailing logs..."
    tail -f $HIVE_HOME/logs/metastore.log
    
elif [[ "$(hostname)" == hiveserver2* ]]; then
    echo "$(date) This is a HiveServer2 container ($(hostname)). Waiting for Hadoop services..."
    wait_for_hadoop
    
    echo "$(date) Waiting for metastore..."
    sleep 30
    echo "$(date) Starting HiveServer2 on $(hostname)..."
    mkdir -p $HIVE_HOME/logs
    hive --service hiveserver2 > $HIVE_HOME/logs/hiveserver2.log 2>&1
else
    echo "$(date) Unknown container role: $(hostname). Running shell to debug."
    /bin/bash
fi