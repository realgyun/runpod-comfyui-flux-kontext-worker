# RunPod ComfyUI FLUX Kontext Worker

Nunchaku FLUX 4-bit 양자화 모델과 Kontext 확장을 지원하는 RunPod ComfyUI Worker입니다.

## 특징

- **FLUX Kontext Dev 4-bit 양자화 모델** 지원
- **Hugging Face 기반 모델 관리** - models.yaml로 모델 목록 관리
- **자동 모델 다운로드** - 시작 시 필요한 모델만 다운로드 (2GB 이상 지원)
- **Git 기반 코드 관리** - ComfyUI와 커스텀 노드는 Git으로 관리
- **듀얼 모드** - 내장 ComfyUI 또는 네트워크 볼륨의 ComfyUI 사용

## Hugging Face 기반 네트워크 볼륨 사용하기

### 1. RunPod에서 네트워크 볼륨 생성

1. RunPod 콘솔에서 "Storage" → "Network Volumes" 선택
2. "New Network Volume" 클릭
3. 볼륨 이름과 크기 설정 (최소 100GB 권장 - ComfyUI + 모델)
4. **중요**: Pod/Serverless와 같은 지역 선택

### 2. ComfyUI Git 저장소 설정 (Pod에서)

```bash
# GPU Pod 생성하고 네트워크 볼륨 연결
# SSH로 접속 후:

cd /workspace

# ComfyUI 클론 (또는 포크한 저장소)
git clone https://github.com/your-username/ComfyUI.git
cd ComfyUI

# models.yaml 파일 생성
cp /path/to/models.yaml.example models.yaml
# 또는 직접 작성
nano models.yaml

# Git에 추가 (모델 파일은 제외)
git add models.yaml
git commit -m "Add models configuration"
git push

# 커스텀 노드 추가 (submodule로)
git submodule add https://github.com/ltdrdata/ComfyUI-Impact-Pack custom_nodes/ComfyUI-Impact-Pack
git submodule add https://github.com/mit-han-lab/ComfyUI-nunchaku custom_nodes/ComfyUI-nunchaku
git commit -m "Add custom nodes"
git push
```

### 3. Pod/Serverless 설정

#### Pod 사용 시:
1. Pod 생성 시 "Container Configuration" → "Select Network Volume"에서 볼륨 선택
2. 자동으로 `/workspace`에 마운트됨

#### Serverless 사용 시:
1. Endpoint 생성 시 "Advanced" → "Select Network Volume"에서 볼륨 선택
2. 자동으로 `/runpod-volume`에 마운트됨

## Hugging Face 워크플로우 (Pod → Serverless)

### 시나리오: Pod에서 모델 설정 업데이트 → Serverless에서 자동 다운로드

1. **Pod에서 models.yaml 업데이트**
   ```bash
   # GPU Pod 접속
   cd /workspace/ComfyUI
   
   # models.yaml 편집
   nano models.yaml
   
   # 새 모델 추가 예시:
   # loras:
   #   - name: "new-lora.safetensors"
   #     url: "https://huggingface.co/..."
   #     size: "1.5GB"
   
   # Git에 커밋
   git add models.yaml
   git commit -m "Add new LoRA model to configuration"
   git push
   ```

2. **Serverless Endpoint 생성**
   - Container Image: `your-dockerhub/comfyui-flux-kontext`
   - Network Volume: 위에서 사용한 동일한 볼륨 선택
   - 환경 변수 설정 필요 없음 (자동 감지)

3. **Serverless에서 자동 처리**
   ```
   시작 시 자동 실행:
   1. /runpod-volume/ComfyUI 감지
   2. git pull 실행 (최신 설정 가져오기)
   3. models.yaml 읽어서 필요한 모델 확인
   4. 없는 모델만 Hugging Face에서 다운로드
   5. /comfyui로 심볼릭 링크 생성
   6. ComfyUI 시작
   ```

4. **장점**
   - **대용량 모델 지원**: Git LFS의 2GB 제한 없음
   - **선택적 다운로드**: 필요한 모델만 다운로드
   - **버전 관리**: models.yaml로 모델 버전 추적
   - **빠른 업데이트**: 설정 파일만 변경하면 됨

### 장점
- **비용 절감**: GPU Pod는 모델 업로드 시에만 사용
- **빠른 시작**: Serverless는 모델이 이미 준비되어 있어 빠르게 시작
- **유연성**: 언제든지 Pod에서 모델 추가/수정 가능

### 환경 변수 설정

| 변수명 | 기본값 | 설명 |
|--------|--------|------|
| `USE_NETWORK_VOLUME` | `true` | 네트워크 볼륨 사용 여부 |
| `NETWORK_VOLUME_PATH` | `/workspace` | 네트워크 볼륨 마운트 경로 (Pod) |
| `COMFYUI_REPO_NAME` | `ComfyUI` | ComfyUI 저장소 폴더명 |
| `GIT_PULL` | `true` | 시작 시 git pull 실행 여부 |
| `DOWNLOAD_MODELS` | `true` | models.yaml 기반 모델 다운로드 여부 |

## models.yaml 설정

`models.yaml.example`을 참고하여 필요한 모델을 설정합니다:

```yaml
models:
  diffusion_models:
    - name: "flux-model.safetensors"
      url: "https://huggingface.co/..."
      size: "4.5GB"
  loras:
    - name: "style-lora.safetensors"
      url: "https://huggingface.co/..."
      size: "1.2GB"
      folder: "Lora"  # 선택사항: 하위 폴더
```

## 로컬 테스트

```bash
# 네트워크 볼륨 시뮬레이션
mkdir -p network-volume
cd network-volume
git clone https://github.com/your-username/ComfyUI.git
cd ComfyUI
cp /path/to/models.yaml .

# Docker Compose로 실행
cd ../..
docker-compose up --build
```

## 네트워크 볼륨 구조

```
/workspace/ (Pod) 또는 /runpod-volume/ (Serverless)
└── ComfyUI/                # Git 저장소
    ├── .git/              # Git 메타데이터
    ├── models.yaml        # 모델 설정 파일
    ├── models/            # 모델 저장 디렉토리 (다운로드됨)
    │   ├── checkpoints/
    │   ├── diffusion_models/
    │   ├── loras/
    │   ├── vae/
    │   └── text_encoders/
    ├── custom_nodes/      # Git submodules
    └── requirements.txt
```

## 빌드 및 배포

### 빌드 전 필수 사항

```bash
# models.yaml 파일 생성 (필수!)
cp models.yaml.example models.yaml

# 필요한 모델 설정 편집
nano models.yaml
```

**중요**: `models.yaml` 파일이 없으면 Docker 빌드가 실패합니다.

### Docker 이미지 빌드

```bash
# Docker 이미지 빌드
docker build -t your-dockerhub-username/comfyui-flux-kontext .

# Docker Hub에 푸시
docker push your-dockerhub-username/comfyui-flux-kontext

# RunPod에서 사용
# Container Image: your-dockerhub-username/comfyui-flux-kontext
```

## 문제 해결

### 디버깅 도구 사용하기

컨테이너 내에서 다음 명령어로 볼륨 상태를 확인할 수 있습니다:
```bash
debug-volume
```

이 명령어는 다음 정보를 표시합니다:
- 환경 타입 (Pod/Serverless)
- 볼륨 마운트 상태
- 모델 디렉토리 구조
- 심볼릭 링크 상태
- 디스크 사용량

### 네트워크 볼륨이 인식되지 않을 때
1. `debug-volume` 명령어로 마운트 상태 확인
2. 볼륨이 올바른 경로에 마운트되었는지 확인
3. 환경 변수 `USE_NETWORK_VOLUME`이 `true`로 설정되어 있는지 확인
4. Pod 로그에서 "Detected network volume" 메시지 확인

### 모델이 로드되지 않을 때
1. 모델 파일이 올바른 디렉토리에 있는지 확인
   - Pod: `/workspace/models/`
   - Serverless: `/runpod-volume/models/`
2. 파일 권한이 올바른지 확인 (읽기 권한 필요)
3. 심볼릭 링크가 올바르게 생성되었는지 확인