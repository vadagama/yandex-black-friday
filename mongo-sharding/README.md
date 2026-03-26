# mongo-sharding

Проект разворачивает приложение pymongo-api с шардированным кластером MongoDB (2 шарда, 1 сервер конфигурации, 1 роутер).

## Архитектура

- **configSrv** — сервер конфигурации (порт 27017)
- **shard1** — первый шард (порт 27018)
- **shard2** — второй шард (порт 27019)
- **mongos_router** — роутер (порт 27020)
- **pymongo_api** — приложение (порт 8080)

## Как запустить

### 1. Запуск контейнеров

```shell
docker compose up -d
```

Дождитесь, пока все контейнеры успешно стартуют (10-15 секунд):

```shell
docker compose ps
```

### 2. Инициализация шардирования и наполнение данными

```shell
./scripts/mongo-init.sh
```

Скрипт выполняет следующие шаги:

1. Инициализирует реплику сервера конфигурации (`config_server`).
2. Инициализирует реплику первого шарда (`shard1`).
3. Инициализирует реплику второго шарда (`shard2`).
4. Подключается к роутеру и:
   - добавляет оба шарда в кластер;
   - включает шардирование для базы `somedb`;
   - шардирует коллекцию `helloDoc` с хешированным ключом `name`;
   - вставляет 1000 тестовых документов.
5. Выводит количество документов на каждом из шардов.

### 3. Ручная инициализация (альтернативный способ)

Если нужно выполнить шаги вручную:

**Инициализация сервера конфигурации:**

```shell
docker compose exec -T configSrv mongosh --port 27017 --quiet <<EOF
rs.initiate(
  {
    _id : "config_server",
    configsvr: true,
    members: [
      { _id : 0, host : "configSrv:27017" }
    ]
  }
);
EOF
```

**Инициализация шарда 1:**

```shell
docker compose exec -T shard1 mongosh --port 27018 --quiet <<EOF
rs.initiate(
  {
    _id : "shard1",
    members: [
      { _id : 0, host : "shard1:27018" }
    ]
  }
);
EOF
```

**Инициализация шарда 2:**

```shell
docker compose exec -T shard2 mongosh --port 27019 --quiet <<EOF
rs.initiate(
  {
    _id : "shard2",
    members: [
      { _id : 1, host : "shard2:27019" }
    ]
  }
);
EOF
```

**Настройка роутера и наполнение данными:**

```shell
docker compose exec -T mongos_router mongosh --port 27020 --quiet <<EOF
sh.addShard("shard1/shard1:27018");
sh.addShard("shard2/shard2:27019");

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

Приложение покажет общее количество документов в базе (≥ 1000) и информацию о шардах.

### Проверка количества документов на шардах

```shell
docker compose exec -T shard1 mongosh --port 27018 --quiet <<EOF
use somedb
db.helloDoc.countDocuments()
EOF
```

```shell
docker compose exec -T shard2 mongosh --port 27019 --quiet <<EOF
use somedb
db.helloDoc.countDocuments()
EOF
```

### Swagger документация

http://localhost:8080/docs
