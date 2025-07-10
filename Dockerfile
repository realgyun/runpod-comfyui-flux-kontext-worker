# 베이스 이미지 설정
FROM runpod/worker-comfyui:5.2.0-base

# 시스템 패키지 설치
RUN apt-get update && apt-get install -y git && rm -rf /var/lib/apt/lists/*

# 모델 저장 디렉토리 생성
RUN mkdir -p \
    /comfyui/models/diffusion_models \
    /comfyui/models/vae \
    /comfyui/models/text_encoders

# 모델 파일 다운로드 (Docker 캐싱 활용을 위해 먼저 실행)

# Diffusion 모델 - Nunchaku FLUX 4-bit 양자화 모델
RUN comfy model download --url "https://huggingface.co/mit-han-lab/nunchaku-flux.1-kontext-dev/resolve/main/svdq-fp4_r32-flux.1-kontext-dev.safetensors?download=true" --relative-path models/diffusion_models --filename "svdq-fp4_r32-flux.1-kontext-dev.safetensors"

# VAE 모델
RUN wget -O "/comfyui/models/vae/ae.safetensors" "https://huggingface.co/lovis93/testllm/resolve/ed9cf1af7465cebca4649157f118e331cf2a084f/ae.safetensors?download=true"

# 텍스트 인코더 모델들
RUN wget -O "/comfyui/models/text_encoders/clip_l.safetensors" "https://huggingface.co/comfyanonymous/flux_text_encoders/resolve/main/clip_l.safetensors?download=true"
RUN wget -O "/comfyui/models/text_encoders/t5xxl_fp16.safetensors" "https://huggingface.co/comfyanonymous/flux_text_encoders/resolve/main/t5xxl_fp16.safetensors?download=true"
RUN wget -O "/comfyui/models/text_encoders/t5xxl_fp8_e4m3fn.safetensors" "https://huggingface.co/comfyanonymous/flux_text_encoders/blob/main/t5xxl_fp8_e4m3fn.safetensors?download=true"

# LoRA 모델 - FLUX Turbo Alpha
RUN wget -O "/comfyui/models/loras/Lora/diffusion_pytorch_model.safetensors" "https://huggingface.co/alimama-creative/FLUX.1-Turbo-Alpha/blob/main/diffusion_pytorch_model.safetensors?download=true"

# ComfyUI-nunchaku 커스텀 노드 설치 (4-bit 양자화 모델 지원)
RUN cd /comfyui/custom_nodes && \
    git clone https://github.com/mit-han-lab/ComfyUI-nunchaku nunchaku_nodes

# ComfyUI-Impact-Pack 커스텀 노드 설치 (고급 이미지 처리 기능)
RUN cd /comfyui/custom_nodes && \
    git clone https://github.com/ltdrdata/ComfyUI-Impact-Pack comfyui-impact-pack && \
    cd comfyui-impact-pack && \
    pip install -r requirements.txt || true

# 추가 커스텀 노드 설치
RUN comfy-node-install \
    was-node-suite-comfyui
