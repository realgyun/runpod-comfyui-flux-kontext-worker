#!/bin/bash

echo "=== RunPod Volume Debugger ==="
echo "현재 시간: $(date)"
echo ""

# 환경 정보
echo "=== 환경 정보 ==="
echo "Hostname: $(hostname)"
echo "Container ID: ${RUNPOD_POD_ID:-'Not set'}"
echo "Pod ID: ${RUNPOD_POD_ID:-'Not set'}"
echo "환경 타입: ${RUNPOD_ENVIRONMENT_NAME:-'Unknown'}"
echo ""

# 마운트 포인트 확인
echo "=== 볼륨 마운트 확인 ==="
echo "RUNPOD_VOLUME_PATH 환경변수: ${RUNPOD_VOLUME_PATH:-'설정되지 않음'}"
echo ""

if [ -d "/workspace" ]; then
    echo "✓ /workspace 존재"
    echo "  내용: $(ls -la /workspace 2>/dev/null | head -5)"
else
    echo "✗ /workspace 없음"
fi

if [ -d "/runpod-volume" ]; then
    echo "✓ /runpod-volume 존재"
    echo "  내용: $(ls -la /runpod-volume 2>/dev/null | head -5)"
else
    echo "✗ /runpod-volume 없음"
fi
echo ""

# 모델 디렉토리 확인
echo "=== 모델 디렉토리 구조 ==="
for volume_path in /workspace /runpod-volume; do
    if [ -d "$volume_path/models" ]; then
        echo "📁 $volume_path/models:"
        for model_type in checkpoints diffusion_models loras vae text_encoders; do
            if [ -d "$volume_path/models/$model_type" ]; then
                count=$(ls -1 "$volume_path/models/$model_type" 2>/dev/null | wc -l)
                echo "  - $model_type: $count 파일"
                ls -lh "$volume_path/models/$model_type" 2>/dev/null | head -3 | sed 's/^/    /'
            fi
        done
        echo ""
    fi
done

# 커스텀 노드 확인
echo "=== 커스텀 노드 ==="
for volume_path in /workspace /runpod-volume; do
    if [ -d "$volume_path/custom_nodes" ]; then
        echo "📁 $volume_path/custom_nodes:"
        ls -1 "$volume_path/custom_nodes" 2>/dev/null | sed 's/^/  - /'
        echo ""
    fi
done

# ComfyUI Git 저장소 상태
echo "=== ComfyUI Git 저장소 상태 ==="
for volume_path in /workspace /runpod-volume; do
    COMFYUI_PATH="$volume_path/${COMFYUI_REPO_NAME:-ComfyUI}"
    if [ -d "$COMFYUI_PATH/.git" ]; then
        echo "📁 $COMFYUI_PATH:"
        cd "$COMFYUI_PATH" 2>/dev/null
        echo "  Branch: $(git branch --show-current 2>/dev/null || echo 'unknown')"
        echo "  Last commit: $(git log -1 --oneline 2>/dev/null || echo 'unknown')"
        
        # 변경사항 확인
        if [ -n "$(git status --porcelain 2>/dev/null)" ]; then
            echo "  ⚠️  Uncommitted changes detected"
        fi
        cd - >/dev/null 2>&1
        echo ""
    fi
done

# ComfyUI 링크 상태
echo "=== ComfyUI 심볼릭 링크 상태 ==="
if [ -L "/comfyui" ]; then
    target=$(readlink "/comfyui")
    echo "📁 /comfyui → $target ✓"
elif [ -d "/comfyui" ]; then
    echo "📁 /comfyui (디렉토리)"
else
    echo "📁 /comfyui (없음)"
fi

echo "📁 /comfyui/models:"
for model_type in checkpoints diffusion_models loras vae text_encoders; do
    if [ -L "/comfyui/models/$model_type" ]; then
        target=$(readlink "/comfyui/models/$model_type")
        echo "  - $model_type → $target ✓"
    elif [ -d "/comfyui/models/$model_type" ]; then
        echo "  - $model_type (디렉토리)"
    else
        echo "  - $model_type (없음)"
    fi
done

echo ""
echo "=== 디스크 사용량 ==="
df -h | grep -E "Filesystem|workspace|runpod-volume|/$" | column -t

echo ""
echo "=== 문제 해결 팁 ==="
if [ ! -d "/workspace" ] && [ ! -d "/runpod-volume" ]; then
    echo "⚠️  네트워크 볼륨이 마운트되지 않았습니다."
    echo "   - RunPod 콘솔에서 네트워크 볼륨이 연결되었는지 확인하세요."
    echo "   - Pod/Serverless 설정에서 볼륨을 선택했는지 확인하세요."
elif [ -d "/runpod-volume" ]; then
    echo "ℹ️  Serverless 환경으로 감지됨 (/runpod-volume)"
    echo "   모델은 /runpod-volume/models/ 아래에 있어야 합니다."
elif [ -d "/workspace" ]; then
    echo "ℹ️  Pod 환경으로 감지됨 (/workspace)"
    echo "   모델은 /workspace/models/ 아래에 있어야 합니다."
fi