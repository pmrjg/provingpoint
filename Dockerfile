# Base image: CUDA 11.8, Python 3.10, Ubuntu 22.04
FROM nvcr.io/nvidia/driver:570-5.15.0-143-generic-ubuntu22.04 AS nvidia
FROM ubuntu:jammy AS jammy

WORKDIR /workspace

# System dependencies
RUN -from=jammy apt-get update && apt-get install -y wget curl git vim htop tmux build-essential \
    && rm -rf /var/lib/apt/lists/*

# Install Miniconda 23.3.1 (Python 3.10)
RUN -from=jammy wget https://repo.anaconda.com/miniconda/Miniconda3-py310_23.3.1-0-Linux-x86_64.sh -O miniconda.sh && \
    bash miniconda.sh -b -p /opt/conda && \
    rm miniconda.sh && \
    /opt/conda/bin/conda clean -tipsy

ENV PATH="/opt/conda/bin:$PATH"

RUN --mount=type=secret,id=jupyter_token,dst=/etc/secrets/token echo 0

# Install PyTorch 2.0.1 with CUDA 11.8
RUN conda activate && \
    pip install -y torch==2.0.1+cu118 torchvision torchaudio --index-url https://download.pytorch.org/whl/cu118

# Install JupyterLab and common data science packages
RUN conda install -y -c conda-forge \
    jupyterlab jupyter notebook ipywidgets matplotlib seaborn pandas numpy scipy scikit-learn plotly tqdm && \
    conda clean -tipsy

# Install additional pip packages
RUN pip install --no-cache-dir \
    tensorboard transformers==4.36.0 datasets==2.18.0 peft==0.5.0 accelerate wandb opencv-python pillow

# Generate Jupyter config and set secure token authentication
RUN jupyter lab --generate-config
# Use a strong, pre-generated token (see below)
RUN echo "c.ServerApp.ip = '0.0.0.0'" >> /root/.jupyter/jupyter_lab_config.py && \
    echo "c.ServerApp.port = 8888" >> /root/.jupyter/jupyter_lab_config.py && \
    echo "c.ServerApp.allow_root = True" >> /root/.jupyter/jupyter_lab_config.py && \
    echo "c.ServerApp.open_browser = False" >> /root/.jupyter/jupyter_lab_config.py && \
    echo "c.ServerApp.token = '$(cat /etc/secrets/token)'" >> /root/.jupyter/jupyter_lab_config.py

# Startup script
RUN echo '#!/bin/bash' > /start.sh && \
    echo 'echo "Starting Jupyter Lab..."' >> /start.sh && \
    echo 'jupyter lab --ip=0.0.0.0 --port=8888 --allow-root --no-browser &' >> /start.sh && \
    echo 'tail -f /dev/null' >> /start.sh && \
    chmod +x /start.sh

EXPOSE 8888 22 443
CMD ["/start.sh"]
