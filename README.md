# MySQL Multi-Source Replication Practice

MySQL 멀티소스 복제(Multi-Source Replication)를 연습하는 예제 프로젝트입니다.

하나의 `replica` 서버가 두 개의 source(`shard1`, `shard2`)를 각각 복제 채널로 구독합니다.

## 프로젝트 목적

- 샤드 DB 2개(`shard1`, `shard2`)를 운영한다고 가정
- 분석/조회용 `replica` DB에서 두 소스를 동시에 수신
- 채널별 복제 설정(`FOR CHANNEL`) 및 GTID 기반 자동 위치 추적 실습

## 구성 요소

- `shard1`: 원본 DB 1 (예: `user_id` 1~500)
- `shard2`: 원본 DB 2 (예: `user_id` 501~1000)
- `replica`: 두 source를 동시에 받는 레플리카 DB (읽기 전용)
- `setup`: 복제 채널 설정을 자동으로 수행하는 1회성 컨테이너

## 프로젝트 구조
```bash
.
├── docker-compose.yml
├── scripts/
│   └── setup-replica.sh
├── replica/
│   └── conf.d/my.cnf
├── source1/
│   ├── conf.d/my.cnf
│   └── init.sql
└── source2/
    ├── conf.d/my.cnf
    └── init.sql
```

## 동작 방식 요약

1. `shard1`, `shard2`, `replica` 컨테이너 실행
2. 각 source 컨테이너가 시작되면서 `init.sql` 실행
   - 복제 계정(`repl`) 생성
   - 샤드 DB 및 테이블 생성
   - 샘플 데이터 삽입
3. `setup` 컨테이너가 `replica`에 접속
4. 복제 채널 생성
   - `ch_shard1` -> `shard1`
   - `ch_shard2` -> `shard2`
5. 채널별 복제 필터 적용
   - `ch_shard1` -> `shard1.%`
   - `ch_shard2` -> `shard2.%`
6. 두 채널 `START REPLICA`

## 실행방법
```bash
docker compose up -d
docker compose logs setup

docker exec -it replica /bin/bash
mysql -u root -proot1234
mysql> SHOW REPLICA STATUS\G

# OR
SHOW REPLICA STATUS FOR CHANNEL 'ch_shard2'\G
```

## 실습
1. 데이터 복제 확인
```bash
-- replica에서 현재 데이터 확인
SELECT 'shard1' AS shard, user_id, username FROM shard1.users
UNION ALL
SELECT 'shard2', user_id, username FROM shard2.users
ORDER BY user_id;
```

2. 실시간 복제 확인
```bash
# shard1에 유저 추가
docker exec -it shard1 mysql -u root -proot1234
INSERT INTO shard1.users (user_id, username, email) VALUES (499, 'testuser', 'test@example.com');

# replica에서 즉시 확인
docker exec -it replica mysql -u root -proot1234
SELECT * FROM shard1.users WHERE user_id = 499;
```

3. replica에 직접 쓰기 시도
```bash
-- replica에서 직접 실행하면 에러가 나야 정상
INSERT INTO shard1.users (user_id, username, email) VALUES (9999, 'hack', 'hack@example.com');
```
