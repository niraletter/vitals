# Vitals

**Native system monitor for Omarchy.**

A compact metric lives in the top bar. Click it to open a dashboard with CPU, memory, swap, GPU, storage, network, and process information.

https://github.com/user-attachments/assets/336a9a92-6c77-48bd-9a6e-6aea534a7579

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

Intel device usage reads i915 performance counters through `intel_gpu_top`, similar to btop. On the **first dashboard open** with an Intel GPU, Vitals:

1. Installs `intel-gpu-tools` if missing (via `pkexec` + your package manager)
2. Grants `CAP_PERFMON` to `intel_gpu_top` with `setcap` (persists across reboot on the binary)

Once setup succeeds, it is not re-run on later opens. Approve the system authentication dialog when it appears. You may see one prompt to install and one to grant PMU access.

Manual setup if auto-setup fails or you prefer to do it yourself:

```bash
# Arch
sudo pacman -S --needed intel-gpu-tools
sudo setcap cap_perfmon=ep "$(command -v intel_gpu_top)"
```

If the GPU tile shows **PMU access needed**, `cap_perfmon` is not granted — run the `setcap` command above or reopen the dashboard once to retry the setup prompt. After setup, the last GPU reading is kept when you close and reopen the dashboard.

Per-process Intel GPU stats use DRM fdinfo (shared memory and per-app engine time).

## Installation

### Install from GitHub

Replace `USERNAME` with the GitHub account that hosts this repository:

```bash
omarchy plugin add https://github.com/niraletter/vitals.git --enable
```

Omarchy asks where to place the widget and selects the right bar section by default. This comes from Vitals' manifest, so no `--section right` argument is needed for a normal install.

For a noninteractive install:

```bash
omarchy plugin add https://github.com/niraletter/vitals.git --enable --yes
```

The plugin is installed as:

```text
~/.config/omarchy/plugins/vitals
```

### Install from a local checkout

Copy the repository into the user plugin directory:

```bash
mkdir -p ~/.config/omarchy/plugins
cp -r vitals ~/.config/omarchy/plugins/vitals
```

During development, copy changed files into the live plugin directory or use `omarchy dev link` if your Omarchy install supports it:

```bash
cp Panel.qml BarWidget.qml Model.js GpuLogic.js ProcessLogic.js MetricTiles.qml ProcessList.qml manifest.json \
  ~/.config/omarchy/plugins/vitals/
omarchy restart shell
```

| File | Role |
| :--- | :--- |
| `Panel.qml` | Shell panel, polling, parsers, bar snapshot |
| `BarWidget.qml` | Top-bar widget and tooltip bridge |
| `MetricTiles.qml` | Dashboard metric grid and expanded tile views |
| `ProcessList.qml` | Process list, search, sort, and tree UI |
| `GpuLogic.js` | GPU and network label helpers |
| `ProcessLogic.js` | Process refresh script and CPU % math |
| `Model.js` | Shared formatting helpers |
| `manifest.json` | Plugin metadata |

Use `omarchy dev link` while actively editing if you want the live plugin directory to point at your checkout.

The default dashboard height fits five process rows; drag the splitter to give the process list more room.

Then enable it:

```bash
omarchy plugin enable vitals
```

The manifest places it in the right bar section by default. Installation and enabling are separate so a plugin cannot change the bar without the user's approval.

If the bar does not update automatically, restart the shell:

```bash
omarchy restart shell
```

## Configuration

The widget can be configured in `~/.config/omarchy/shell.json`. Add or edit the `vitals` entry in the bar layout:

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

Available bar metrics are `cpu`, `memory`, `gpu`, `storage`, `disk`, and `network`. Per-core view mode is `bar`, `fill`, or `spark` (bars, vertical fill, or mini graph). Set `gpuGraphEnabled` or individual keys in `moduleGraphEnabled` to `false` to hide sparkline graphs. The dashboard also saves graph visibility and layout changes made through its controls.

`pollIntervalMs` accepts values from 500 to 15000 milliseconds (default 3000). Lower values update more frequently and use more CPU. This interval drives the pinned bar value, dashboard refresh when open, and most metric polling.

`backgroundPollIntervalMs` is optional. When set, it slows Intel GPU `intel_gpu_top` sampling while the dashboard is closed (defaults to `pollIntervalMs` when unset or zero).

## Controls

Quick reference for mouse and UI actions in the dashboard.

| | Do this | What happens |
| :--- | :--- | :--- |
| **Bar** | Hover the bar widget | Shows a tooltip with stats for the pinned metric (from the last poll; CPU shows per-core %) |
| **Dashboard** | Left-click the bar widget | Opens or closes the dashboard; does not change the bar value |
| | Middle-click the bar widget | Refreshes dashboard tiles when open; refreshes the pinned bar metric when closed |
| | Click **−** or **+** | Slows down or speeds up polling |
| | Click **↻** | Refreshes dashboard tiles now (bar value still follows the poll interval when open) |
| | Read **Updated Xs ago** (header) | Age of the last successful metric parse |
| **Metrics** | Left-click a metric tile | Expands or collapses details (CPU shows per-core load and temperature) |
| | Middle-click a metric tile | Pins that metric to the top bar |
| | Right-click CPU, memory, network, disk, or GPU tile | Toggles the module sparkline graph on or off |
| | Right-click a CPU core tile | Cycles core view: bars → fill → graph |
| | Click **GPU:** (when multiple GPUs) | Switches the monitored GPU |
| **Process list** | Click the search field | Focuses search (filters as you type) |
| | Click **All**, **User**, or **System** | Shows all, your, or system processes |
| | Left-click a column header | Sorts by that column (RSS by default) |
| | Right-click the Memory column | Switches between RSS and PSS |
| | Left-click a process row | Shows full command details |
| | Right-click a process row | Toggles the process tree under that row |
| | Click the **clear** icon in search | Clears the current search query |
| | Click the floating **↑** or **↓** button | Jumps to the first or last process |
| | Click **Terminate** or **Kill** | Sends SIGTERM or SIGKILL |
| **Layout** | Left-click and drag the section divider | Resizes the metric grid and process list |
| | Middle-click the divider | Restores the default layout |

## Persisted settings

These are saved in `~/.config/omarchy/shell.json` and survive reboot:

| Setting | Saved |
| :--- | :--- |
| Pinned bar metric | Yes |
| Module/process splitter size | Yes |
| Poll interval | Yes |
| Graph toggles | Yes |
| CPU core view mode | Yes |
| Primary network interface | Yes |
| Expanded modules, process filter, sort | No (session only) |

## Validate before publishing

From the repository root, run:

```bash
omarchy plugin validate .
```

The manifest must keep the plugin ID `vitals`. Plugin IDs in the reserved `omarchy.*` namespace are not allowed for third-party plugins.

## Updating and removing

```bash
omarchy plugin update vitals
omarchy plugin disable vitals
omarchy plugin enable vitals
omarchy plugin remove vitals --yes
```

Disabling removes Vitals from the bar while keeping its files and settings installed. Enabling it again restores the widget.

## License

This project is licensed under the [MIT License](LICENSE).
