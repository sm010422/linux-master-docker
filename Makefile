.PHONY: up down build rebuild ssh1 ssh2 exec1 exec2 logs clean

NETWORK    = linux-master-docker_study_net
IMG1       = linux-master-docker-server1
IMG2       = linux-master-docker-server2
VOL_PREFIX = linux-master-docker

# Docker Compose v5 does not accept cgroupns_mode, so containers are started
# with docker run --cgroupns=host so systemd can manage cgroups inside.

# 환경 시작
up: _network
	@docker run -d \
		--name linux-server1 \
		--hostname server1.linux.local \
		--privileged --cgroupns=host \
		-v /sys/fs/cgroup:/sys/fs/cgroup:rw \
		-v $(VOL_PREFIX)_server1_home:/home \
		-v $(VOL_PREFIX)_server1_www:/var/www/html \
		-v $(VOL_PREFIX)_server1_data:/data \
		-p 2201:22 -p 8080:80 -p 8443:443 -p 2121:21 \
		--network $(NETWORK) --ip 172.30.0.10 \
		--restart unless-stopped \
		$(IMG1) && echo "server1 started" || echo "server1 already running"
	@docker run -d \
		--name linux-server2 \
		--hostname server2.linux.local \
		--privileged --cgroupns=host \
		-v /sys/fs/cgroup:/sys/fs/cgroup:rw \
		-v $(VOL_PREFIX)_server2_home:/home \
		-p 2202:22 \
		--network $(NETWORK) --ip 172.30.0.20 \
		--restart unless-stopped \
		$(IMG2) && echo "server2 started" || echo "server2 already running"

# 네트워크 생성 (없을 때만)
_network:
	@docker network create --driver bridge \
		--subnet 172.30.0.0/24 --gateway 172.30.0.1 \
		$(NETWORK) 2>/dev/null || true

# 환경 종료
down:
	docker rm -f linux-server1 linux-server2 2>/dev/null || true

# 이미지 빌드
build:
	docker compose build --no-cache

# 재빌드 후 바로 시작
rebuild: build up

# server1 SSH 접속 (root / toor)
ssh1:
	ssh -o StrictHostKeyChecking=no root@localhost -p 2201

# server2 SSH 접속 (root / toor)
ssh2:
	ssh -o StrictHostKeyChecking=no root@localhost -p 2202

# server1 bash 직접 진입
exec1:
	docker exec -it linux-server1 bash

# server2 bash 직접 진입
exec2:
	docker exec -it linux-server2 bash

# 로그 확인
logs:
	docker logs -f linux-server1

# 컨테이너 + 볼륨 + 네트워크 + 이미지 완전 삭제 (주의: 연습 데이터도 삭제됨)
clean: down
	docker network rm $(NETWORK) 2>/dev/null || true
	docker volume rm \
		$(VOL_PREFIX)_server1_home $(VOL_PREFIX)_server1_www \
		$(VOL_PREFIX)_server1_data $(VOL_PREFIX)_server2_home \
		2>/dev/null || true
	docker rmi $(IMG1) $(IMG2) 2>/dev/null || true
