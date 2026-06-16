.PHONY: up down build ssh1 ssh2 logs clean

# 환경 시작 (최초엔 이미지 빌드 포함)
up:
	docker compose up -d

# 환경 종료
down:
	docker compose down

# 이미지 새로 빌드
build:
	docker compose build --no-cache

# server1 SSH 접속 (root / toor)
ssh1:
	ssh -o StrictHostKeyChecking=no root@localhost -p 2201

# server2 SSH 접속 (root / toor)
ssh2:
	ssh -o StrictHostKeyChecking=no root@localhost -p 2202

# server1 bash 직접 진입 (SSH 없이)
exec1:
	docker exec -it linux-server1 bash

# server2 bash 직접 진입
exec2:
	docker exec -it linux-server2 bash

# 로그 확인
logs:
	docker compose logs -f

# 컨테이너 + 볼륨 완전 삭제 (주의: 연습 데이터도 삭제됨)
clean:
	docker compose down -v --rmi all
