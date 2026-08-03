+++
title = "Running Kubernetes with a GPU Inside WSL2 on My RTX Laptop"
description = "Run Kubernetes with NVIDIA GPU support inside WSL2 on a laptop, from k3s setup and validation to the limits of local GPU workloads."
date = 2026-04-22
draft = false

[taxonomies]
tags = ["kubernetes", "wsl2", "nvidia", "gpu", "k3s", "ml-infrastructure"]

[extra]
keywords = "kubernetes, wsl2, nvidia, gpu, k3s, ml-infrastructure"
toc = true
static_thumbnail = "/images/social-wsl-nvidia-gpu.png"

+++

I wanted a local environment where I could:

- run Kubernetes
- schedule GPU workloads
- experiment with CUDA / inference / device plugins
- avoid renting cloud GPUs

I used a Lenovo Legion laptop with an RTX GPU. The working stack was:

- Windows 11 + NVIDIA driver (WSL-enabled)
- WSL2 (Ubuntu 24.04)
- K3s (containerd)
- NVIDIA Container Toolkit
- NVIDIA device plugin

The non-obvious part was that the NVIDIA device plugin itself had to use `runtimeClassName: nvidia`.

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

Continue if this command detects the GPU.

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

Do not install Linux NVIDIA drivers inside WSL:

```bash
apt install nvidia-utils-*
```

They can conflict with the driver components provided by Windows.

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

It should print:

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

## Step 7: Run the device plugin with the NVIDIA runtime

On my setup, the plugin started but detected no GPUs.

Logs look like:

```bash
No devices found. Waiting indefinitely.
```

Set the DaemonSet's runtime class to `nvidia`:

```bash
kubectl patch daemonset nvidia-device-plugin-daemonset \
  -n kube-system \
  --type='merge' \
  -p '{"spec":{"template":{"spec":{"runtimeClassName":"nvidia"}}}}'
```

Restart the plugin pod:

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

## Limits

This setup is good for:

- learning Kubernetes GPU scheduling
- testing inference workloads
- experimenting with device plugins
- prototyping LLM infra locally

It is not suitable for:

- performance benchmarking
- multi-GPU experiments
- production-like environments

Save the working DaemonSet configuration if you want to reuse it:

```bash
kubectl get ds nvidia-device-plugin-daemonset -n kube-system -o yaml > nvidia-device-plugin-wsl2.yaml
```
