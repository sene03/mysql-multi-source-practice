-- replication 유저 생성
CREATE USER 'repl'@'%' IDENTIFIED BY 'repl1234';
GRANT REPLICATION SLAVE ON *.* TO 'repl'@'%';

-- shard1 DB 및 샘플 데이터 (user_id 1~500)
CREATE DATABASE shard1;
USE shard1;

CREATE TABLE users (
  user_id   INT          NOT NULL,
  username  VARCHAR(50)  NOT NULL,
  email     VARCHAR(100) NOT NULL,
  region    VARCHAR(20)  NOT NULL DEFAULT 'A-M',
  created_at DATETIME    NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (user_id)
);

INSERT INTO users (user_id, username, email) VALUES
  (1,   'alice',   'alice@example.com'),
  (2,   'bob',     'bob@example.com'),
  (3,   'carol',   'carol@example.com'),
  (100, 'dave',    'dave@example.com'),
  (200, 'eve',     'eve@example.com'),
  (300, 'frank',   'frank@example.com'),
  (400, 'grace',   'grace@example.com'),
  (500, 'heidi',   'heidi@example.com');
