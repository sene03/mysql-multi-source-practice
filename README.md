# 실행방법
```bash
docker compose up -d
docker compose logs setup

docker exec -it replica mysql -u root -proot1234
mysql> SHOW REPLICA STATUS\G
```