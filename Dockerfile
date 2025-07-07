FROM runpod/worker-comfyui:5.2.0-base

RUN apt-get update && apt-get install -y git && rm -rf /var/lib/apt/lists/*

RUN mkdir -p \
    /comfyui/models/diffusion_models \
    /comfyui/models/vae \
    /comfyui/models/text_encoders

# 5. Download all the large, slow models first to leverage Docker caching.
# IMPORTANT: You must find the real download URLs for these models.

# --- Diffusion Model ---
RUN comfy model download --url "https://huggingface.co/Comfy-Org/flux1-kontext-dev_ComfyUI/resolve/main/split_files/diffusion_models/flux1-dev-kontext_fp8_scaled.safetensors?download=true" --relative-path models/diffusion_models --filename "flux1-dev-kontext_fp8_scaled.safetensors"
# --- VAE Model ---
RUN wget -O "/comfyui/models/vae/ae.safetensors" "https://huggingface.co/lovis93/testllm/resolve/ed9cf1af7465cebca4649157f118e331cf2a084f/ae.safetensors?download=true"

# --- CLIP (Text Encoder) Models ---
RUN wget -O "/comfyui/models/text_encoders/clip_l.safetensors" "https://huggingface.co/comfyanonymous/flux_text_encoders/resolve/main/clip_l.safetensors?download=true"
RUN wget -O "/comfyui/models/text_encoders/t5xxl_fp16.safetensors" "https://huggingface.co/comfyanonymous/flux_text_encoders/resolve/main/t5xxl_fp16.safetensors?download=true"


RUN comfy-node-install \
    was-node-suite-comfyui
