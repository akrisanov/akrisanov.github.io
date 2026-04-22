+++
title = "Running Kubernetes with GPU inside WSL2 on my RTX Laptop)"
description = "A step-by-step guide to setting up Kubernetes with NVIDIA GPU access inside WSL2 on a Windows laptop."
date = 2026-04-22

[taxonomies]
tags = ["kubernetes", "gpu", "wsl2", "nvidia", "k3s", "ml-infra"]

[extra]
keywords = "kubernetes, gpu, wsl2, nvidia, k3s, ml-infra, local cluster"
toc = true
+++

## Why I did this

I wanted a local environment where I can:

- run Kubernetes
- schedule GPU workloads
- experiment with CUDA / inference / device plugins
- without renting cloud GPUs

I have a Lenovo Legion laptop with an RTX GPU and WSL2. Turns out:

> Yes, you can run Kubernetes with GPU access inside WSL2.
> But there are a couple of non-obvious traps.

This is a step-by-step guide based on a working setup.

## TL;DR

Final stack:

- Windows 11 + NVIDIA driver (WSL-enabled)
- WSL2 (Ubuntu 24.04)
- K3s (containerd)
- NVIDIA Container Toolkit
- NVIDIA device plugin
- One critical fix: **device plugin must use `runtimeClassName: nvidia`**

## Prerequisites

You need:

- Windows 11
- NVIDIA GPU (RTX in my case)
- Latest NVIDIA driver **with WSL support**
- WSL2 installed

Inside WSL:

```bash
nvidia-smi
```

If this works — you’re good.

## Step 1: Don’t install Linux NVIDIA drivers

WSL already provides everything via:

```bash
/usr/lib/wsl/lib/
```

If `nvidia-smi` is missing:

```bash
echo 'export PATH=$PATH:/usr/lib/wsl/lib' >> ~/.bashrc
source ~/.bashrc
```

Do **NOT** run:

```bash
apt install nvidia-utils-*
```

You will break your setup.

## Step 2: Install NVIDIA Container Toolkit

```bash
curl -fsSL https://nvidia.github.io/libnvidia-container/gpgkey | \
  sudo gpg --dearmor -o /usr/share/keyrings/nvidia-container-toolkit-keyring.gpg

curl -s -L https://nvidia.github.io/libnvidia-container/stable/deb/nvidia-container-toolkit.list | \
  sed 's#deb https://#deb [signed-by=/usr/share/keyrings/nvidia-container-toolkit-keyring.gpg] https://#g' | \
  sudo tee /etc/apt/sources.list.d/nvidia-container-toolkit.list

sudo apt update
sudo apt install -y nvidia-container-toolkit
```

## Step 3: Verify GPU in containers (Podman)

Generate CDI config:

```bash
sudo mkdir -p /etc/cdi
sudo nvidia-ctk cdi generate --output=/etc/cdi/nvidia.yaml
```

Test:

```bash
podman run --rm --device=nvidia.com/gpu=all ubuntu nvidia-smi
```

## Step 4: Install K3s

Make sure systemd is enabled:

```bash
ps -p 1 -o comm=
```

Should print:

```bash
systemd
```

Install K3s:

```bash
curl -sfL https://get.k3s.io | sh -
```

Configure kubeconfig:

```bash
mkdir -p ~/.kube
sudo cp /etc/rancher/k3s/k3s.yaml ~/.kube/config
sudo chown $USER:$USER ~/.kube/config
export KUBECONFIG=~/.kube/config
```

Check:

```bash
kubectl get nodes
```

## Step 5: Enable NVIDIA runtime in K3s

```bash
sudo nvidia-ctk runtime configure --runtime=containerd
sudo systemctl restart k3s
```

Verify:

```bash
sudo grep nvidia /var/lib/rancher/k3s/agent/etc/containerd/config.toml
```

## Step 6: Install NVIDIA device plugin

```bash
kubectl apply -f \
https://raw.githubusercontent.com/NVIDIA/k8s-device-plugin/v0.17.1/deployments/static/nvidia-device-plugin.yml
```

Check:

```bash
kubectl get ds -n kube-system | grep nvidia
kubectl get pods -n kube-system | grep nvidia
```

## Step 7: The critical fix (WSL2-specific)

At this point the plugin runs but sees zero GPUs.

Logs look like:

```bash
No devices found. Waiting indefinitely.
```

Fix:

```bash
kubectl patch daemonset nvidia-device-plugin-daemonset \
  -n kube-system \
  --type='merge' \
  -p '{"spec":{"template":{"spec":{"runtimeClassName":"nvidia"}}}}'
```

Restart pod:

```bash
kubectl delete pod -n kube-system -l name=nvidia-device-plugin-ds
```

Verify:

```bash
kubectl get node -o jsonpath='{.status.capacity.nvidia\.com/gpu}'
```

Expected:

```bash
1
```

## Step 8: Run a GPU workload

```bash
cat <<'EOF' | kubectl apply -f -
apiVersion: v1
kind: Pod
metadata:
  name: cuda-smoke-test
spec:
  restartPolicy: Never
  runtimeClassName: nvidia
  containers:
  - name: cuda
    image: nvcr.io/nvidia/k8s/cuda-sample:nbody
    args: ["nbody", "-gpu", "-benchmark"]
    resources:
      limits:
        nvidia.com/gpu: 1
EOF
```

Watch:

```bash
kubectl get pod cuda-smoke-test -w
kubectl logs cuda-smoke-test
```

## What actually broke on my first attempts

Everything worked except one subtle thing:

> The NVIDIA device plugin itself was running under the wrong runtime.

Even though, containerd knew about NVIDIA, Podman could use GPU, and CUDA worked.

The plugin pod still used default runtime → no GPU → no resources.

Setting:

```bash
runtimeClassName: nvidia
```

fixed it.

## Final result

After following these steps, you should have:

- local Kubernetes cluster
- GPU scheduling
- CUDA workloads
- no cloud costs

All inside WSL2.

## When to use this

This setup is good for:

- learning Kubernetes GPU scheduling
- testing inference workloads
- experimenting with device plugins
- prototyping LLM infra locally

Not great for:

- performance benchmarking
- multi-GPU experiments
- production-like environments

## One last tip

Save your working config:

```bash
kubectl get ds nvidia-device-plugin-daemonset -n kube-system -o yaml > nvidia-device-plugin-wsl2.yaml
```

This saves you from debugging this again later.
