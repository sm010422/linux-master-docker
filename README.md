# linux-master-docker

> VMware 없이 Docker로 띄우는 리눅스 마스터 1급/2급 실습 환경

![Rocky Linux](https://img.shields.io/badge/Rocky_Linux-9-10B981?logo=rockylinux&logoColor=white)
![Docker](https://img.shields.io/badge/Docker-Compose-2496ED?logo=docker&logoColor=white)
![systemd](https://img.shields.io/badge/systemd-enabled-lightgrey)
![License](https://img.shields.io/badge/license-MIT-blue)

Rocky Linux 9 (RHEL 계열) + systemd 기반으로 실제 시험 환경과 최대한 유사하게 구성했습니다.  
서버 2대(server1 / server2)가 같은 네트워크 안에서 통신하며, `systemctl`, 패키지 관리, 네트워크 서비스 등 시험 항목을 그대로 실습할 수 있습니다.

---

## 환경 구성

```
┌─────────────────────────────────────────────────────┐
│                   study_net (172.30.0.0/24)         │
│                                                     │
│  ┌──────────────────┐    ┌──────────────────┐       │
│  │    server1       │    │    server2       │       │
│  │  172.30.0.10     │◄──►│  172.30.0.20     │       │
│  │                  │    │                  │       │
│  │ httpd / mariadb  │    │  클라이언트 역할  │       │
│  │ vsftpd / samba   │    │  (samba, nfs,    │       │
│  │ nfs / bind       │    │   ftp 등 접속    │       │
│  │ postfix / ssh    │    │   연습용)        │       │
│  └──────────────────┘    └──────────────────┘       │
│       SSH: 2201                SSH: 2202            │
│       HTTP: 8080                                    │
└─────────────────────────────────────────────────────┘
```

### 컨테이너 계정 정보

| 계정 | 비밀번호 | 권한 |
|------|----------|------|
| root | toor | 관리자 |
| linux | linux | sudo 가능 (wheel 그룹) |
| user1 | user1 | 일반 사용자 (devteam 그룹) |
| user2 | user2 | 일반 사용자 (webteam 그룹) |
| user3 | user3 | 일반 사용자 |

---

## 빠른 시작

### 요구 사항

- Docker Desktop (Mac/Windows) 또는 Docker Engine (Linux)
- Docker Compose v2 이상

### 시작 / 종료

```bash
# 최초 빌드 및 시작 (이미지 빌드 포함, 5~10분 소요)
docker compose up -d --build

# 이미 빌드된 이미지로 시작
docker compose up -d

# 종료 (데이터 유지)
docker compose down

# 완전 초기화 (볼륨·이미지 모두 삭제)
docker compose down -v --rmi all
```

### 접속 방법

```bash
# ── 방법 1: SSH 접속 (실제 서버처럼) ──────────────────
ssh root@localhost -p 2201     # server1
ssh root@localhost -p 2202     # server2

# ── 방법 2: docker exec 직접 진입 ─────────────────────
docker exec -it linux-server1 bash
docker exec -it linux-server2 bash

# ── Makefile 단축 명령어 ──────────────────────────────
make up       # 시작
make ssh1     # server1 SSH
make ssh2     # server2 SSH
make exec1    # server1 bash 직접 진입
make down     # 종료
make clean    # 완전 초기화
```

---

## 설치된 패키지 목록

### 서비스 / 데몬

| 서비스 | 패키지 | 기본 상태 |
|--------|--------|-----------|
| 웹 서버 | `httpd`, `mod_ssl` | 비활성 |
| 데이터베이스 | `mariadb`, `mariadb-server` | 비활성 |
| FTP 서버 | `vsftpd` | 비활성 |
| 파일 공유 (Windows) | `samba`, `samba-client` | 비활성 |
| 파일 공유 (Unix) | `nfs-utils` | 비활성 |
| DNS | `bind`, `bind-utils` | 비활성 |
| 메일 서버 | `postfix` | 비활성 |
| SSH | `openssh-server` | **활성** |
| 크론 | `cronie`, `at` | **활성** |
| 로그 | `rsyslog`, `logrotate` | **활성** |
| 방화벽 | `firewalld`, `iptables` | 비활성 |
| 수퍼 데몬 | `xinetd` | 비활성 |

> 대부분 서비스를 비활성 상태로 둔 이유: `systemctl enable/start` 실습 자체가 시험 항목이기 때문입니다.

### 도구 / 유틸리티

| 분류 | 패키지 |
|------|--------|
| 네트워크 | `net-tools`, `iproute`, `nmap`, `tcpdump`, `bind-utils`, `telnet` |
| 프로세스 | `procps-ng`, `psmisc`, `lsof`, `sysstat`, `htop` |
| 파일시스템 | `lvm2`, `e2fsprogs`, `xfsprogs`, `parted`, `gdisk` |
| 접근 제어 | `quota`, `acl`, `attr` |
| 개발 | `gcc`, `make`, `python3`, `git` |
| 기타 | `vim`, `nano`, `wget`, `curl`, `tar`, `man`, `bash-completion` |

---

## 서비스별 실습 가이드

### Apache (httpd)

```bash
# 시작
systemctl enable --now httpd

# 설정 파일
vi /etc/httpd/conf/httpd.conf
vi /etc/httpd/conf.d/vhost.conf   # 가상 호스트

# 웹 루트
ls /var/www/html/

# 로그
tail -f /var/log/httpd/access_log
tail -f /var/log/httpd/error_log

# 확인 (호스트 머신 브라우저에서)
# http://localhost:8080
```

### MariaDB

```bash
# 시작 및 초기 보안 설정
systemctl enable --now mariadb
mysql_secure_installation

# 접속
mysql -u root -p

# 기본 실습
CREATE DATABASE testdb;
CREATE USER 'dbuser'@'localhost' IDENTIFIED BY 'pass';
GRANT ALL ON testdb.* TO 'dbuser'@'localhost';
```

### vsftpd (FTP)

```bash
# 설정 파일
vi /etc/vsftpd/vsftpd.conf

# 주요 설정 항목
anonymous_enable=NO
local_enable=YES
write_enable=YES
chroot_local_user=YES

systemctl enable --now vsftpd

# server2에서 접속 테스트
ftp 172.30.0.10
```

### Samba

```bash
# 설정 파일
vi /etc/samba/smb.conf

# 공유 설정 예시 추가
[share]
  path = /srv/samba/share
  writable = yes
  valid users = linux

# Samba 전용 비밀번호 설정
smbpasswd -a linux

systemctl enable --now smb nmb

# server2에서 접속 테스트
smbclient //172.30.0.10/share -U linux
```

### NFS

```bash
# 공유 디렉토리 생성
mkdir -p /srv/nfs/share
echo "/srv/nfs/share 172.30.0.0/24(rw,sync,no_root_squash)" >> /etc/exports

systemctl enable --now nfs-server
exportfs -arv

# server2에서 마운트 테스트
showmount -e 172.30.0.10
mount -t nfs 172.30.0.10:/srv/nfs/share /mnt
```

### BIND (DNS)

```bash
# 설정 파일
vi /etc/named.conf
vi /etc/named.rfc1912.zones

# 정방향 존 파일 예시
vi /var/named/linux.local.zone

systemctl enable --now named

# 테스트
nslookup server1.linux.local 127.0.0.1
dig @127.0.0.1 server1.linux.local
```

### 방화벽 (firewalld / iptables)

```bash
# firewalld
systemctl enable --now firewalld
firewall-cmd --add-service=http --permanent
firewall-cmd --add-port=8080/tcp --permanent
firewall-cmd --reload
firewall-cmd --list-all

# iptables (직접 규칙)
systemctl enable --now iptables
iptables -L -n -v
iptables -A INPUT -p tcp --dport 80 -j ACCEPT
iptables-save > /etc/sysconfig/iptables
```

### cron / at

```bash
# crontab 편집
crontab -e

# 예시: 매일 새벽 2시에 스크립트 실행
# 0 2 * * * /home/linux/backup.sh

# /etc/cron.d/ 에 시스템 크론 작성
vi /etc/cron.d/myjob

# at: 특정 시각에 1회 실행
at now + 5 minutes
at> echo "test" > /tmp/at_test.txt
at> Ctrl+D

atq     # 대기 중인 작업 확인
atrm 1  # 작업 삭제
```

---

## 사용자 / 그룹 관리 실습

```bash
# 사용자 생성
useradd -m -s /bin/bash testuser
passwd testuser

# 사용자 정보 수정
usermod -aG devteam testuser    # 그룹 추가
usermod -L testuser             # 계정 잠금
usermod -U testuser             # 계정 잠금 해제

# 그룹 관리
groupadd newgroup
groupdel newgroup
gpasswd -a testuser newgroup

# 사용자 정보 확인
id testuser
cat /etc/passwd | grep testuser
cat /etc/shadow | grep testuser
cat /etc/group  | grep testuser
```

---

## 파일 시스템 실습

### 파일 권한 / ACL

```bash
# 기본 권한
chmod 755 /srv/share
chown linux:devteam /srv/share

# ACL 설정 (quota, acl 패키지)
setfacl -m u:user1:rwx /srv/share
getfacl /srv/share

# 특수 권한
chmod u+s /usr/bin/program   # setuid
chmod g+s /srv/share         # setgid
chmod +t  /tmp/sticky        # sticky bit
```

### LVM

```bash
# 물리 볼륨 확인
pvdisplay
vgdisplay
lvdisplay

# LVM 생성 흐름
pvcreate /dev/sdb
vgcreate myvg /dev/sdb
lvcreate -L 1G -n mylv myvg
mkfs.ext4 /dev/myvg/mylv
mount /dev/myvg/mylv /mnt
```

---

## 컨테이너 간 통신 예시

server2에서 server1의 서비스에 접근하는 실습:

```bash
# server2 진입
docker exec -it linux-server2 bash

# server1으로 SSH
ssh root@172.30.0.10
ssh root@server1.linux.local

# FTP 접속
ftp 172.30.0.10

# 웹 서버 접근
curl http://172.30.0.10

# DNS 조회
nslookup server1.linux.local 172.30.0.10

# NFS 마운트
mount -t nfs 172.30.0.10:/srv/nfs/share /mnt

# Samba 접속
smbclient //172.30.0.10/share -U linux
```

---

## 로그 확인

```bash
# 시스템 로그 (systemd journal)
journalctl -xe
journalctl -u httpd -f       # 특정 서비스 로그

# 전통적인 syslog
tail -f /var/log/messages
tail -f /var/log/secure      # 인증 로그
tail -f /var/log/maillog     # 메일 로그

# 서비스별
tail -f /var/log/httpd/access_log
tail -f /var/log/httpd/error_log
tail -f /var/log/mariadb/mariadb.log
```

---

## 자주 쓰는 명령어 치트시트

```bash
# 서비스 관리
systemctl start|stop|restart|reload <service>
systemctl enable|disable <service>
systemctl status <service>
systemctl list-units --type=service

# 패키지 관리 (dnf/rpm)
dnf install <package>
dnf remove <package>
dnf search <keyword>
dnf list installed
rpm -qa                        # 설치된 패키지 전체
rpm -qi <package>              # 패키지 상세 정보
rpm -ql <package>              # 패키지 파일 목록
rpm -qf /usr/bin/vim           # 파일이 속한 패키지 확인

# 네트워크
ip addr show
ip route show
ss -tnlp                       # 열려 있는 포트 확인
netstat -tnlp                  # (net-tools)

# 프로세스
ps aux
ps -ef
top / htop
kill -9 <PID>
killall <process_name>

# 디스크
df -h
du -sh /var/log
fdisk -l
lsblk
```

---

## 파일 구조

```
linux-master-docker/
├── Dockerfile          # Rocky Linux 9 기반 이미지 정의
├── docker-compose.yml  # server1, server2 컨테이너 구성
├── Makefile            # 단축 명령어 모음
└── README.md           # 이 문서
```

---

## 주의 사항

- `privileged: true` 모드로 실행되므로 **호스트 시스템에 영향을 줄 수 있는 명령어** (예: `rm -rf /`, 커널 파라미터 변경)는 주의해서 사용하세요.
- 컨테이너 내부에서 LVM 실습 시 실제 블록 디바이스가 없으므로 루프 디바이스(`losetup`)를 활용하거나 `docker volume` 을 마운트해야 합니다.
- `docker compose down`은 볼륨을 삭제하지 않아 연습 데이터가 유지됩니다. 완전 초기화는 `docker compose down -v` 를 사용하세요.
