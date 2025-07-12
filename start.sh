#!/bin/bash

echo "Starting ComfyUI with network volume support..."

# ===== 환경 변수 설정 =====
USE_NETWORK_VOLUME=${USE_NETWORK_VOLUME:-"true"}
NETWORK_VOLUME_PATH=${NETWORK_VOLUME_PATH:-"/workspace"}
RUNPOD_VOLUME_PATH="/runpod-volume"
COMFYUI_REPO_NAME=${COMFYUI_REPO_NAME:-"ComfyUI"}
GIT_PULL=${GIT_PULL:-"true"}
DOWNLOAD_MODELS=${DOWNLOAD_MODELS:-"true"}

# ===== 네트워크 볼륨 경로 감지 =====
# Serverless 환경 확인
if [ -d "$RUNPOD_VOLUME_PATH" ] && [ "$(ls -A $RUNPOD_VOLUME_PATH)" ]; then
    echo "Detected Serverless environment with network volume at $RUNPOD_VOLUME_PATH"
    VOLUME_PATH=$RUNPOD_VOLUME_PATH
# Pod 환경 확인
elif [ -d "$NETWORK_VOLUME_PATH" ] && [ "$(ls -A $NETWORK_VOLUME_PATH)" ]; then
    echo "Detected Pod environment with network volume at $NETWORK_VOLUME_PATH"
    VOLUME_PATH=$NETWORK_VOLUME_PATH
# 네트워크 볼륨 없음
else
    echo "No network volume detected, using built-in ComfyUI"
    USE_NETWORK_VOLUME="false"
fi

# ===== 네트워크 볼륨 사용 시 처리 =====
if [ "$USE_NETWORK_VOLUME" = "true" ] && [ -n "$VOLUME_PATH" ]; then
    COMFYUI_PATH="$VOLUME_PATH/$COMFYUI_REPO_NAME"
    
    # ComfyUI 디렉토리 확인
    if [ ! -d "$COMFYUI_PATH" ]; then
        echo "Warning: ComfyUI not found at $COMFYUI_PATH"
        echo "Using built-in ComfyUI"
        USE_NETWORK_VOLUME="false"
    else
        echo "Found ComfyUI at $COMFYUI_PATH"
        
        # Git 저장소인 경우 업데이트
        if [ -d "$COMFYUI_PATH/.git" ] && [ "$GIT_PULL" = "true" ]; then
            echo "Updating ComfyUI repository..."
            cd "$COMFYUI_PATH"
            
            # Git 안전 디렉토리 설정
            git config --global --add safe.directory "$COMFYUI_PATH"
            
            # Git 인증 정보 연결 (네트워크 볼륨에 저장된 경우)
            GIT_AUTH_FILE="$VOLUME_PATH/git_auth/.git-credentials"
            if [ -f "$GIT_AUTH_FILE" ]; then
                echo "Setting up Git authentication..."
                ln -sf "$GIT_AUTH_FILE" ~/.git-credentials
                git config --global credential.helper store
                echo "Git authentication configured"
            fi
            
            # Git pull
            echo "Running git pull..."
            if git pull; then
                echo "Successfully updated ComfyUI"
            else
                echo "Warning: git pull failed, continuing with existing files"
            fi
            
            # Submodule 업데이트
            echo "Updating git submodules..."
            if git submodule update --init --recursive; then
                echo "Successfully updated submodules"
            else
                echo "Warning: git submodule update failed, continuing with existing submodules"
            fi
            
            cd /
        fi
        
        # ComfyUI 심볼릭 링크 생성
        if [ -d "/comfyui" ] && [ ! -L "/comfyui" ]; then
            echo "Backing up existing ComfyUI..."
            mv /comfyui /comfyui_backup
        fi
        
        if [ ! -e "/comfyui" ]; then
            echo "Creating symlink from $COMFYUI_PATH to /comfyui"
            ln -sfn "$COMFYUI_PATH" /comfyui
        fi
        
        # 모델 다운로드 (models.yaml 기반)
        if [ "$DOWNLOAD_MODELS" = "true" ] && [ -f "$COMFYUI_PATH/models.yaml" ]; then
            echo "Downloading models based on models.yaml..."
            
            # Python 스크립트로 모델 다운로드
            COMFYUI_PATH="$COMFYUI_PATH" python3 << 'EOF'
import yaml
import os
import subprocess
import time

def download_file(url, dest_path, max_retries=3):
    """wget을 사용하여 파일 다운로드"""
    dest_dir = os.path.dirname(dest_path)
    if not os.path.exists(dest_dir):
        os.makedirs(dest_dir, exist_ok=True)
    
    # 이미 파일이 존재하면 건너뛰기
    if os.path.exists(dest_path):
        print(f"  ✓ Already exists: {os.path.basename(dest_path)}")
        return True
    
    print(f"  ⬇ Downloading: {os.path.basename(dest_path)}")
    
    for attempt in range(max_retries):
        try:
            # wget with continue option
            cmd = ['wget', '-c', '-O', dest_path, url]
            result = subprocess.run(cmd, capture_output=True, text=True)
            
            if result.returncode == 0:
                print(f"  ✓ Downloaded: {os.path.basename(dest_path)}")
                return True
            else:
                print(f"  ✗ Attempt {attempt + 1} failed")
                if attempt < max_retries - 1:
                    time.sleep(5)
        except Exception as e:
            print(f"  ✗ Error: {str(e)}")
            if attempt < max_retries - 1:
                time.sleep(5)
    
    # 실패 시 부분 파일 삭제
    if os.path.exists(dest_path):
        os.remove(dest_path)
    return False

# ComfyUI 경로
comfyui_path = os.environ.get('COMFYUI_PATH', '/comfyui')
models_yaml_path = os.path.join(comfyui_path, 'models.yaml')

if not os.path.exists(models_yaml_path):
    print(f"models.yaml not found at {models_yaml_path}")
    exit(0)

# YAML 파일 읽기
try:
    with open(models_yaml_path, 'r') as f:
        config = yaml.safe_load(f)
except Exception as e:
    print(f"Error reading models.yaml: {e}")
    exit(1)

# 모델 다운로드
models = config.get('models', {})
download_settings = config.get('download_settings', {})
max_retries = download_settings.get('max_retries', 3)

for model_type, model_list in models.items():
    if not isinstance(model_list, list):
        continue
    
    print(f"\n=== {model_type} ===")
    
    for model in model_list:
        if not isinstance(model, dict):
            continue
        
        name = model.get('name')
        url = model.get('url')
        folder = model.get('folder', '')
        
        if not name or not url:
            continue
        
        # 대상 경로 구성
        if folder:
            dest_path = os.path.join(comfyui_path, 'models', model_type, folder, name)
        else:
            dest_path = os.path.join(comfyui_path, 'models', model_type, name)
        
        # 다운로드 실행
        download_file(url, dest_path, max_retries)

print("\nModel download completed!")
EOF
            
        elif [ -f "$COMFYUI_PATH/models.yaml" ]; then
            echo "Model downloading is disabled (DOWNLOAD_MODELS=false)"
        else
            echo "No models.yaml found, skipping model download"
        fi
        
        # Python 의존성 설치
        if [ -f "$COMFYUI_PATH/requirements.txt" ]; then
            echo "Installing ComfyUI Python dependencies..."
            cd /comfyui
            pip install -r requirements.txt --no-cache-dir || true
            cd /
        fi
        
        # 커스텀 노드 의존성 설치
        if [ -d "$COMFYUI_PATH/custom_nodes" ]; then
            echo "Installing custom nodes dependencies..."
            for node_dir in "$COMFYUI_PATH/custom_nodes"/*; do
                if [ -d "$node_dir" ] && [ -f "$node_dir/requirements.txt" ]; then
                    node_name=$(basename "$node_dir")
                    echo "  Installing for $node_name..."
                    pip install -r "$node_dir/requirements.txt" --no-cache-dir || echo "  Warning: Failed for $node_name"
                fi
            done
        fi
    fi
else
    echo "Using built-in ComfyUI (no network volume)"
fi

# ===== RunPod 기본 시작 스크립트 실행 =====
echo "Starting RunPod ComfyUI worker..."
exec /start.sh