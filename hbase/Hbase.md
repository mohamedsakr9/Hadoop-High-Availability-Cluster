# Apache HBase High Availability Documentation

## Overview

This Apache HBase setup provides high availability and scalability with:
- **Master-Backup Architecture**: Primary and backup HBase Masters
- **Distributed RegionServers**: Multiple RegionServers for data distribution
- **ZooKeeper Integration**: Coordination with existing Hadoop ZooKeeper cluster
- **HDFS Integration**: Seamless integration with HA Hadoop cluster
- **Automatic Failover**: ZooKeeper-managed master failover

## Architecture

```
HBase Masters:
├── hm1 (Primary Master)
└── hm2 (Backup Master)

RegionServers:
├── rs1 (RegionServer + DataNode + NodeManager)
├── rs2 (RegionServer + DataNode + NodeManager)
└── rs3 (RegionServer + DataNode + NodeManager)

External Dependencies:
├── ZooKeeper Cluster (m1, m2, m3)
├── HDFS Cluster (sakrcluster)
└── YARN Cluster
```

## Components

### HBase Masters
- **Primary Master (hm1)**: Main coordination and administrative functions
- **Backup Master (hm2)**: Standby master for automatic failover
- **Load Balancer**: Automatic region balancing across RegionServers
- **Web UI**: Management interface on port 16010

### RegionServers
- **Data Storage**: Handle read/write operations for HBase tables
- **Region Management**: Serve table regions and handle client requests
- **Integrated Services**: Combined with Hadoop DataNode and YARN NodeManager
- **Auto-recovery**: Service monitoring and restart capabilities

### Integration Layer
- **HDFS Storage**: HBase data stored in HDFS at `/hbase`
- **ZooKeeper Coordination**: Uses existing Hadoop ZooKeeper ensemble
- **YARN Integration**: Leverages YARN for resource management
- **Network Resolution**: Automatic host discovery and registration

## Configuration Files

### HBase Configuration (`hbase-site.xml`)
```xml
<configuration>
  <property>
    <name>hbase.cluster.distributed</name>
    <value>true</value>
  </property>
  
  <property>
    <name>hbase.rootdir</name>
    <value>hdfs://sakrcluster/hbase</value>
  </property>
  
  <property>
    <name>hbase.zookeeper.quorum</name>
    <value>m1,m2,m3</value>
  </property>
  
  <property>
    <name>hbase.master.info.port</name>
    <value>16010</value>
  </property>
  
  <property>
    <name>hbase.replication</name>
    <value>true</value>
  </property>
</configuration>
```

### Environment Configuration (`hbase-env.sh`)
```bash
export JAVA_HOME=/usr/lib/jvm/java-8-openjdk-amd64
export HBASE_MANAGES_ZK=false
export HBASE_HEAPSIZE=1G
export HBASE_LOG_DIR=/opt/hbase/logs
export HBASE_OPTS="$HBASE_OPTS -Djava.net.preferIPv4Stack=true"
```

### Cluster Configuration Files
- **regionservers**: Lists RegionServer nodes (rs1, rs2, rs3)
- **backup-masters**: Lists backup master nodes (hm2)

## Deployment

### Prerequisites
- Hadoop HA cluster running and accessible
- ZooKeeper ensemble operational
- Base Hadoop image (`opt-ha`) available
- Docker networking configured

### Step 1: Build HBase Image
```bash
# Build HBase image
docker build -t hbase-ha:latest ./hbase/
```

### Step 2: Deploy HBase Masters
```bash
# Start primary master
docker-compose up -d hm1

# Start backup master
docker-compose up -d hm2
```

### Step 3: Deploy RegionServers
```bash
# Start RegionServers (includes DataNode and NodeManager)
docker-compose up -d rs1 rs2 rs3
```

### Step 4: Verify Deployment
```bash
# Check service status
docker-compose ps

# Access HBase shell
docker exec -it hm1 hbase shell

# Check cluster status
docker exec -it hm1 hbase shell -n -e "status"
```

## Service Startup Process

### Master Nodes (hm1, hm2)
1. **SSH Service**: Start SSH daemon
2. **Host Resolution**: Update `/etc/hosts` with cluster IPs
3. **HDFS Availability**: Wait for HDFS cluster
4. **Directory Creation**: Create `/hbase` directory in HDFS
5. **Master Start**: Launch HBase Master process
6. **Service Monitoring**: Continuous health monitoring

### RegionServer Nodes (rs1, rs2, rs3)
1. **SSH Service**: Start SSH daemon
2. **Host Resolution**: Update `/etc/hosts` with cluster IPs
3. **Directory Setup**: Create required Hadoop directories
4. **DataNode Start**: Launch HDFS DataNode
5. **NodeManager Start**: Launch YARN NodeManager
6. **RegionServer Start**: Launch HBase RegionServer
7. **Service Monitoring**: Monitor and restart failed services

## High Availability Features

### Master Failover
- **Automatic Detection**: ZooKeeper detects master failures
- **Seamless Transition**: Backup master becomes active
- **Client Transparency**: Applications continue without interruption
- **State Recovery**: Master state recovered from ZooKeeper

### Data Availability
- **Region Distribution**: Data distributed across multiple RegionServers
- **HDFS Replication**: Underlying data replicated in HDFS
- **WAL (Write-Ahead Log)**: Transaction logs for data consistency
- **Region Recovery**: Automatic region reassignment on failure

### Service Recovery
- **Health Monitoring**: Continuous process monitoring
- **Automatic Restart**: Failed services restarted automatically
- **Dependency Management**: Service startup order maintained
- **Resource Allocation**: Proper directory and permission setup

## Operations and Management

### HBase Shell Commands
```bash
# Access HBase shell
docker exec -it hm1 hbase shell

# Basic operations
status                    # Cluster status
list                     # List tables
create 'test', 'cf'      # Create table
put 'test', 'row1', 'cf:col1', 'value1'  # Insert data
get 'test', 'row1'       # Retrieve data
scan 'test'              # Scan table
disable 'test'           # Disable table
drop 'test'              # Drop table
```

### Administrative Commands
```bash
# Check region assignments
echo "list_regions" | hbase shell

# Balance cluster
echo "balance_switch true" | hbase shell
echo "balancer" | hbase shell

# Check RegionServer status
echo "status 'simple'" | hbase shell
echo "status 'detailed'" | hbase shell
```

### Web Interfaces
- **HBase Master UI**: http://hm1:16010
- **RegionServer UI**: http://rs1:16030, http://rs2:16030, http://rs3:16030
- **HDFS UI**: Through Hadoop cluster
- **YARN UI**: Through Hadoop cluster

## Monitoring and Troubleshooting

### Service Health Checks
```bash
# Check HBase processes
docker exec hm1 jps | grep HMaster
docker exec rs1 jps | grep HRegionServer

# Check service logs
docker exec hm1 tail -f /opt/hbase/logs/hbase-huser-master-hm1.log
docker exec rs1 tail -f /opt/hbase/logs/hbase-huser-regionserver-rs1.log

# Check HDFS connectivity
docker exec hm1 hdfs dfs -ls /hbase
```

### Common Issues and Solutions

#### Master Startup Issues
```bash
# Check HDFS availability
docker exec hm1 hdfs dfs -ls /

# Verify ZooKeeper connectivity
docker exec hm1 hbase zkcli ls /hbase

# Check master logs
docker exec hm1 cat /opt/hbase/logs/hbase-huser-master-hm1.log
```

#### RegionServer Issues
```bash
# Check RegionServer registration
echo "status 'rs'" | docker exec -i hm1 hbase shell

# Verify network connectivity
docker exec rs1 ping hm1
docker exec rs1 telnet hm1 16000

# Restart RegionServer
docker exec rs1 /opt/hbase/bin/hbase-daemon.sh stop regionserver
docker exec rs1 /opt/hbase/bin/hbase-daemon.sh start regionserver
```

#### Network Resolution Issues
```bash
# Check hosts file
docker exec rs1 cat /etc/hosts

# Update host mappings
docker exec rs1 sudo /update-hosts.sh

# Test DNS resolution
docker exec rs1 nslookup hm1
```

## Performance Tuning

### Memory Configuration
```bash
# In hbase-env.sh
export HBASE_HEAPSIZE=2G
export HBASE_REGIONSERVER_OPTS="-Xms2G -Xmx2G"
export HBASE_MASTER_OPTS="-Xms1G -Xmx1G"
```

### Table Configuration
```bash
# Create table with performance settings
create 'mytable', {NAME => 'cf', COMPRESSION => 'SNAPPY', BLOCKSIZE => '65536'}

# Configure region splitting
alter 'mytable', {MAX_FILESIZE => '10737418240'}  # 10GB

# Enable bloom filters
alter 'mytable', {NAME => 'cf', BLOOMFILTER => 'ROW'}
```

### RegionServer Tuning
```xml
<!-- In hbase-site.xml -->
<property>
    <name>hbase.hregion.memstore.flush.size</name>
    <value>134217728</value>  <!-- 128MB -->
</property>

<property>
    <name>hbase.regionserver.global.memstore.size</name>
    <value>0.4</value>
</property>
```

## Backup and Recovery

### Data Backup
```bash
# Export table data
docker exec hm1 hbase org.apache.hadoop.hbase.mapreduce.Export mytable /backup/mytable

# Snapshot creation
echo "snapshot 'mytable', 'mytable_snapshot'" | docker exec -i hm1 hbase shell

# List snapshots
echo "list_snapshots" | docker exec -i hm1 hbase shell
```

### Configuration Backup
```bash
# Backup HBase configuration
docker cp hm1:/opt/hbase/conf ./hbase_conf_backup/

# Backup ZooKeeper HBase znodes
docker exec hm1 hbase zkcli ls /hbase > hbase_zk_backup.txt
```

### Recovery Procedures
```bash
# Restore from snapshot
echo "disable 'mytable'" | docker exec -i hm1 hbase shell
echo "restore_snapshot 'mytable_snapshot'" | docker exec -i hm1 hbase shell
echo "enable 'mytable'" | docker exec -i hm1 hbase shell

# Import table data
docker exec hm1 hbase org.apache.hadoop.hbase.mapreduce.Import mytable /backup/mytable
```

## Scaling Operations

### Adding RegionServers
1. **Update Configuration**:
   ```bash
   # Add new RegionServer to regionservers file
   echo "rs4" >> regionservers
   ```

2. **Deploy New Container**:
   ```bash
   docker run -d --name rs4 --hostname rs4 \
     --network hbase_network \
     -v hbase_data:/data \
     hbase-ha:latest
   ```

3. **Register RegionServer**:
   ```bash
   # RegionServer will auto-register with master
   echo "status 'rs'" | docker exec -i hm1 hbase shell
   ```

### Load Balancing
```bash
# Enable automatic balancing
echo "balance_switch true" | docker exec -i hm1 hbase shell

# Manual balance
echo "balancer" | docker exec -i hm1 hbase shell

# Check balance status
echo "balancer_enabled" | docker exec -i hm1 hbase shell
```

## Integration Examples

### Java Application Integration
```java
import org.apache.hadoop.hbase.HBaseConfiguration;
import org.apache.hadoop.hbase.client.Connection;
import org.apache.hadoop.hbase.client.ConnectionFactory;

Configuration config = HBaseConfiguration.create();
config.set("hbase.zookeeper.quorum", "m1,m2,m3");
config.set("hbase.zookeeper.property.clientPort", "2181");

Connection connection = ConnectionFactory.createConnection(config);
```

### Python Integration
```python
import happybase

# Connect to HBase
connection = happybase.Connection(host='hm1', port=9090)

# Create table
connection.create_table('mytable', {'cf': dict()})

# Insert data
table = connection.table('mytable')
table.put(b'row1', {b'cf:col1': b'value1'})

# Retrieve data
row = table.row(b'row1')
print(row)
```

### MapReduce Integration
```bash
# Run MapReduce job with HBase
docker exec hm1 hbase org.apache.hadoop.hbase.mapreduce.RowCounter mytable
```

## Security Considerations

### Current Configuration
- Development-focused setup
- No authentication required
- Standard HBase security practices
- Network isolation through Docker

### Production Security
- Configure Kerberos authentication
- Enable HBase authorization
- Set up SSL/TLS encryption
- Configure firewall rules
- Enable audit logging

## Maintenance

### Regular Tasks
```bash
# Compact tables
echo "major_compact 'mytable'" | docker exec -i hm1 hbase shell

# Clean up old WAL files
docker exec hm1 hbase org.apache.hadoop.hbase.util.HBaseFsck

# Check table consistency
echo "hbck" | docker exec -i hm1 hbase shell
```

### Log Management
```bash
# Rotate logs
docker exec hm1 find /opt/hbase/logs -name "*.log.*" -mtime +7 -delete

# Monitor log sizes
docker exec hm1 du -sh /opt/hbase/logs/*
```

---

This HBase HA setup provides a robust, distributed NoSQL database solution with automatic failover, horizontal scaling, and seamless integration with the existing Hadoop ecosystem.