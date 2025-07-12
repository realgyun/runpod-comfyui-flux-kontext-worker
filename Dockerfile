# 베이스 이미지 설정
FROM runpod/worker-comfyui:5.2.0-base

# 시스템 패키지 설치
RUN apt-get update && apt-get install -y \
    git \
    wget \
    && rm -rf /var/lib/apt/lists/*

# Python 패키지 설치
RUN pip install --no-cache-dir \
    pyyaml

# models.yaml.example 파일 복사 (빌드 시 필수)
COPY models.yaml.example /etc/comfyui/models.yaml

# 시작 스크립트 복사 및 권한 설정
COPY start.sh /start-with-network-volume.sh
RUN chmod +x /start-with-network-volume.sh

# 디버깅 스크립트 복사 및 권한 설정
COPY debug-volume.sh /usr/local/bin/debug-volume
RUN chmod +x /usr/local/bin/debug-volume

# 환경 변수 설정 (기본값)
ENV USE_NETWORK_VOLUME="true"
ENV NETWORK_VOLUME_PATH="/workspace"
ENV COMFYUI_REPO_NAME="ComfyUI"
ENV GIT_PULL="true"
ENV DOWNLOAD_MODELS="true"

# CMD로 설정 (RunPod worker와 호환성을 위해)
CMD ["/start-with-network-volume.sh"]