# 트러블슈팅 가이드

---

## 1. `docker compose up` 실행 시 `cgroupns_mode` 오류

### 증상

```
validating docker-compose.yml: services.server2 additional properties 'cgroupns_mode' not allowed
```

### 원인

Docker Compose v5부터 `cgroupns_mode` 속성을 스키마 검증에서 허용하지 않습니다.

### 해결

`docker compose up` 을 직접 사용하지 말고 **반드시 `make` 명령어를 사용하세요.**  
Makefile은 `docker run --cgroupns=host` 로 컨테이너를 직접 실행하여 이 문제를 우회합니다.

```bash
# 잘못된 방법
docker compose up -d --build   # ← 오류 발생

# 올바른 방법
make build   # 이미지 빌드
make up      # 컨테이너 시작
```

---

## 2. 컨테이너가 시작되지만 SSH 연결이 즉시 끊김

### 증상

```
$ ssh root@localhost -p 2201
Connection closed by 127.0.0.1 port 2201
```

### 원인

컨테이너 내부 systemd가 cgroup 제어 그룹을 생성하지 못해 freeze 상태가 됩니다.

```
Failed to create /init.scope control group: No such file or directory
Failed to allocate manager object: No such file or directory
Freezing execution.
```

`--cgroupns=host` 없이 컨테이너를 시작하면 Docker가 private cgroup 네임스페이스를 생성하고, systemd가 `/init.scope`를 만들지 못합니다. sshd 자체가 뜨지 않으므로 연결이 즉시 닫힙니다.

### 해결

`make up` 사용 시 자동으로 `--cgroupns=host` 플래그가 적용됩니다.  
`docker compose up` 으로 직접 시작했다면 컨테이너를 재시작하세요.

```bash
make down
make up
```

---

## 3. SSH 비밀번호 인증 실패 (`Permission denied`)

### 증상

```
$ ssh root@localhost -p 2201
root@localhost's password:
Permission denied, please try again.
```

컨테이너가 정상 실행 중이고, 비밀번호(`toor`)가 맞는데도 계속 거부됩니다.

### 원인 (3가지 복합)

컨테이너 로그에서 다음 오류를 확인할 수 있습니다.

```
unix_chkpwd: check pass; user unknown
unix_chkpwd: password check failed for user (root)
pam_unix(sshd:auth): authentication failure
```

**원인 1 — nsswitch.conf에 SSSD가 포함됨**

Rocky Linux 8 기본 설정은 `authselect` 가 활성화 전이라도 nsswitch.conf에 `sss`(SSSD)를 포함시킵니다.

```
passwd: sss files systemd   ← sssd 미실행 시 getspnam() 실패
shadow: files sss
```

SSSD가 실행되지 않은 컨테이너 환경에서 `unix_chkpwd`가 사용자 정보를 찾지 못합니다.

**원인 2 — `/etc/shadow` 권한이 `000`**

Rocky Linux 8의 기본 `/etc/shadow` 권한은 `----------` (000)입니다.  
`unix_chkpwd` 바이너리는 setuid root이지만, 특정 조건에서 shadow 파일에 접근하지 못합니다.

```
$ strace /usr/sbin/unix_chkpwd root nullok <<< "toor"
openat(AT_FDCWD, "/etc/shadow", O_RDONLY|O_CLOEXEC) = -1 EACCES (Permission denied)
```

**원인 3 — `pam_loginuid.so`가 `required`**

`/etc/pam.d/sshd`의 `pam_loginuid.so`가 `required`로 설정돼 있는데, 컨테이너 환경에서 실패하면 세션 전체가 거부됩니다.

### 해결

Dockerfile에 아래 세 가지 수정이 이미 적용돼 있습니다. 이미지를 재빌드하면 해결됩니다.

```bash
make build
make down
make up
```

수동으로 실행 중인 컨테이너에 즉시 적용하려면:

```bash
# 1. authselect를 minimal(files 전용)로 설정
docker exec linux-server1 authselect select minimal --force

# 2. /etc/shadow 권한 수정
docker exec linux-server1 chmod 640 /etc/shadow

# 3. pam_loginuid optional로 변경
docker exec linux-server1 sed -i \
  's/session    required     pam_loginuid.so/session    optional     pam_loginuid.so/' \
  /etc/pam.d/sshd

# 4. sshd 재시작
docker exec linux-server1 systemctl restart sshd
```

---

## 4. `xinetd` 패키지 설치 실패

### 증상

```
No match for argument: xinetd
Error: Unable to find a match: xinetd
```

### 원인

Rocky Linux 9에서 `xinetd`가 공식 저장소에서 제거됐습니다. RHEL 9부터 deprecated 처리됩니다.

### 해결

이 프로젝트는 `xinetd` 실습이 가능한 **Rocky Linux 8** 기반으로 변경됐습니다.  
`Dockerfile`의 `FROM rockylinux:8` 로 설정되어 있어 별도 조치가 필요 없습니다.

---

## 5. SSH 접속 시 `WARNING: REMOTE HOST IDENTIFICATION HAS CHANGED`

### 증상

```
@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@
@    WARNING: REMOTE HOST IDENTIFICATION HAS CHANGED!     @
@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@
```

### 원인

`make build`로 이미지를 재빌드하면 컨테이너의 SSH 호스트키가 새로 생성됩니다.  
로컬 `~/.ssh/known_hosts`에 이전 키가 남아있어 충돌합니다.

### 해결

```bash
ssh-keygen -R '[localhost]:2201'   # server1
ssh-keygen -R '[localhost]:2202'   # server2
```

이후 다시 접속하면 새 키를 신뢰할지 묻습니다.  
`make ssh1` / `make ssh2` 는 `-o StrictHostKeyChecking=no` 옵션을 사용하므로 이 경고 없이 접속됩니다.
