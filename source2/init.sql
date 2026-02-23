-- replication 유저 생성
CREATE USER 'repl'@'%' IDENTIFIED BY 'repl1234';
GRANT REPLICATION SLAVE ON *.* TO 'repl'@'%';

-- shard2 DB 및 샘플 데이터 (user_id 501~1000)
CREATE DATABASE shard2;
USE shard2;

CREATE TABLE users (
  user_id   INT          NOT NULL,
  username  VARCHAR(50)  NOT NULL,
  email     VARCHAR(100) NOT NULL,
  region    VARCHAR(20)  NOT NULL DEFAULT 'N-Z',
  created_at DATETIME    NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (user_id)
);

INSERT INTO users (user_id, username, email) VALUES
  (501, 'nancy',   'nancy@example.com'),
  (502, 'oscar',   'oscar@example.com'),
  (503, 'peggy',   'peggy@example.com'),
  (600, 'quinn',   'quinn@example.com'),
  (700, 'rupert',  'rupert@example.com'),
  (800, 'sybil',   'sybil@example.com'),
  (900, 'trent',   'trent@example.com'),
  (1000,'victor',  'victor@example.com');
