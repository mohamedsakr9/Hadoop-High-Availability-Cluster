# Apache Hive High Availability Documentation

## Overview

This Apache Hive setup provides high availability and load balancing with:
- **Multiple HiveServer2 instances**: Load-balanced across 3 servers
- **Shared Metastore**: Single metastore service with PostgreSQL backend
- **HAProxy Load Balancer**: Automatic failover and request distribution
- **Tez Integration**: High-performance execution engine
- **Hadoop Integration**: Seamless integration with HA Hadoop cluster

## Architecture

```
Client Applications
        ↓
HAProxy Load Balancer (Port 10010)
        ↓
┌─────────────────────────────────────┐
│  HiveServer2 Cluster                │
├─ hive-1:10000 (HiveServer2)         │
├─ hive-2:10000 (HiveServer2)         │
└─ hive-3:10000 (HiveServer2)         │
        ↓
Shared Metastore (metastore:9083)
        ↓
PostgreSQL Database (metagres:5432)
        ↓
Hadoop HDFS Cluster (sakrcluster)
```

## Components

### HiveServer2 Nodes
- **Multiple instances**: hive-1, hive-2, hive-3
- **Load balanced**: HAProxy distributes connections
- **Tez execution**: Uses Apache Tez for query processing
- **Shared configuration**: Consistent setup across all nodes

### Metastore Service
- **Centralized metadata**: Single metastore for all HiveServer2 instances
- **PostgreSQL backend**: Persistent metadata storage
- **Schema management**: Automatic schema initialization
- **Thrift interface**: Standard Hive metastore protocol

### HAProxy Load Balancer
- **Connection distribution**: Round-robin load balancing
- **Health checks**: Automatic failure detection
- **Port mapping**: External port 10010 → internal port 10000
- **High availability**: Transparent failover

## Configuration Files

### Hive Configuration (`hive-site.xml`)
```xml
<configuration>
  <property>
    <name>hive.metastore.uris</name>
    <value>thrift://metastore:9083</value>
  </property>
  
  <property>
    <name>hive.server2.thrift.port</name>
    <value>10000</value>
  </property>
  
  <property>
    <name>hive.server2.authentication</name>
    <value>NONE</value>
  </property>
  
  <property>
    <name>hive.execution.mode</name>
    <value>container</value>
  </property>
  
  <property>
    <name>tez.lib.uris</name>
    <value>hdfs:///apps/tez/lib</value>
  </property>
</configuration>
```

### Metastore Configuration (`metastore-site.xml`)
```xml
<configuration>
  <property>
    <name>javax.jdo.option.ConnectionURL</name>
    <value>jdbc:postgresql://metagres:5432/metastore</value>
  </property>
  
  <property>
    <name>javax.jdo.option.ConnectionUserName</name>
    <value>hive</value>
  </property>
  
  <property>
    <name>metastore.thrift.port</name>
    <value>9083</value>
  </property>
</configuration>
```

### Tez Configuration (`tez-site.xml`)
```xml
<configuration>
  <property>
    <name>tez.lib.uris</name>
    <value>hdfs:///apps/tez/tez.tar.gz</value>
  </property>
  
  <property>
    <name>tez.am.resource.memory.mb</name>
    <value>2048</value>
  </property>
  
  <property>
    <name>tez.task.resource.memory.mb</name>
    <value>1024</value>
  </property>
</configuration>
```

### HAProxy Configuration (`haproxy.cfg`)
```
frontend hiveserver2
    bind *:10010
    default_backend hiveserver2_nodes

backend hiveserver2_nodes
    balance roundrobin
    server hive-1 hive-1:10000 check
    server hive-2 hive-2:10000 check
    server hive-3 hive-3:10000 check
```

## Deployment

### Prerequisites
- Hadoop HA cluster running and accessible
- PostgreSQL database for metastore
- Docker and Docker Compose
- Base Hadoop image (`opt-ha`) available

### Step 1: Build Hive Images
```bash
# Build main Hive image
docker build -t hive-ha:latest ./Hive/

# Build HAProxy load balancer
docker build -t hive-proxy:latest ./Hive/HA\ Proxy/
```

### Step 2: Deploy Services
```bash
# Start PostgreSQL metastore database
docker-compose up -d metagres

# Start Hive metastore
docker-compose up -d metastore

# Wait for metastore initialization
sleep 30

# Start HiveServer2 instances
docker-compose up -d hive-1 hive-2 hive-3

# Start HAProxy load balancer
docker-compose up -d hive-proxy
```

### Step 3: Verify Deployment
```bash
# Check service status
docker-compose ps

# Test connection through load balancer
beeline -u "jdbc:hive2://localhost:10010/default"
```

## Service Startup Process

### Metastore Container
1. **Hadoop Wait**: Waits for HDFS availability
2. **Schema Initialize**: Initializes PostgreSQL schema (first run only)
3. **Metastore Start**: Starts Hive metastore service on port 9083
4. **Tez Setup**: 
   - Creates HDFS directories `/apps/tez/lib`
   - Uploads Tez libraries to HDFS
   - Configures Tez for distributed execution

### HiveServer2 Containers
1. **Hadoop Wait**: Waits for HDFS availability
2. **Metastore Wait**: Waits for metastore service
3. **Service Start**: Starts HiveServer2 on port 10000
4. **Log Monitoring**: Tails service logs

### HAProxy Container
1. **Configuration Load**: Loads haproxy.cfg
2. **Health Checks**: Monitors HiveServer2 instances
3. **Load Balancing**: Distributes incoming connections

## Connection Methods

### Through Load Balancer (Recommended)
```bash
# Beeline CLI
beeline -u "jdbc:hive2://hive-proxy:10010/default"

# JDBC Connection String
jdbc:hive2://hive-proxy:10010/default
```

### Direct Connection
```bash
# Connect to specific HiveServer2 instance
beeline -u "jdbc:hive2://hive-1:10000/default"
beeline -u "jdbc:hive2://hive-2:10000/default"
beeline -u "jdbc:hive2://hive-3:10000/default"
```

### External Access
```bash
# If exposed through Docker port mapping
beeline -u "jdbc:hive2://localhost:10010/default"
```

## Query Execution

### Tez Engine Benefits
- **Performance**: Optimized DAG execution
- **Memory Management**: Efficient memory utilization
- **Caching**: Intermediate result caching
- **Parallelism**: Enhanced parallel processing

### Example Queries
```sql
-- Create database
CREATE DATABASE IF NOT EXISTS test_db;
USE test_db;

-- Create table
CREATE TABLE sample_table (
    id INT,
    name STRING,
    date_created DATE
) STORED AS PARQUET;

-- Insert data
INSERT INTO sample_table VALUES 
(1, 'Alice', '2024-01-01'),
(2, 'Bob', '2024-01-02');

-- Query data
SELECT * FROM sample_table WHERE date_created > '2024-01-01';
```

## Monitoring and Management

### Service Health Checks
```bash
# Check HiveServer2 status
docker exec hive-1 jps | grep HiveServer2

# Check metastore status  
docker exec metastore jps | grep HiveMetastore

# Check HAProxy status
curl http://hive-proxy:8404/stats
```

### Log Monitoring
```bash
# HiveServer2 logs
docker exec hive-1 tail -f /hive/logs/hiveserver2.log

# Metastore logs
docker exec metastore tail -f /hive/logs/metastore.log

# HAProxy logs
docker logs hive-proxy
```

### Performance Monitoring
```bash
# Check YARN applications
yarn application -list

# Monitor Tez sessions
# Access HiveServer2 web UI on port 10002 (if enabled)

# Check HDFS usage
hdfs dfs -du -h /apps/tez
```

## High Availability Features

### Load Balancing
- **Round-robin**: Equal distribution across servers
- **Health checks**: Automatic unhealthy server removal
- **Session persistence**: Connection-level load balancing
- **Transparent failover**: Automatic retry on failure

### Fault Tolerance
- **Multiple HiveServer2**: Service continues if one fails
- **Shared metastore**: No metadata loss on server failure
- **PostgreSQL persistence**: Durable metadata storage
- **HDFS integration**: Leverages Hadoop HA capabilities

### Scalability
- **Horizontal scaling**: Add more HiveServer2 instances
- **Resource allocation**: Configurable memory and CPU
- **Concurrent sessions**: Multiple simultaneous users
- **Query parallelism**: Tez DAG optimization

## Performance Tuning

### Memory Configuration
```xml
<!-- In hive-site.xml -->
<property>
    <name>hive.tez.container.size</name>
    <value>2048</value>
</property>

<!-- In tez-site.xml -->
<property>
    <name>tez.am.resource.memory.mb</name>
    <value>4096</value>
</property>
```

### Connection Pool Tuning
```xml
<!-- In hive-site.xml -->
<property>
    <name>hive.server2.async.exec.threads</name>
    <value>100</value>
</property>

<property>
    <name>hive.server2.thrift.max.worker.threads</name>
    <value>500</value>
</property>
```

### Query Optimization
```sql
-- Enable vectorization
SET hive.vectorized.execution.enabled=true;

-- Enable cost-based optimization
SET hive.cbo.enable=true;

-- Configure parallel execution
SET hive.exec.parallel=true;
SET hive.exec.parallel.thread.number=8;
```

## Troubleshooting

### Common Issues and Solutions

#### Connection Timeouts
```bash
# Check HAProxy backend status
echo "show stat" | socat stdio tcp4-connect:hive-proxy:8404

# Verify HiveServer2 is running
docker exec hive-1 netstat -tlnp | grep 10000
```

#### Metastore Connection Issues
```bash
# Test PostgreSQL connection
docker exec metastore psql -h metagres -U hive -d metastore -c "\l"

# Check metastore service
docker exec metastore netstat -tlnp | grep 9083
```

#### Tez Execution Problems
```bash
# Check Tez libraries in HDFS
hdfs dfs -ls /apps/tez/

# Verify Tez configuration
docker exec hive-1 grep -A 5 -B 5 "tez.lib.uris" /hive/conf/hive-site.xml
```

#### Schema Initialization
```bash
# Reinitialize schema (destructive)
docker exec metastore schematool -dbType postgres -initSchema --verbose

# Upgrade schema
docker exec metastore schematool -dbType postgres -upgradeSchema
```

## Backup and Recovery

### Metastore Backup
```bash
# Backup PostgreSQL database
docker exec metagres pg_dump -U hive metastore > metastore_backup.sql

# Restore database
docker exec -i metagres psql -U hive -d metastore < metastore_backup.sql
```

### Configuration Backup
```bash
# Backup Hive configurations
docker cp metastore:/hive/conf ./hive_conf_backup/
docker cp hive-1:/hive/conf ./hiveserver2_conf_backup/
```

## Development and Testing

### Adding HiveServer2 Instances
1. **Update docker-compose.yml**:
   ```yaml
   hive-4:
     image: hive-ha:latest
     hostname: hive-4
     depends_on:
       - metastore
   ```

2. **Update HAProxy configuration**:
   ```
   backend hiveserver2_nodes
       server hive-4 hive-4:10000 check
   ```

3. **Restart services**:
   ```bash
   docker-compose up -d hive-4
   docker-compose restart hive-proxy
   ```

### Custom Configuration
```bash
# Mount custom configurations
docker run -v ./custom-hive-site.xml:/hive/conf/hive-site.xml hive-ha:latest
```

### Testing Scenarios
```bash
# Test failover
docker stop hive-1
beeline -u "jdbc:hive2://hive-proxy:10010/default" -e "SHOW TABLES;"

# Test load distribution
# Connect multiple sessions and monitor distribution

# Test performance
# Run benchmark queries and measure execution time
```

## Integration

### External Tools
- **BI Tools**: Connect using JDBC URL `jdbc:hive2://hive-proxy:10010/default`
- **Spark**: Configure Hive metastore URI in Spark configuration
- **Data Pipeline Tools**: Use Hive JDBC driver for data ingestion

### API Access
```python
# Python example using PyHive
from pyhive import hive

conn = hive.Connection(host='hive-proxy', port=10010, database='default')
cursor = conn.cursor()
cursor.execute('SHOW TABLES')
tables = cursor.fetchall()
```

---

This Hive HA setup provides a robust, scalable data warehouse solution with automatic failover, load balancing, and high-performance query execution suitable for production environments.