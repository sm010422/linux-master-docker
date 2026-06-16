FROM rockylinux:9

LABEL description="리눅스 마스터 1급/2급 학습 환경 (Rocky Linux 9 + systemd)"
ENV container=docker

# ─── 저장소 추가 및 전체 패키지 설치 ───────────────────────────────────────────
RUN dnf -y update && \
    dnf -y install epel-release && \
    dnf -y groupinstall "Development Tools" && \
    dnf -y install \
        # 시스템 / systemd
        systemd sudo \
        # 편집기 / 기본 도구
        vim-enhanced nano \
        wget curl git \
        tar gzip bzip2 xz zip unzip \
        which file tree \
        man man-db \
        bash-completion \
        words \
        # 네트워크 도구 (시험 단골 출제)
        net-tools iproute iputils \
        bind-utils nmap \
        telnet tcpdump \
        hostname \
        # 프로세스 / 시스템 모니터링
        procps-ng psmisc lsof \
        sysstat htop \
        # ── 서비스들 ──
        # 웹 서버
        httpd httpd-tools mod_ssl \
        # 데이터베이스
        mariadb mariadb-server \
        # FTP 서버
        vsftpd \
        # Samba (Windows 파일 공유)
        samba samba-client samba-common \
        # NFS
        nfs-utils \
        # DNS
        bind bind-utils \
        # 메일 서버
        postfix \
        # SSH
        openssh-server openssh-clients \
        # 스케줄러
        cronie at \
        # 로그 / 로테이션
        rsyslog logrotate \
        # 방화벽
        firewalld iptables iptables-services \
        # 파일시스템 도구
        lvm2 e2fsprogs xfsprogs \
        parted gdisk \
        # 접근 제어
        quota acl attr \
        # 인증
        authselect oddjob-mkhomedir \
        # 수퍼 데몬
        xinetd \
        # 계정 관리 도구
        passwd shadow-utils \
    && dnf clean all && rm -rf /var/cache/dnf

# ─── systemd Docker 최적화 (불필요한 유닛 마스킹) ────────────────────────────
RUN systemctl mask \
        dev-hugepages.mount \
        sys-fs-fuse-connections.mount \
        systemd-update-utmp.service \
        systemd-tmpfiles-setup-dev.service \
        systemd-remount-fs.service \
        systemd-logind.service \
    2>/dev/null || true

# ─── SSH 설정: root 로그인·비밀번호 인증 허용 ────────────────────────────────
RUN sed -i \
        -e 's|^#\?PermitRootLogin.*|PermitRootLogin yes|' \
        -e 's|^#\?PasswordAuthentication.*|PasswordAuthentication yes|' \
        -e 's|^#\?UseDNS.*|UseDNS no|' \
        /etc/ssh/sshd_config && \
    ssh-keygen -A

# ─── Apache 기본 설정 ────────────────────────────────────────────────────────
RUN echo "ServerName localhost" >> /etc/httpd/conf/httpd.conf

# ─── 계정 설정 ───────────────────────────────────────────────────────────────
# root 비밀번호: toor
RUN echo 'root:toor' | chpasswd

# 연습용 일반 계정 (linux / linux), sudo 가능
RUN useradd -m -s /bin/bash linux && \
    echo 'linux:linux' | chpasswd && \
    usermod -aG wheel linux

# 추가 연습용 계정 (user1 ~ user3)
RUN for i in 1 2 3; do \
        useradd -m -s /bin/bash "user${i}" && \
        echo "user${i}:user${i}" | chpasswd; \
    done

# 연습용 그룹
RUN groupadd devteam && \
    groupadd webteam && \
    usermod -aG devteam user1 && \
    usermod -aG webteam user2

# ─── 부팅 시 자동 시작할 서비스 ─────────────────────────────────────────────
# (sshd 만 기본 활성화; 나머지는 직접 systemctl enable 연습)
RUN systemctl enable sshd cronie rsyslog 2>/dev/null || true

VOLUME ["/sys/fs/cgroup"]

# SSH / HTTP / HTTPS / FTP / MariaDB / DNS / Samba / NFS
EXPOSE 22 80 443 21 20 3306 53 137 138 139 445 2049

STOPSIGNAL SIGRTMIN+3
CMD ["/usr/sbin/init"]
