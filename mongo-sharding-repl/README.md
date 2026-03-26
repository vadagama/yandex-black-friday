# mongo-sharding-repl

Проект разворачивает приложение pymongo-api с шардированным кластером MongoDB и репликацией (2 шарда по 3 реплики, 3 сервера конфигурации, 1 роутер).

## Архитектура

- **configSrv1, configSrv2, configSrv3** — реплика-сет сервера конфигурации (порт 27017)
- **shard1-1, shard1-2, shard1-3** — реплика-сет первого шарда (порт 27018)
- **shard2-1, shard2-2, shard2-3** — реплика-сет второго шарда (порт 27019)
- **mongos_router** — роутер (порт 27020)
- **pymongo_api** — приложение (порт 8080)

## Как запустить

### 1. Запуск контейнеров

```shell
docker compose up -d
```

Дождитесь, пока все контейнеры успешно стартуют (15-20 секунд):

```shell
docker compose ps
```

### 2. Инициализация шардирования, репликации и наполнение данными

```shell
./scripts/mongo-init.sh
```

Скрипт выполняет следующие шаги:

1. Инициализирует реплика-сет сервера конфигурации (`config_server`) из 3 нод: configSrv1, configSrv2, configSrv3.
2. Инициализирует реплика-сет первого шарда (`shard1`) из 3 нод: shard1-1, shard1-2, shard1-3.
3. Инициализирует реплика-сет второго шарда (`shard2`) из 3 нод: shard2-1, shard2-2, shard2-3.
4. Подключается к роутеру и:
   - добавляет оба шарда (с указанием всех реплик) в кластер;
   - включает шардирование для базы `somedb`;
   - шардирует коллекцию `helloDoc` с хешированным ключом `name`;
   - вставляет 1000 тестовых документов.
5. Выводит количество документов на каждом из шардов.
6. Выводит статус реплика-сетов (primary/secondary для каждой ноды).

### 3. Ручная инициализация (альтернативный способ)

Если нужно выполнить шаги вручную:

**Инициализация реплика-сета сервера конфигурации:**

```shell
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
```

**Инициализация реплика-сета шарда 1:**

```shell
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
```

**Инициализация реплика-сета шарда 2:**

```shell
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
```

**Настройка роутера и наполнение данными:**

```shell
docker compose exec -T mongos_router mongosh --port 27020 --quiet <<EOF
sh.addShard("shard1/shard1-1:27018,shard1-2:27018,shard1-3:27018");
sh.addShard("shard2/shard2-1:27019,shard2-2:27019,shard2-3:27019");

sh.enableSharding("somedb");
sh.shardCollection("somedb.helloDoc", { "name" : "hashed" });

use somedb
for(var i = 0; i < 1000; i++) db.helloDoc.insertOne({age:i, name:"ly"+i})

db.helloDoc.countDocuments()
EOF
```

## Как проверить

### Проверка через приложение

Откройте в браузере: http://localhost:8080

Приложение покажет общее количество документов в базе (>= 1000) и информацию о шардах.

### Проверка количества документов на шардах

```shell
docker compose exec -T shard1-1 mongosh --port 27018 --quiet <<EOF
use somedb
db.helloDoc.countDocuments()
EOF
```

```shell
docker compose exec -T shard2-1 mongosh --port 27019 --quiet <<EOF
use somedb
db.helloDoc.countDocuments()
EOF
```

### Проверка статуса репликации

```shell
docker compose exec -T shard1-1 mongosh --port 27018 --quiet <<EOF
rs.status().members.forEach(m => print(m.name + " — " + m.stateStr))
EOF
```

```shell
docker compose exec -T shard2-1 mongosh --port 27019 --quiet <<EOF
rs.status().members.forEach(m => print(m.name + " — " + m.stateStr))
EOF
```

### Swagger документация

http://localhost:8080/docs
