#!/bin/bash

###
# Инициализация реплика-сета сервера конфигурации (3 ноды)
###

docker compose exec -T configSrv1 mongosh --port 27017 --quiet <<EOF
rs.initiate(
  {
    _id : "config_server",
    configsvr: true,
    members: [
      { _id : 0, host : "configSrv1:27017" },
      { _id : 1, host : "configSrv2:27017" },
      { _id : 2, host : "configSrv3:27017" }
    ]
  }
);
EOF

sleep 5

###
# Инициализация реплика-сета шарда 1 (3 ноды)
###

docker compose exec -T shard1-1 mongosh --port 27018 --quiet <<EOF
rs.initiate(
  {
    _id : "shard1",
    members: [
      { _id : 0, host : "shard1-1:27018" },
      { _id : 1, host : "shard1-2:27018" },
      { _id : 2, host : "shard1-3:27018" }
    ]
  }
);
EOF

sleep 5

###
# Инициализация реплика-сета шарда 2 (3 ноды)
###

docker compose exec -T shard2-1 mongosh --port 27019 --quiet <<EOF
rs.initiate(
  {
    _id : "shard2",
    members: [
      { _id : 0, host : "shard2-1:27019" },
      { _id : 1, host : "shard2-2:27019" },
      { _id : 2, host : "shard2-3:27019" }
    ]
  }
);
EOF

sleep 5

###
# Инициализация роутера и наполнение данными
###

docker compose exec -T mongos_router mongosh --port 27020 --quiet <<EOF
sh.addShard("shard1/shard1-1:27018,shard1-2:27018,shard1-3:27018");
sh.addShard("shard2/shard2-1:27019,shard2-2:27019,shard2-3:27019");

sh.enableSharding("somedb");
sh.shardCollection("somedb.helloDoc", { "name" : "hashed" });

use somedb
for(var i = 0; i < 1000; i++) db.helloDoc.insertOne({age:i, name:"ly"+i})

db.helloDoc.countDocuments()
EOF

###
# Проверка количества документов на шардах
###

echo ""
echo "===== Проверка количества документов на shard1 ====="
docker compose exec -T shard1-1 mongosh --port 27018 --quiet <<EOF
use somedb
db.helloDoc.countDocuments()
EOF

echo ""
echo "===== Проверка количества документов на shard2 ====="
docker compose exec -T shard2-1 mongosh --port 27019 --quiet <<EOF
use somedb
db.helloDoc.countDocuments()
EOF

###
# Проверка статуса репликации
###

echo ""
echo "===== Статус реплика-сета config_server ====="
docker compose exec -T configSrv1 mongosh --port 27017 --quiet <<EOF
rs.status().members.forEach(m => print(m.name + " — " + m.stateStr))
EOF

echo ""
echo "===== Статус реплика-сета shard1 ====="
docker compose exec -T shard1-1 mongosh --port 27018 --quiet <<EOF
rs.status().members.forEach(m => print(m.name + " — " + m.stateStr))
EOF

echo ""
echo "===== Статус реплика-сета shard2 ====="
docker compose exec -T shard2-1 mongosh --port 27019 --quiet <<EOF
rs.status().members.forEach(m => print(m.name + " — " + m.stateStr))
EOF
