#!/bin/bash
# replica 컨테이너 안에서 실행되는 스크립트
# shard1, shard2 채널을 설정하고 replication을 시작합니다

set -e

MYSQL="mysql -h replica -u root -proot1234"

echo "[replica-setup] shard1, shard2 채널 설정 시작..."

# shard1 채널 설정
$MYSQL <<EOF
CHANGE REPLICATION SOURCE TO
  SOURCE_HOST     = 'shard1',
  SOURCE_PORT     = 3306,
  SOURCE_USER     = 'repl',
  SOURCE_PASSWORD = 'repl1234',
  SOURCE_AUTO_POSITION = 1
FOR CHANNEL 'ch_shard1';

-- shard1 채널은 shard1 DB만 복제
CHANGE REPLICATION FILTER
  REPLICATE_WILD_DO_TABLE = ('shard1.%')
FOR CHANNEL 'ch_shard1';
EOF

echo "[replica-setup] ch_shard1 채널 설정 완료"

# shard2 채널 설정
$MYSQL <<EOF
CHANGE REPLICATION SOURCE TO
  SOURCE_HOST     = 'shard2',
  SOURCE_PORT     = 3306,
  SOURCE_USER     = 'repl',
  SOURCE_PASSWORD = 'repl1234',
  SOURCE_AUTO_POSITION = 1
FOR CHANNEL 'ch_shard2';

-- shard2 채널은 shard2 DB만 복제
CHANGE REPLICATION FILTER
  REPLICATE_WILD_DO_TABLE = ('shard2.%')
FOR CHANNEL 'ch_shard2';
EOF

echo "[replica-setup] ch_shard2 채널 설정 완료"

# 두 채널 동시 시작
$MYSQL -e "START REPLICA FOR CHANNEL 'ch_shard1';"
$MYSQL -e "START REPLICA FOR CHANNEL 'ch_shard2';"

echo "[replica-setup] 양쪽 채널 replication 시작 완료!"
