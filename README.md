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
| **Bar** | Pin CPU, memory, GPU, storage, disk, or network to the top bar. |
| **CPU & memory** | Usage, temperature, fans, uptime, per-core load, RAM, and swap. |
| **GPU** | Intel, AMD, and NVIDIA. Usage, temperature, VRAM, and per-app stats. |
| **Storage & network** | Disk space, I/O speeds, live rates, and **WIFI** / **ETH** labels. |
| **Processes** | Search, filter, sort, inspect commands, and end tasks. |
| **Dashboard** | Expand tiles for more detail. Optional mini graphs. |
| **Theme** | Matches Omarchy. High usage turns red. |
| **Efficiency** | Stays light when closed; full stats when you open the dashboard. |

## Requirements

Omarchy with the shell plugin system and Quickshell bar widget support. Missing optional tools only disable their related metric.

| Tool | Provides |
| :--- | :--- |
| `ps` | Process data |
| `df` | Filesystem capacity |
| `ip` | Local address information |
| `ss` | Per-process network bandwidth (`ss -tanpi`) |
| `lspci` | GPU discovery |
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

## Configuration

The widget can be configured in `~/.config/omarchy/shell.json`. Add or edit the `vitals` entry:

```json
{
  "id": "vitals",
  "barMetric": "memory",
  "cpuCoreViewMode": "bar",
  "gpuGraphEnabled": true,
  "moduleGraphEnabled": {
    "cpu": true,
    "memory": true,
    "network": true,
    "disk": true
  },
  "moduleGridHeight": 300,
  "processListHeight": 255,
  "pollIntervalMs": 3000,
  "backgroundPollIntervalMs": 5000
}
```

**Options:**
- `barMetric`: `cpu`, `memory`, `gpu`, `storage`, `disk`, or `network`
- `cpuCoreViewMode`: `bar`, `fill`, or `spark` (bars, vertical fill, or mini graph)
- `gpuGraphEnabled`: Show/hide GPU graph
- `pollIntervalMs`: 500–15000 ms (default 3000). Lower values update more frequently.
- `backgroundPollIntervalMs`: Optional. Slows Intel GPU sampling while dashboard is closed.

## Controls

| Context | Action | Result |
| :--- | :--- | :--- |
| **Bar** | Hover | Tooltip with pinned metric stats |
| **Dashboard** | Left-click bar | Open/close dashboard |
| | Middle-click bar | Refresh tiles (when open) or bar metric (when closed) |
| | Click **−** or **+** | Slow down or speed up polling |
| | Click **↻** | Refresh tiles now |
| **Metrics** | Left-click tile | Expand/collapse details |
| | Middle-click tile | Pin metric to top bar |
| | Right-click tile | Toggle sparkline graph (CPU, memory, network, disk, GPU) |
| | Right-click CPU core | Cycle core view: bars → fill → graph |
| | Click **GPU:** (multi-GPU) | Switch monitored GPU |
| **Process list** | Click search field | Focus search (filters as you type) |
| | Click **All**, **User**, or **System** | Filter process type |
| | Left-click column header | Sort by column (RSS by default) |
| | Right-click Memory column | Switch between RSS and PSS |
| | Left-click process row | Show full command details |
| | Right-click process row | Toggle process tree |
| | Click **clear** icon | Clear search query |
| | Click floating **↑** or **↓** | Jump to first/last process |
| | Click **Terminate** or **Kill** | Send SIGTERM or SIGKILL |
| **Layout** | Drag section divider | Resize metric grid and process list |
| | Middle-click divider | Restore default layout |

## Persisted settings

These are saved in `~/.config/omarchy/shell.json`:

| Setting | Persisted |
| :--- | :--- |
| Pinned bar metric | Yes |
| Module/process splitter size | Yes |
| Poll interval | Yes |
| Graph toggles | Yes |
| CPU core view mode | Yes |
| Primary network interface | Yes |
| Expanded modules, process filter, sort | No (session only) |

## Updating and removing

```bash
omarchy plugin update vitals
omarchy plugin disable vitals
omarchy plugin enable vitals
omarchy plugin remove vitals --yes
```

Disabling removes Vitals from the bar while keeping files and settings. Enabling again restores it.

## License

This project is licensed under the [MIT License](LICENSE).
