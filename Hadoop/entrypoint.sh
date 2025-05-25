#!/bin/bash
echo "$(date) Starting SSH service..."
sudo service ssh start

echo "$(date) Configuring ZooKeeper myid and logs..."

if [[ "$(hostname)" =~ m([0-9]+) ]]; then
    ID="${BASH_REMATCH[1]}"
    echo "$ID" > $ZK_DIR/myid
    echo "$(date) Set ZooKeeper ID to $ID based on hostname $(hostname)"
fi

if [[ "$(hostname)" =~ ^w.* ]]; then
    sleep 30
    
    echo "$(date) Starting DataNode on worker node $(hostname)..."
    hdfs --daemon start datanode
    echo "$(date) Starting NodeManager on worker node $(hostname)..."
    yarn --daemon start nodemanager
    
    echo "$(date) Worker node services started successfully! Monitoring logs..."
    tail -f /dev/null
    exit 0
fi

echo "$(date) Starting JournalNode on $(hostname)..."
hdfs --daemon start journalnode

if [ "$(hostname)" == "m1" ]; then

    if [ ! -d "$NAMENODE_DIR/current" ]; then
        echo "$(date) Formatting NameNode as it hasn't been formatted yet..."
        hdfs namenode -format -force
    else
        echo "$(date) NameNode is already formatted. Skipping formatting..."
    fi
    
    echo "$(date) Starting NameNode on m1..."
    hdfs --daemon start namenode
    sleep 10
    echo "$(date) Starting ZooKeeper on m1..."
    zkServer.sh start
    sleep 5

    if echo "ls /hadoop-ha" | zkCli.sh -server m1:2181 | grep -q sakrcluster; then
        echo "$(date) ZKFC is already formatted. Skipping formatting..."
    else
        echo "$(date) Formatting Zookeeper Failover Controller (ZKFC) as it hasn't been formatted yet..."
        hdfs zkfc -formatZK -force
    fi

    echo "$(date) Starting ZKFC on m1..."
    hdfs --daemon start zkfc
    
    echo "$(date) Setting up YARN HA ZooKeeper paths..."
    
    if echo "ls /rmstore" | zkCli.sh -server m1:2181 2>&1 | grep -q "Node does not exist"; then
        echo "$(date) Creating /rmstore ZooKeeper path for YARN HA..."
        echo "create /rmstore" | zkCli.sh -server m1:2181
    else
        echo "$(date) /rmstore ZooKeeper path already exists"
    fi
    
    if echo "ls /yarn-leader-election" | zkCli.sh -server m1:2181 2>&1 | grep -q "Node does not exist"; then
        echo "$(date) Creating /yarn-leader-election ZooKeeper path for YARN HA..."
        echo "create /yarn-leader-election" | zkCli.sh -server m1:2181
    else
        echo "$(date) /yarn-leader-election ZooKeeper path already exists"
    fi

elif [[ "$(hostname)" =~ ^m.* && "$(hostname)" != m1 ]]; then
    # Bootstrap Standby NameNode
    if [ ! -d "$NAMENODE_DIR/current" ]; then
        sleep 20 
        echo "$(date) Bootstrapping Standby on $(hostname)..."
        hdfs namenode -bootstrapStandby
    else
        echo "$(date) Standby NameNode already bootstrapped. Skipping..."
    fi
    
    # Start ZooKeeper and NameNode for standby nodes
    echo "$(date) Starting ZooKeeper on $(hostname)..."
    zkServer.sh start

    echo "$(date) Starting NameNode on $(hostname)..."  
    hdfs --daemon start namenode
    sleep 20
    echo "$(date) Starting ZKFC on $(hostname)..."
    hdfs --daemon start zkfc
fi

# Wait for HDFS services to fully start
sleep 5

# Start ResourceManager on all master nodes
echo "$(date) Starting ResourceManager on $(hostname)..."
yarn --daemon start resourcemanager

echo "$(date) All services started successfully! Monitoring logs..."
tail -f /dev/null