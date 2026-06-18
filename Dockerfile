FROM rockylinux:8

LABEL description="리눅스 마스터 1급/2급 학습 환경 (Rocky Linux 8 + systemd)"
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

# ─── ble.sh (bash syntax highlighting) ───────────────────────────────────────
RUN git clone --depth=1 https://github.com/akinomyoga/ble.sh /tmp/blesh-src && \
    make -C /tmp/blesh-src install PREFIX=/usr/local && \
    rm -rf /tmp/blesh-src && \
    echo '[[ $- == *i* ]] && source /usr/local/share/blesh/ble.sh' \
    >> /etc/bashrc

# ─── 쉘 환경 설정 (컬러 프롬프트 + 편의 alias) ──────────────────────────────
RUN printf '%s\n' \
    "alias ls='ls --color=auto'" \
    "alias l='ls -alF'" \
    "alias ll='ls -lF'" \
    "alias la='ls -A'" \
    "alias grep='grep --color=auto'" \
    "alias df='df -h'" \
    "alias du='du -h'" \
    "alias free='free -h'" \
    "if [ \"\$(id -u)\" -eq 0 ]; then" \
    "    PS1='\[\e[01;31m\]\u\[\e[0m\]@\[\e[01;33m\]\h\[\e[0m\]:\[\e[01;34m\]\w\[\e[0m\]\\$ '" \
    "else" \
    "    PS1='\[\e[01;32m\]\u\[\e[0m\]@\[\e[01;33m\]\h\[\e[0m\]:\[\e[01;34m\]\w\[\e[0m\]\\$ '" \
    "fi" \
    > /etc/profile.d/custom.sh

# ─── PAM / NSS 설정 (컨테이너 환경 최적화) ──────────────────────────────────
# SSSD 없이 files 기반 인증만 사용 (sssd 미실행 시 getspnam 실패 방지)
RUN authselect select minimal --force
# pam_loginuid는 컨테이너 환경에서 실패하므로 optional로 변경
RUN sed -i 's/session    required     pam_loginuid.so/session    optional     pam_loginuid.so/' \
        /etc/pam.d/sshd

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

# /etc/shadow 권한을 640으로 설정 (기본 000은 unix_chkpwd가 읽지 못해 SSH 인증 실패)
RUN chmod 640 /etc/shadow

# ─── 부팅 시 자동 시작할 서비스 ─────────────────────────────────────────────
# (sshd 만 기본 활성화; 나머지는 직접 systemctl enable 연습)
RUN systemctl enable sshd cronie rsyslog 2>/dev/null || true

VOLUME ["/sys/fs/cgroup"]

# SSH / HTTP / HTTPS / FTP / MariaDB / DNS / Samba / NFS
EXPOSE 22 80 443 21 20 3306 53 137 138 139 445 2049

STOPSIGNAL SIGRTMIN+3
CMD ["/usr/sbin/init"]
