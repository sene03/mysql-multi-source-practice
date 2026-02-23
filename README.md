# 실행방법
```bash
docker compose up -d
docker compose logs setup

docker exec -it replica /bin/bash
mysql -u root -proot1234
mysql> SHOW REPLICA STATUS\G
```

# 실습
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