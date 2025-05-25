# Hadoop High Availability Cluster Documentation

## Overview

This Docker-based Hadoop cluster provides high availability using:
- **HDFS HA**: 3 NameNodes with ZooKeeper-based failover
- **YARN HA**: 3 ResourceManagers with automatic failover
- **ZooKeeper Quorum**: 3-node cluster for coordination
- **Dynamic Scaling**: Automated script for adding master nodes

## Architecture

```
Master Nodes (m1, m2, m3):
├── NameNode (Active/Standby)
├── ResourceManager (Active/Standby) 
├── JournalNode
└── ZooKeeper

Worker Nodes (w1, w2, w3):
├── DataNode
└── NodeManager
```

## Prerequisites

### System Requirements
- **Docker**: 20.10+
- **Docker Compose**: 2.0+
- **Memory**: Minimum 8GB RAM (16GB recommended)
- **Storage**: 50GB+ available disk space
- **Network**: All nodes must be able to communicate on required ports

### Required Ports
| Service | Port | Description |
|---------|------|-------------|
| NameNode RPC | 9000 | HDFS client communication |
| NameNode Web UI | 50070 | NameNode web interface |
| ResourceManager | 8032 | YARN client communication |
| ResourceManager Web UI | 8088 | YARN web interface |
| JournalNode | 8485 | Edit log synchronization |
| ZooKeeper | 2181 | Client connections |
| ZooKeeper Peer | 2888 | Peer communication |
| ZooKeeper Election | 3888 | Leader election |

## Configuration Files

### Core Configuration (`core-site.xml`)
```xml
<configuration>
    <property>
        <name>fs.defaultFS</name>
        <value>hdfs://sakrcluster</value>
        <description>Default filesystem URI - points to HA nameservice</description>
    </property>
    <property>
        <name>ha.zookeeper.quorum</name>
        <value>m1:2181,m2:2181,m3:2181</value>
        <description>ZooKeeper ensemble for HA coordination</description>
    </property>
</configuration>
```

### HDFS Configuration (`hdfs-site.xml`)
Key HA settings:
- **Nameservice**: `sakrcluster` with 3 NameNodes (m1, m2, m3)
- **Replication Factor**: 3 for data redundancy
- **Journal Nodes**: Shared edit log storage across all master nodes
- **Automatic Failover**: Enabled with ZooKeeper coordination
- **Fencing**: Uses shell script fencing method

### YARN Configuration (`yarn-site.xml`)
- **ResourceManager HA**: 3 RMs (rm1, rm2, rm3) on master nodes
- **ZooKeeper State Store**: Persistent state storage for failover
- **Automatic Failover**: Enabled with leader election

### ZooKeeper Configuration (`zoo.cfg`)
- **3-node quorum**: m1, m2, m3
- **Data directory**: `/Data/zookeeper`
- **Autopurge**: Enabled with 1-hour interval

## Deployment

### Step 1: Environment Setup
```bash
# Clone repository
git clone <repository-url>
cd hadoop-high-availability-cluster

# Ensure Docker and Docker Compose are installed
docker --version
docker-compose --version
```

### Step 2: Build Images
```bash
# Build Hadoop image
docker build -t hadoop-ha:latest ./Hadoop/

# Build HBase image (if using)
docker build -t hbase-ha:latest ./hbase/

# Build Hive image (if using)  
docker build -t hive-ha:latest ./Hive/
```

### Step 3: Deploy Cluster
```bash
# Start all services
docker-compose up -d

# Check service status
docker-compose ps

# Monitor logs
docker-compose logs -f
```

### Step 4: Verify Deployment

#### Check HDFS Status
```bash
# Access any master node
docker exec -it <master-container> bash

# Check cluster status
hdfs dfsadmin -report

# Check NameNode HA status
hdfs haadmin -getAllServiceState
```

#### Check YARN Status  
```bash
# Check ResourceManager status
yarn rmadmin -getAllServiceState

# View cluster info
yarn node -list
```

#### Check ZooKeeper Status
```bash
# Connect to ZooKeeper CLI
zkCli.sh -server m1:2181

# List HA paths
ls /hadoop-ha
ls /rmstore
```

## Service Startup Sequence

The entrypoint script handles the following startup sequence:

### Master Nodes (m1, m2, m3):
1. **SSH Service**: Started for inter-node communication
2. **ZooKeeper ID Setup**: Based on hostname pattern
3. **JournalNode**: Started on all masters first
4. **Primary Master (m1)**:
   - Format NameNode (if not already formatted)
   - Start NameNode
   - Start ZooKeeper
   - Format ZKFC (if not already done)
   - Start ZKFC
   - Create YARN ZooKeeper paths
5. **Secondary Masters (m2, m3)**:
   - Bootstrap Standby NameNode
   - Start ZooKeeper
   - Start NameNode
   - Start ZKFC
6. **ResourceManager**: Started on all masters

### Worker Nodes (w*):
1. **SSH Service**: Started
2. **Wait**: 30-second delay for masters to initialize
3. **DataNode**: Started for HDFS storage
4. **NodeManager**: Started for YARN compute

## Dynamic Scaling

### Adding Master Nodes
The cluster includes a dynamic scaling script (`add_master.sh`) to add new master nodes:

```bash
# Add a new master node (e.g., m4)
./add_master.sh 4

# This script automatically:
# 1. Extracts current configurations from existing masters
# 2. Updates ZooKeeper quorum settings
# 3. Adds new NameNode and ResourceManager configurations
# 4. Updates all existing nodes with new configs
# 5. Configures the new master if container exists
```

### Manual Master Addition Process
For adding masters manually:

1. **Update configurations**:
   ```bash
   # Update hdfs-site.xml to include new NameNode
   # Update yarn-site.xml to include new ResourceManager  
   # Update zoo.cfg to include new ZooKeeper server
   # Update core-site.xml ZooKeeper quorum
   ```

2. **Create new container**:
   ```bash
   docker run -d --name m4 --hostname m4 \
     --network hadoop_network \
     -p 50074:50070 -p 8094:8088 \
     --cpus=2.0 --memory=2G hadoop-ha:latest
   ```

3. **Restart services** for configuration changes to take effect

### Adding Worker Nodes
```bash
# Update docker-compose.yml with new worker services
docker-compose up -d w4 w5

# Verify nodes join cluster
yarn node -list
```

## Monitoring and Management

### Web Interfaces
- **Active NameNode**: http://\<active-master\>:50070
- **Active ResourceManager**: http://\<active-rm\>:8088
- **DataNode**: http://\<worker\>:50075
- **NodeManager**: http://\<worker\>:8042

### Health Checks
```bash
# HDFS health
hdfs fsck /

# YARN applications
yarn application -list

# Check service status
docker-compose ps
```

### Log Locations
- **Hadoop Logs**: `/Data/hadoop-3.3.6/logs/`
- **ZooKeeper Logs**: `/zookeeper-3.5.9/logs/`
- **Container Logs**: `docker-compose logs <service-name>`

## Troubleshooting

### Common Operations

#### 1. NameNode Management
```bash
# Check if NameNode is formatted
ls -la /Data/hadoop-3.3.6/namenode/current/

# Format NameNode (destructive operation)
hdfs namenode -format -force
```

#### 2. ZooKeeper Operations
```bash
# Check ZooKeeper status
zkServer.sh status

# Test connectivity
telnet m1 2181
```

#### 3. Failover Management
```bash
# Check ZKFC status
hdfs haadmin -getServiceState nn1
hdfs haadmin -getServiceState nn2

# Manual failover
hdfs haadmin -transitionToActive nn2 --forcemanual
```

#### 4. Journal Node Management
```bash
# Check JournalNode status
jps | grep JournalNode

# Verify journal directory
ls -la /Data/hadoop-3.3.6/data/jn/
```

### Recovery Procedures

#### NameNode Recovery
```bash
# Standby automatically becomes active on failure
# Manual failover if needed:
hdfs haadmin -transitionToActive nn2 --forcemanual
```

#### ResourceManager Recovery
```bash
# Check RM state
yarn rmadmin -getServiceState rm1

# Manual failover
yarn rmadmin -transitionToActive rm2
```

## Performance Tuning

### JVM Memory Settings
Configure in hadoop-env.sh:

```bash
# Recommended production settings
export HADOOP_HEAPSIZE_MAX=2048m
export HDFS_NAMENODE_OPTS="-Xmx4g -Xms4g"
export YARN_RESOURCEMANAGER_OPTS="-Xmx4g -Xms4g"
```

### Network Optimization
```xml
<!-- In hdfs-site.xml -->
<property>
    <name>dfs.namenode.handler.count</name>
    <value>20</value>
</property>
```

### Resource Allocation
Update in yarn-site.xml:
```xml
<property>
    <name>yarn.nodemanager.resource.memory-mb</name>
    <value>8192</value>
</property>
<property>
    <name>yarn.nodemanager.resource.cpu-vcores</name>
    <value>4</value>
</property>
```

## Security Configuration

### Current Setup
- Development-focused configuration
- Simplified authentication for testing
- Standard Hadoop security practices

### Production Enhancements
For production deployment, consider:
- Kerberos authentication setup
- SSL/TLS encryption
- Custom SSH key management
- Firewall configuration
- Audit logging setup

## Backup and Recovery

### Critical Data Locations
- **NameNode metadata**: `/Data/hadoop-3.3.6/namenode/`
- **ZooKeeper data**: `/Data/zookeeper/`
- **Journal logs**: `/Data/hadoop-3.3.6/data/jn/`

### Backup Script Example
```bash
#!/bin/bash
BACKUP_DIR="/backup/$(date +%Y%m%d)"
mkdir -p $BACKUP_DIR

# Backup NameNode metadata
docker exec <namenode-container> hdfs dfsadmin -saveNamespace
docker cp <namenode-container>:/Data/hadoop-3.3.6/namenode $BACKUP_DIR/

# Backup ZooKeeper data
docker cp <zk-container>:/Data/zookeeper $BACKUP_DIR/
```

## Development and Testing

### Configuration Changes
1. Modify configuration files in `./configs/`
2. Rebuild Docker images
3. Test with `docker-compose up --build`
4. Validate cluster functionality

### Adding Services
1. Create new Dockerfile in service directory
2. Add service to docker-compose.yml
3. Update networking and dependencies
4. Add monitoring endpoints

## System Features

### High Availability Features
- **Automatic Failover**: ZooKeeper-coordinated failover for both HDFS and YARN
- **Data Replication**: 3x replication factor for data durability
- **Journal Node Quorum**: Shared edit logs across master nodes
- **Split-brain Prevention**: ZooKeeper consensus prevents conflicting states

### Scalability Features
- **Dynamic Master Addition**: Automated script for cluster expansion
- **Worker Node Scaling**: Simple docker-compose scaling
- **Resource Management**: Configurable CPU and memory allocation
- **Load Distribution**: Multiple active services for load balancing

---

This cluster provides a robust foundation for big data processing with high availability and scalability features suitable for development, testing, and production environments.