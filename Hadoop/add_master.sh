#!/bin/bash
NEW_MASTER=$1

echo "Updating configurations for newly added master node: m$NEW_MASTER"

# Step 1: Extract configuration files from existing master
EXISTING_MASTERS=$(docker ps --format '{{.Names}}' | grep -E '^m[0-9]+$' | grep -v "m$NEW_MASTER")
FIRST_MASTER=$(echo "$EXISTING_MASTERS" | head -n1)

echo "Extracting configuration files..."
docker cp $FIRST_MASTER:/Data/hadoop-3.3.6/etc/hadoop/hdfs-site.xml ./hdfs-site.xml
docker cp $FIRST_MASTER:/Data/hadoop-3.3.6/etc/hadoop/yarn-site.xml ./yarn-site.xml
docker cp $FIRST_MASTER:/Data/hadoop-3.3.6/etc/hadoop/core-site.xml ./core-site.xml
docker cp $FIRST_MASTER:/zookeeper-3.5.9/conf/zoo.cfg ./zoo.cfg

# Step 2: Update ZooKeeper quorum in core-site.xml
if grep -q "ha.zookeeper.quorum" core-site.xml; then
  QUORUM=$(grep -A1 "ha.zookeeper.quorum" core-site.xml | grep "<value>" | sed 's/.*<value>\(.*\)<\/value>.*/\1/')
  # Check if the host is already in the quorum
  if ! echo "$QUORUM" | grep -q "m$NEW_MASTER:2181"; then
    NEW_QUORUM="$QUORUM,m$NEW_MASTER:2181"
    sed -i "s|<value>$QUORUM<\/value>|<value>$NEW_QUORUM<\/value>|" core-site.xml
    echo "Updated ZooKeeper quorum: $NEW_QUORUM"
  fi
fi

# Step 3: Update HDFS configuration
NAMENODE_LIST=$(grep -A1 "dfs.ha.namenodes.sakrcluster" hdfs-site.xml | grep "<value>" | sed 's/.*<value>\(.*\)<\/value>.*/\1/')
if [ -z "$NAMENODE_LIST" ]; then
  echo "Error: Could not find dfs.ha.namenodes.sakrcluster in hdfs-site.xml"
  exit 1
fi

# Update shared edits directory if it exists
if grep -q "dfs.namenode.shared.edits.dir" hdfs-site.xml; then
  NAMENODE_EDITS=$(grep -A1 "dfs.namenode.shared.edits.dir" hdfs-site.xml | grep "<value>" | sed 's/.*<value>\(.*\)<\/value>.*/\1/')
  
  if [[ "$NAMENODE_EDITS" == qjournal://* ]]; then
    JOURNAL_NODES=$(echo "$NAMENODE_EDITS" | cut -d'/' -f3)
    
    # Check if the host is already in the journal nodes list
    if ! echo "$JOURNAL_NODES" | grep -q "m$NEW_MASTER:8485"; then
      NEW_JOURNAL_NODES="$JOURNAL_NODES;m$NEW_MASTER:8485"
      NEW_NAMENODE_EDITS=$(echo "$NAMENODE_EDITS" | sed "s|$JOURNAL_NODES|$NEW_JOURNAL_NODES|")
      sed -i "s|<value>$NAMENODE_EDITS<\/value>|<value>$NEW_NAMENODE_EDITS<\/value>|" hdfs-site.xml
      echo "Updated shared edits directory: $NEW_NAMENODE_EDITS"
    fi
  fi
fi

# Add the new namenode to the list if not already present
if ! echo "$NAMENODE_LIST" | grep -q "\bm$NEW_MASTER\b"; then
  NEW_NAMENODE_LIST="$NAMENODE_LIST,m$NEW_MASTER"
  sed -i "s/<value>$NAMENODE_LIST<\/value>/<value>$NEW_NAMENODE_LIST<\/value>/" hdfs-site.xml
  echo "Updated NameNode list: $NEW_NAMENODE_LIST"
else
  echo "NameNode m$NEW_MASTER already in the list"
fi

if ! grep -q "dfs.namenode.rpc-address.sakrcluster.m$NEW_MASTER" hdfs-site.xml; then
  sed -i "/<\/configuration>/i\\
  <property>\\
    <name>dfs.namenode.rpc-address.sakrcluster.m$NEW_MASTER<\/name>\\
    <value>m$NEW_MASTER:8020<\/value>\\
  <\/property>\\
  <property>\\
    <name>dfs.namenode.http-address.sakrcluster.m$NEW_MASTER<\/name>\\
    <value>m$NEW_MASTER:50070<\/value>\\
  <\/property>\\
  <property>\\
    <name>dfs.namenode.servicerpc-address.sakrcluster.m$NEW_MASTER<\/name>\\
    <value>m$NEW_MASTER:8022<\/value>\\
  <\/property>" hdfs-site.xml
  echo "Added RPC addresses for m$NEW_MASTER"
fi

# Step 4: Update YARN RM configuration
RM_LIST=$(grep -A1 "yarn.resourcemanager.ha.rm-ids" yarn-site.xml | grep "<value>" | sed 's/.*<value>\(.*\)<\/value>.*/\1/')
if [ -z "$RM_LIST" ]; then
  echo "Error: Could not find yarn.resourcemanager.ha.rm-ids in yarn-site.xml"
  exit 1
fi

if ! echo "$RM_LIST" | grep -q "\brm$NEW_MASTER\b"; then
  NEW_RM_LIST="$RM_LIST,rm$NEW_MASTER"
  sed -i "s/<value>$RM_LIST<\/value>/<value>$NEW_RM_LIST<\/value>/" yarn-site.xml
  echo "Updated ResourceManager list: $NEW_RM_LIST"
else
  echo "ResourceManager rm$NEW_MASTER already in the list"
fi

# Check for yarn.resourcemanager.zk-address
if grep -q "yarn.resourcemanager.zk-address" yarn-site.xml; then
  ZK_ADDRESS=$(grep -A1 "yarn.resourcemanager.zk-address" yarn-site.xml | grep "<value>" | sed 's/.*<value>\(.*\)<\/value>.*/\1/')
  
  # Check if m4 is already in the ZK address list
  if ! echo "$ZK_ADDRESS" | grep -q "m$NEW_MASTER:2181"; then
    NEW_ZK_ADDRESS="$ZK_ADDRESS,m$NEW_MASTER:2181"
    sed -i "s|<value>$ZK_ADDRESS<\/value>|<value>$NEW_ZK_ADDRESS<\/value>|" yarn-site.xml
    echo "Updated YARN ResourceManager ZK address: $NEW_ZK_ADDRESS"
  fi
fi

if ! grep -q "yarn.resourcemanager.hostname.rm$NEW_MASTER" yarn-site.xml; then
  sed -i "/<\/configuration>/i\\
  <property>\\
    <name>yarn.resourcemanager.hostname.rm$NEW_MASTER<\/name>\\
    <value>m$NEW_MASTER<\/value>\\
  <\/property>\\
  <property>\\
    <name>yarn.resourcemanager.address.rm$NEW_MASTER<\/name>\\
    <value>m$NEW_MASTER:8032<\/value>\\
  <\/property>\\
  <property>\\
    <name>yarn.resourcemanager.scheduler.address.rm$NEW_MASTER<\/name>\\
    <value>m$NEW_MASTER:8030<\/value>\\
  <\/property>\\
  <property>\\
    <name>yarn.resourcemanager.resource-tracker.address.rm$NEW_MASTER<\/name>\\
    <value>m$NEW_MASTER:8031<\/value>\\
  <\/property>\\
  <property>\\
    <name>yarn.resourcemanager.admin.address.rm$NEW_MASTER<\/name>\\
    <value>m$NEW_MASTER:8033<\/value>\\
  <\/property>\\
  <property>\\
    <name>yarn.resourcemanager.webapp.address.rm$NEW_MASTER<\/name>\\
    <value>m$NEW_MASTER:8088<\/value>\\
  <\/property>" yarn-site.xml
  echo "Added RM addresses for rm$NEW_MASTER"
fi

# Step 5: Update ZooKeeper configuration
if ! grep -q "server.$NEW_MASTER=m$NEW_MASTER:2888:3888" zoo.cfg; then
  echo -e "\nserver.$NEW_MASTER=m$NEW_MASTER:2888:3888" >> zoo.cfg
  echo "Updated ZooKeeper configuration with server.$NEW_MASTER"
fi

# Step 6: Update all existing masters with new configuration
for MASTER in $EXISTING_MASTERS; do
  echo "Updating configuration on $MASTER..."
  docker cp hdfs-site.xml $MASTER:/Data/hadoop-3.3.6/etc/hadoop/
  docker cp yarn-site.xml $MASTER:/Data/hadoop-3.3.6/etc/hadoop/
  docker cp core-site.xml $MASTER:/Data/hadoop-3.3.6/etc/hadoop/
  docker cp zoo.cfg $MASTER:/zookeeper-3.5.9/conf/
  
done

# Step 7: Update configuration on the new master if it exists
if docker ps --format '{{.Names}}' | grep -q "m$NEW_MASTER"; then
  echo "Updating configuration on m$NEW_MASTER..."
  docker cp hdfs-site.xml m$NEW_MASTER:/Data/hadoop-3.3.6/etc/hadoop/
  docker cp yarn-site.xml m$NEW_MASTER:/Data/hadoop-3.3.6/etc/hadoop/
  docker cp core-site.xml m$NEW_MASTER:/Data/hadoop-3.3.6/etc/hadoop/
  docker cp zoo.cfg m$NEW_MASTER:/zookeeper-3.5.9/conf/
  
  # Add explicit NameNode ID to hadoop-env.sh
  docker exec m$NEW_MASTER bash -c "echo 'export HDFS_NAMENODE_OPTS=\"\$HDFS_NAMENODE_OPTS -Ddfs.ha.namenode.id=m$NEW_MASTER\"' >> /Data/hadoop-3.3.6/etc/hadoop/hadoop-env.sh"
else
  echo "Container m$NEW_MASTER does not exist. Please create it before updating configurations."
  echo "Example: docker run -d --name m$NEW_MASTER --hostname m$NEW_MASTER --network sakr-ha_hadoop_network -p 5007$NEW_MASTER:50070 -p 809$NEW_MASTER:8088 --cpus=2.0 --memory=2G opt-ha"
fi

# Step 8: Update worker nodes
WORKER_NODES=$(docker ps --format '{{.Names}}' | grep -E '^w[0-9]+$')
for WORKER in $WORKER_NODES; do
  echo "Updating configuration on $WORKER..."
  docker cp hdfs-site.xml $WORKER:/Data/hadoop-3.3.6/etc/hadoop/
  docker cp yarn-site.xml $WORKER:/Data/hadoop-3.3.6/etc/hadoop/
  docker cp core-site.xml $WORKER:/Data/hadoop-3.3.6/etc/hadoop/
done

# Clean up temporary files
rm -f hdfs-site.xml yarn-site.xml core-site.xml zoo.cfg

echo "Configuration updated for all nodes."
echo "Restarting ..."
reboot
