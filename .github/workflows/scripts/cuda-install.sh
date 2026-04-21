#!/bin/bash
# Copied from vLLM github actions https://github.com/vllm-project/vllm/blob/main/.github/workflows/scripts/cuda-install.sh

# Replace '.' with '-' ex: 11.8 -> 11-8
cuda_version=$(echo "$1" | tr "." "-")
# Map the GitHub runner label to NVIDIA's apt repo path segment, e.g.
#   ubuntu-22.04      -> ubuntu2204
#   ubuntu-24.04-arm  -> ubuntu2404   (NVIDIA splits arch into a separate path segment)
OS=$(echo "$2" | sed -E 's/-arm$//' | tr -d ".\-")

# NVIDIA publishes separate CUDA apt repos per CPU architecture. The repo path
# segment differs from `uname -m`: on ARM servers it's "sbsa" (Server Base
# System Architecture), not "aarch64". Detect the runner arch and pick the
# right path so the same script works on x86_64 and aarch64 GitHub runners.
case "$(uname -m)" in
  x86_64)  arch_path="x86_64" ;;
  aarch64) arch_path="sbsa"   ;;
  *)
    echo "Unsupported architecture: $(uname -m)" >&2
    exit 1
    ;;
esac

# Installs CUDA
wget -nv "https://developer.download.nvidia.com/compute/cuda/repos/${OS}/${arch_path}/cuda-keyring_1.1-1_all.deb"
sudo dpkg -i cuda-keyring_1.1-1_all.deb
rm cuda-keyring_1.1-1_all.deb
sudo apt -qq update
sudo apt -y install "cuda-${cuda_version}" "cuda-nvcc-${cuda_version}" "cuda-libraries-dev-${cuda_version}"
sudo apt clean

# Test nvcc
PATH=/usr/local/cuda-$1/bin:${PATH}
nvcc --version

# Log gcc, g++, c++ versions
gcc --version
g++ --version
c++ --version
