# Orchestrator and Replication topology using Docker containers

## 1. Cloning Orchestrator

Link to the Orchestrator project in GitHub: https://github.com/github/orchestrator

To clone the project run:
```
$ git clone https://github.com/github/orchestrator.git
```

## 2. Building Orchestrator Docker Image

The Dockerfile is in the root of the cloned orchestrator project:
```
$ cd orchestrator
```
If you want to use *oraclelinux:7-slim* as OS instead of *alpine:3.6*, you can download this [Dockerfile](https://github.com/wagnerjfr/orchestrator-mysql-replication-docker/blob/master/Dockerfile) and replace by the existing one:
```
$ docker build -t orchestrator:latest .
```
To check whether the image was built, run:
```
$ docker images
```

## 3. Creating Docker Network:

Let's create a Docker so we can specify the IPs from each node:
```
$ docker network create --subnet=172.20.0.0/16 orchnet
```
To check whether the network was created, run:
```
$ docker network ls
```

## 4. Orchestrator in a container

We will create a container with Orchestrator image, define its network and set its IP
```
$ docker run --name orchestrator --net orchnet --ip 172.20.0.10 -p 3000:3000 orchestrator:latest
```
You will see the orchestrator start running.

## 5. Replication Topology using MySQLs in containers

Let's set up a replication topology M→S1, M→S2. You just need to run the commands below:

Creating 3 MySQL servers in containers:
```
for N in 1 2 3
  do docker run -d --name=node$N --hostname=node$N --net orchnet --ip "172.20.0.1$N" \
  -v $PWD/d$N:/var/lib/mysql -e MYSQL_ROOT_PASSWORD=mypass \
  mysql/mysql-server:5.7 \
  --server-id=$N \
  --enforce-gtid-consistency='ON' \
  --log-slave-updates='ON' \
  --gtid-mode='ON' \
  --log-bin='mysql-bin-1.log'
done
```
To see whether the MySQL Containers are ready run:
```
$ docker ps -a
```

The MySQL containers must be with status (healthy) and NOT (health: starting) to go the next step.

Setting master replication in node1:
```
docker exec -it node1 mysql -uroot -pmypass \
  -e "CREATE USER 'repl'@'%' IDENTIFIED BY 'slavepass';" \
  -e "GRANT REPLICATION SLAVE ON *.* TO 'repl'@'%';" \
  -e "SHOW MASTER STATUS;"
```
Setting slave replication on node2 and node3
```
for N in 2 3
  do docker exec -it node$N mysql -uroot -pmypass \
    -e "CHANGE MASTER TO MASTER_HOST='172.20.0.11', MASTER_PORT=3306, \
        MASTER_USER='repl', MASTER_PASSWORD='slavepass', MASTER_AUTO_POSITION = 1;"

  docker exec -it node$N mysql -uroot -pmypass -e "START SLAVE;"
done
```
Checking whether slaves are replicating. ***Slave_IO_Running: Yes*** and ***Slave_SQL_Running: Yes***.
:
```
$ docker exec -it node2 mysql -uroot -pmypass -e "SHOW SLAVE STATUS\G"
```
```
$ docker exec -it node3 mysql -uroot -pmypass -e "SHOW SLAVE STATUS\G"
```
Grant access to the Orchestrator so it can see the topology:
```
docker exec -it node1 mysql -uroot -pmypass \
  -e "CREATE USER 'orc_client_user'@'172.20.0.10' IDENTIFIED BY 'orc_client_password';" \
  -e "GRANT SUPER, PROCESS, REPLICATION SLAVE, RELOAD ON *.* TO 'orc_client_user'@'172.20.0.10';" \
  -e "GRANT SELECT ON mysql.slave_master_info TO 'orc_client_user'@'172.20.0.10';"
```
## 6. Orchestrator commands: discover and topology

Now it's time to run the commands in Orchestrator container so it can find the topology:

To discover the topology:
```
$ docker exec -it orchestrator ./orchestrator -c discover -i 172.20.0.11:3306 --debug
```
To see the topology:
```
$ docker exec -it orchestrator ./orchestrator -c topology -i 172.20.0.11:3306
```
You can also see it accessing: http://localhost:3000

![alt text](https://github.com/wagnerjfr/orchestrator-mysql-replication-docker/blob/master/orchestrator.png)

## 7. Clean up

Stopping the containers:
```
$ docker stop orchestrator node1 node2 node3
```
Removing the stopped containers
```
$ docker rm orchestrator node1 node2 node3
```
Deleting data directories:
```
$ sudo rm -rf d1 d2 d3
```
