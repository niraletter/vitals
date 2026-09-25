# Vitals

**Native system monitor for Omarchy.**

A compact metric lives in the top bar. Click it to open a dashboard with CPU, memory, swap, GPU, storage, network, and process information.

https://github.com/user-attachments/assets/4a33f637-2eac-4e74-89c9-834af9f2a63a

## Installation
```bash
omarchy plugin add https://github.com/niraletter/vitals.git --enable
```

### Install from a local checkout

Copy the repository into the user plugin directory:

```bash
mkdir -p ~/.config/omarchy/plugins
cp -r vitals ~/.config/omarchy/plugins/vitals
```

Then enable it:

```bash
omarchy plugin enable vitals
```

If the bar does not update automatically, restart the shell:

```bash
omarchy restart shell
```

## Features

| Feature | Description |
| :--- | :--- |
| **Bar** | Pin one or more of CPU, memory, GPU, storage, disk, or network to the top bar. |
| **CPU & memory** | Usage, temperature, fans, uptime, per-core load, RAM, and swap. |
| **GPU** | Intel, AMD, and NVIDIA. Usage, chip/hotspot temperature, VRAM, and per-app stats. |
| **Storage & network** | Disk space, I/O speeds, live rates, and **WIFI** / **ETH** labels. |
| **Processes** | Search, filter, sort, inspect commands, and end tasks. |
| **Dashboard** | Expand tiles for more detail. Optional mini graphs. |
| **Theme** | Matches Omarchy. High usage turns red. |
| **Efficiency** | Stays light when closed; full stats when you open the dashboard. |

## Requirements

Omarchy with the shell plugin system and Quickshell bar widget support. Missing optional tools only disable their related metric.

| Tool | Provides |
| :--- | :--- |
| `intel_gpu_top` (`intel-gpu-tools`) | Intel GPU device usage (i915 PMU) |
| `pkexec` / polkit | One-time Intel GPU install and `CAP_PERFMON` setup prompts |
| `sensors` | Additional temperatures (`lm_sensors`) |
| `nvidia-smi` | NVIDIA GPU and VRAM data |

### Intel GPU setup

Intel device usage reads i915 performance counters through `intel_gpu_top`, similar to btop. On the **first dashboard open** with an Intel GPU, Vitals automatically:

1. Installs `intel-gpu-tools` if missing (via `pkexec` + your package manager)
2. Grants `CAP_PERFMON` to `intel_gpu_top` with `setcap` (persists across reboot)

Approve the system authentication dialog when it appears. Once setup succeeds, it won't run again.

Manual setup if auto-setup fails:

```bash
# Arch
sudo pacman -S --needed intel-gpu-tools
sudo setcap cap_perfmon=ep "$(command -v intel_gpu_top)"
```

If the GPU tile shows **PMU access needed**, `cap_perfmon` is not granted — run the `setcap` command above or reopen the dashboard to retry.

Per-process Intel GPU stats use DRM fdinfo (shared memory and per-app engine time).

## Updating and removing

```bash
omarchy plugin update vitals
omarchy plugin disable vitals
omarchy plugin enable vitals
omarchy plugin remove vitals --yes
```

## License

This project is licensed under the [MIT License](LICENSE).
