# Hadoop High Availability Cluster

A comprehensive, production-ready big data ecosystem with high availability, fault tolerance, and horizontal scaling capabilities. This cluster integrates Apache Hadoop, HBase, Hive, and Apache NiFi in a containerized environment with automatic failover and load balancing.

## 🏗️ Architecture Overview

```
┌─────────────────────────────────────────────────────────────────┐
│                    Big Data Ecosystem                           │
├─────────────────────────────────────────────────────────────────┤
│  Data Ingestion Layer                                           │
│  ├── Apache NiFi (Data Flow Management)                         │
│                                                                 │
│  Data Processing Layer                                          │
│  ├── Apache Hive (Data Warehouse)                               │
│  │   ├── HiveServer2 Cluster (3 nodes + Load Balancer)          │
│  │   └── Shared Metastore with PostgreSQL                       │
│                                                                 │
│  Data Storage Layer                                             │
│  ├── Apache HBase (NoSQL Database)                              │
│  │   ├── Masters: hm1 (Primary), hm2 (Backup)                   │
│  │   └── RegionServers: rs1, rs2, rs3                           │
│  └── Apache Hadoop HDFS (Distributed File System)               │
│      ├── NameNodes: m1, m2, m3 (High Availability)              │
│      └── DataNodes: w1, w2 + RegionServers                      │
│                                                                 │
│  Resource Management Layer                                      │
│  ├── Apache YARN (Resource Manager)                             │
│  │   └── ResourceManagers: m1, m2, m3 (High Availability)       │
│  └── Apache Tez (Execution Engine for Hive)                     │
│                                                                 │
│  Coordination Layer                                             │
│  └── Apache ZooKeeper (Cluster Coordination)                    │
│      └── Ensemble: m1, m2, m3                                   │
└─────────────────────────────────────────────────────────────────┘
```

## 🚀 Key Features

### High Availability & Fault Tolerance
- **HDFS HA**: 3 NameNodes with automatic failover via ZooKeeper
- **YARN HA**: 3 ResourceManagers with leader election
- **HBase HA**: Primary/Backup masters with distributed RegionServers
- **Hive HA**: Load-balanced HiveServer2 instances with shared metastore
- **Automatic Recovery**: Self-healing services with health monitoring

### Scalability & Performance
- **Horizontal Scaling**: Dynamic addition of master and worker nodes
- **Load Balancing**: HAProxy for Hive connections with health checks
- **Resource Management**: Configurable CPU and memory limits
- **Optimized Execution**: Tez engine for high-performance query processing
- **Data Replication**: 3x replication factor for data durability

### Production Ready
- **Containerized Deployment**: Docker Compose orchestration
- **Persistent Storage**: Docker volumes for data persistence
- **Health Monitoring**: Comprehensive health checks and auto-restart
- **Web Interfaces**: Management UIs for all components
- **Logging**: Centralized logging with container log aggregation

## 📋 Prerequisites

### System Requirements
- **OS**: Linux (Ubuntu 20.04+ recommended)
- **Docker**: 20.10+
- **Docker Compose**: 2.0+
- **Memory**: 16GB+ RAM (32GB recommended for production)
- **Storage**: 100GB+ available disk space
- **CPU**: 8+ cores recommended

### Network Ports
| Service | Port | Description |
|---------|------|-------------|
| Hadoop NameNode UI | 50778-50779 | HDFS management interface |
| YARN ResourceManager | 8087-8089 | Resource management UI |
| HBase Master | 16010-16011 | HBase management interface |
| HBase RegionServer | 16030-16032 | RegionServer monitoring |
| Hive (Load Balanced) | 10010 | Main Hive connection point |
| Hive Metastore | 9083 | Metastore service |
| PostgreSQL | 6432 | Metastore database |
| Apache NiFi | 9900 | Data flow management |
| HAProxy Stats | 8404 | Load balancer statistics |

## 🛠️ Quick Start

### 1. Clone Repository
```bash
git clone https://github.com/your-username/hadoop-high-availability-cluster.git
cd hadoop-high-availability-cluster
```

### 2. Build Images
```bash
# Build base Hadoop image
docker build -t opt-ha ./Hadoop/

# Build HBase image
docker build -t hbase-unified ./hbase/

# Build Hive image
docker build -t hive ./Hive/

# Build HAProxy image
docker build -t haproxy ./Hive/HA\ Proxy/
```

### 3. Deploy Cluster
```bash
# Start the entire ecosystem
docker-compose up -d

# Monitor deployment progress
docker-compose logs -f

# Check service health
docker-compose ps
```

### 4. Verify Installation
```bash
# Check HDFS cluster status
docker exec m1 hdfs dfsadmin -report

# Check YARN cluster
docker exec m1 yarn node -list

# Check HBase cluster
docker exec hm1 hbase shell -n -e "status"

# Connect to Hive
docker exec hive-1 beeline -u "jdbc:hive2://localhost:10000/default"

# Access NiFi (Browser)
# https://localhost:9900
# Username: sakr, Password: HolyMolyNifi$
```

## 🔧 Configuration

### Cluster Configuration Files
- **Hadoop**: `./Hadoop/configs/`
  - `core-site.xml`, `hdfs-site.xml`, `yarn-site.xml`
  - `hadoop-env.sh`, `yarn-env.sh`
- **HBase**: `./hbase/`
  - `hbase-site.xml`, `regionservers`, `backup-masters`
- **Hive**: `./Hive/`
  - `hive-site.xml`, `metastore-site.xml`, `tez-site.xml`
- **ZooKeeper**: `./Hadoop/configs/zoo.cfg`

### Resource Allocation
Default resource limits per container:
- **Masters (m1, m2, m3)**: 2 CPU, 2GB RAM
- **Workers (w1, w2)**: 2 CPU, 2GB RAM  
- **HBase RegionServers**: 2 CPU, 3GB RAM
- **Hive Services**: 2 CPU, 2GB RAM

Modify in `docker-compose.yml`:
```yaml
deploy:
  resources:
    limits:
      cpus: "4.0"
      memory: "4G"
```

## 📊 Usage Examples

### HDFS Operations
```bash
# Create directory
docker exec m1 hdfs dfs -mkdir /user/data

# Upload file
docker exec m1 hdfs dfs -put /local/file.txt /user/data/

# List files
docker exec m1 hdfs dfs -ls /user/data

# Check file system
docker exec m1 hdfs fsck /
```

### Hive Data Warehouse
```sql
-- Connect via load balancer
beeline -u "jdbc:hive2://localhost:10010/default"

-- Create database and table
CREATE DATABASE sales;
USE sales;

CREATE TABLE customers (
    id INT,
    name STRING,
    email STRING,
    created_date DATE
) STORED AS PARQUET;

-- Insert and query data
INSERT INTO customers VALUES 
(1, 'John Doe', 'john@example.com', '2024-01-15');

SELECT * FROM customers WHERE created_date > '2024-01-01';
```

### HBase NoSQL Operations
```bash
# Access HBase shell
docker exec hm1 hbase shell

# Create table
create 'user_profiles', 'personal', 'activity'

# Insert data
put 'user_profiles', 'user1', 'personal:name', 'Alice Smith'
put 'user_profiles', 'user1', 'personal:age', '28'
put 'user_profiles', 'user1', 'activity:last_login', '2024-01-15'

# Query data
get 'user_profiles', 'user1'
scan 'user_profiles'
```

## 🔄 Scaling Operations

### Add Master Node
```bash
# Use the provided scaling script
./add_master.sh 4

# Or manually add to docker-compose.yml and restart
docker-compose up -d m4
```

### Add Worker Nodes
```bash
# Add worker definition to docker-compose.yml
docker-compose up -d w3 w4

# Verify new nodes
docker exec m1 yarn node -list
```

### Add HBase RegionServers
```bash
# Update regionservers file and deploy
echo "rs4" >> ./hbase/regionservers
docker-compose up -d rs4
```

## ⚡ Performance Tuning

### JVM Memory Settings
```bash
# Hadoop services (in hadoop-env.sh)
export HADOOP_HEAPSIZE_MAX=4096m
export HDFS_NAMENODE_OPTS="-Xmx4g -Xms4g"

# HBase services (in hbase-env.sh)
export HBASE_HEAPSIZE=4G
export HBASE_REGIONSERVER_OPTS="-Xms4G -Xmx4G"
```

### Hive Query Optimization
```sql
-- Enable vectorization and CBO
SET hive.vectorized.execution.enabled=true;
SET hive.cbo.enable=true;
SET hive.exec.parallel=true;

-- Configure Tez
SET hive.execution.engine=tez;
SET tez.queue.name=default;
```

## 🔍 Monitoring & Management

### Web Interfaces
- **Hadoop NameNode**: http://localhost:50778
- **YARN ResourceManager**: http://localhost:8088  
- **HBase Master**: http://localhost:16010
- **HAProxy Stats**: http://localhost:8404
- **Apache NiFi**: https://localhost:9900

### Health Monitoring
```bash
# Check all services
docker-compose ps

# Monitor specific service logs
docker-compose logs -f hive-1

# Check cluster health
./scripts/health_check.sh
```

### Backup Operations
```bash
# Backup HDFS metadata
docker exec m1 hdfs dfsadmin -saveNamespace

# Backup Hive metastore
docker exec metagres pg_dump -U hive metastore > backup.sql

# Backup HBase data
docker exec hm1 hbase shell -n -e "snapshot 'mytable', 'backup_snapshot'"
```

## 🛡️ Security Notes

This cluster is configured for development and testing environments. For production deployment, implement:

- **Authentication**: Configure Kerberos for secure authentication
- **Authorization**: Set up proper access controls and permissions  
- **Encryption**: Enable SSL/TLS for data in transit
- **Network Security**: Configure firewalls and network segmentation
- **Audit Logging**: Enable comprehensive audit trails

## 🔧 Troubleshooting

### Common Issues

#### Services Not Starting
```bash
# Check container logs
docker-compose logs <service-name>

# Verify dependencies
docker-compose ps

# Restart specific service
docker-compose restart <service-name>
```

#### Network Connectivity
```bash
# Test inter-container connectivity
docker exec m1 ping hm1

# Check port availability
docker exec m1 netstat -tlnp | grep 9000
```

#### Resource Issues
```bash
# Check container resource usage
docker stats

# Increase memory limits in docker-compose.yml
# Restart affected services
```


## 🤝 Contributing

1. Fork the repository
2. Create feature branch (`git checkout -b feature/new-feature`)
3. Commit changes (`git commit -am 'Add new feature'`)
4. Push to branch (`git push origin feature/new-feature`)
5. Create Pull Request

---

**⚡ Ready to process big data at scale with enterprise-grade reliability!**

[![Docker](https://img.shields.io/badge/Docker-20.10+-blue.svg)](https://www.docker.com/)
[![Hadoop](https://img.shields.io/badge/Hadoop-3.3.6-yellow.svg)](https://hadoop.apache.org/)
[![HBase](https://img.shields.io/badge/HBase-2.4.18-red.svg)](https://hbase.apache.org/)
[![Hive](https://img.shields.io/badge/Hive-4.0.1-orange.svg)](https://hive.apache.org/)
[![License](https://img.shields.io/badge/License-Apache%202.0-green.svg)](https://opensource.org/licenses/Apache-2.0)