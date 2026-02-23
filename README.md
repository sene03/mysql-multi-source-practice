# MySQL Multi-Source Replication 실습

## 개요

여러 MySQL 서버(Source)의 데이터를 하나의 Replica로 통합하는 **Multi-Source Replication** 실습 환경입니다.

</br>

### 시나리오: 샤딩된 유저 DB 병합

유저 수가 많아져 `users` 테이블을 두 서버에 샤딩한 상황을 가정합니다.

- **shard1**: user_id 1 ~ 500 담당
- **shard2**: user_id 501 ~ 1000 담당
- **replica**: 두 샤드를 모두 받아 전체 유저 조회 / 통계 / 분석에 활용

```
[shard1]  server-id=1  port=3306
[shard2]  server-id=2  port=3307
    │  ch_shard1          │  ch_shard2
    └──────────┬───────────┘
           [replica]  server-id=3  port=3308
```

---

</br>

## 핵심 개념

### Multi-Source Replication
하나의 Replica가 여러 Source로부터 동시에 데이터를 받는 구조입니다.
Replica는 Source마다 독립적인 **Replication Channel**을 생성하고,
각 채널은 별도의 I/O 스레드와 SQL 스레드를 가지며 서로 영향을 주지 않습니다.

</br>


### GTID (Global Transaction Identifier)
트랜잭션마다 붙는 전 세계 고유 ID입니다. `UUID:번호` 형식으로 표현됩니다.

```
3faa244c-...:1-10  →  shard1의 1번~10번 트랜잭션
3faef049-...:1-10  →  shard2의 1번~10번 트랜잭션
```

GTID를 사용하면 Replica가 이미 적용한 트랜잭션을 자동으로 건너뛰기 때문에
binlog 파일명/위치를 직접 관리할 필요가 없습니다.

</br>


### Replication Channel Filter
`REPLICATE_WILD_DO_TABLE`로 채널마다 복제할 테이블을 지정할 수 있습니다.

- `ch_shard1` → `shard1.*` 만 복제
- `ch_shard2` → `shard2.*` 만 복제

두 샤드의 테이블 구조가 동일해도 DB명이 다르기 때문에 충돌이 발생하지 않습니다.

---

</br>


## 파일 구조

```
mysql-multi-source/
├── docker-compose.yml
├── source1/
│   └── init.sql          # shard1 초기 데이터 + replication 유저 생성
├── source2/
│   └── init.sql          # shard2 초기 데이터 + replication 유저 생성
└── scripts/
    └── setup-replica.sh  # replica 채널 설정 자동화 스크립트
```

---

</br>


## 실행 방법

### 1. 전체 기동

```bash
docker compose up -d
```

컨테이너 기동 순서는 자동으로 관리됩니다.
- shard1, shard2 기동 및 초기화
- replica 기동
- setup 컨테이너가 1회 실행되며 채널 설정 완료

</br>


### 2. 채널 설정 결과 확인

```bash
docker compose logs setup
```

</br>


### 3. 정리

```bash
docker compose down -v   # 컨테이너 + 볼륨 모두 삭제
docker compose down      # 컨테이너만 삭제 (데이터 유지)
```

---

</br>


## 실습 시나리오

### 시나리오 1: 기본 복제 확인

replica에서 두 샤드의 데이터가 모두 보이는지 확인합니다.

```bash
docker exec -it replica mysql -u root -proot1234
```

```sql
-- 전체 유저 조회 (두 샤드 합산)
SELECT 'shard1' AS shard, user_id, username, email FROM shard1.users
UNION ALL
SELECT 'shard2', user_id, username, email FROM shard2.users
ORDER BY user_id;
```

</br>


### 시나리오 2: 실시간 복제 확인

shard에 데이터를 넣으면 replica에 즉시 반영되는지 확인합니다.

```bash
# shard1에 유저 추가
docker exec -it shard1 mysql -u root -proot1234 -e "
INSERT INTO shard1.users (user_id, username, email)
VALUES (499, 'newuser', 'new@example.com');"

# replica에서 즉시 확인
docker exec -it replica mysql -u root -proot1234 -e "
SELECT * FROM shard1.users WHERE user_id = 499;"
```

</br>


### 시나리오 3: 채널 필터 확인

shard1의 데이터가 shard2 채널을 통해 넘어오지 않는지 확인합니다.

```sql
-- replica에서 실행
-- shard2 DB에는 user_id 499가 없어야 정상
SELECT * FROM shard2.users WHERE user_id = 499;
```

</br>



### 시나리오 4: Source 장애 상황

shard1이 죽었을 때 replica 동작을 확인합니다.

```bash
# shard1 강제 종료
docker stop shard1
```

```sql
-- replica에서 채널 상태 확인
-- ch_shard1: Replica_IO_Running = No (연결 끊김)
-- ch_shard2: Replica_IO_Running = Yes (영향 없음)
SHOW REPLICA STATUS\G
```

shard1이 죽어도 **이미 replica에 복제된 데이터는 그대로 남아있고**,
ch_shard2는 계속 정상 동작합니다.

```bash
# shard1 복구
docker start shard1

# 잠시 후 자동으로 재연결됨 (GTID 덕분에 끊긴 시점부터 이어받음)
```

</br>



### 시나리오 5: replica에서 백업 후 복원

shard1이 장애일 때 replica에서 데이터를 덤프해 복원합니다.

```bash
# replica에서 shard1 데이터 백업
docker exec replica mysqldump -u root -proot1234 shard1 > shard1_backup.sql

# shard1 복구 후 데이터 복원
docker start shard1
docker exec -i shard1 mysql -u root -proot1234 shard1 < shard1_backup.sql
```

---

</br>


## 상태 모니터링

```sql
-- 채널별 IO / SQL 스레드 상태
SELECT
  CHANNEL_NAME,
  SERVICE_STATE
FROM performance_schema.replication_connection_status;

-- 채널별 에러 확인
SELECT
  CHANNEL_NAME,
  LAST_ERROR_MESSAGE
FROM performance_schema.replication_applier_status;

-- 실행된 GTID 전체 확인
SELECT @@GLOBAL.gtid_executed;
```

INSERT INTO shard1.users (user_id, username, email) VALUES (9999, 'hack', 'hack@example.com');
```
