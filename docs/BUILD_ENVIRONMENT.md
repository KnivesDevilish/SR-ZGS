# SR-ZGS — Build Environment

| Field | Value |
|---|---|
| Document version | 2.2 (Phase 0 closure synchronization; public, privacy-reviewed version). Supersedes the reported-baseline-only version 1. |
| Date | 2026-10-30 |
| Status | Host and existing containers documented. Canonical build environment **approved (D2), not created**; image digest not selected. Nothing built. |

Evidence labels are defined in `PROJECT_OVERVIEW.md` §1. Every host and container value in this document is **UPE**: output the developer ran and supplied. No AI tool accessed the host or the containers directly.

**Privacy.** This is the public version. It omits personal and machine-specific identifiers: the operating-system username, home-directory path, exact CPU and GPU models, device and storage models, PCI device IDs, local device-node numbers, local container names, and local container image IDs and digests. Placeholders in angle brackets, such as `<user>` or `<toolbx-container>`, stand in where a path or command needs one. None of the omitted values is needed to reproduce the build environment; the capabilities that matter (architecture, x86-64 level, core and thread count, memory, storage type, graphics driver stack) are kept.

---

## 1. Purpose

This document records:
- The developer's originally reported hardware and OS baseline (§2).
- The host environment as shown by developer-supplied command output (UPE, §3).
- The existing containers and their suitability (§5–6).
- The approved (D2, 2026-10-30), **not yet created**, canonical build environment (§7).

It is not proof that any build or runtime works. No SR-ZGS build has been performed.

---

## 2. Originally reported baseline

Source: developer-provided KDE System Information screenshot. These values are kept as originally reported, with one correction.

| Component | Reported value |
|---|---|
| Device | Laptop (make and model omitted from the public document) |
| Operating system | Bazzite 44 Desktop Edition |
| Desktop environment | KDE Plasma 6.7.5 |
| KDE Frameworks | 6.30.0 |
| Qt | 6.11.2 |
| Kernel | `7.2.4-ogc3.1.fc44.x86_64` (**corrected**; see note) |
| System architecture | 64-bit; intended development target: Linux x86-64 |
| Display session | Wayland |
| Processor | Intel x86-64 laptop CPU (exact model omitted from the public document) |
| Logical processors shown by system information | 4 |
| Memory | 16 GiB installed; 15.5 GiB usable, as reported |
| Graphics processor | Intel integrated GPU (exact model omitted from the public document) |

**Kernel correction (2026-10-30).** Version 1 of this document recorded the kernel as `7.2.4-0gc3.1.fc44.x86_64`, which was a transcription error. The developer's `uname -r` output is `7.2.4-ogc3.1.fc44.x86_64` (UPE), and that value is authoritative.

No serial number or other device-specific identifier is required for this project. Do not request or record one.

---

## 3. Host environment from developer-supplied output (UPE, 2026-10-30)

### 3.1 Operating system and kernel

| Item | Value |
|---|---|
| Distribution | Bazzite 44 **Kinoite** (KDE), image version `44.20260915.0` |
| Kernel (`uname -r`) | `7.2.4-ogc3.1.fc44.x86_64` |
| Architecture | `x86_64` |

### 3.2 CPU

| Item | Value |
|---|---|
| Model | Intel x86-64 laptop CPU (exact model omitted from the public document) |
| Topology | 2 cores / 4 threads |
| x86-64 levels (dynamic linker) | x86-64-v2 and **x86-64-v3** supported |
| Notable flags | AVX2, FMA, BMI1, BMI2 |

### 3.3 Memory and storage

| Item | Value |
|---|---|
| RAM | 15 GiB total; 11 GiB available at inspection time |
| Swap | ZRAM, 7.8 GiB; about 35 MiB used. This is compressed RAM, not disk. |
| Disk | **Mechanical HDD** (`ROTA=1`), about 1 TB (model omitted from the public document) |
| Free space | Several hundred GB available in `/var/home` at inspection |
| Root filesystem | composefs. Its reported 100% usage is a property of the image-based root and does **not** mean the physical disk is full. |

### 3.4 Graphics

| Item | Value |
|---|---|
| GPU | Intel integrated GPU (exact model omitted from the public document) |
| Kernel driver | `i915` |
| Mesa | 26.2.2 |
| OpenGL | Direct rendering enabled, hardware-accelerated, OpenGL 4.6 |
| Vulkan ICD | `intel_hasvk_icd.x86_64.json` present |
| Vulkan devices | GPU0: **the Intel integrated GPU** (physical; Mesa Intel open-source driver; Vulkan API 1.3.354). GPU1: **llvmpipe** (software renderer). |
| Vulkan warnings | Warnings mention the DZN ICD and display extensions. These are most likely Mesa's Dozen (Vulkan-on-Direct3D 12) ICD failing to load outside WSL (TI). They do **not** show that Vulkan is broken, nor that it works for ModernGekko. |

### 3.5 Host development tools

| Present | Absent |
|---|---|
| GCC/G++ 16.2.1, GNU Make 4.4.1, Git 2.55.0, Python 3.14.7, pkg-config 2.5.1 | Clang, Clang++, LLVM, `llvm-config`, `llvm-config-20`, LLD, **CMake, Ninja, wayland-scanner** |

**Conclusion:** the host cannot build ModernGekko as it stands. CMake and Ninja are mandatory, and `wayland-scanner` becomes mandatory once `wayland-client` is detected (SC + UPE). It also lacks LLVM 19/20.

---

## 4. Reported vs observed differences

| Item | Reported (§2) | Observed (§3, UPE) |
|---|---|---|
| OS naming | "Bazzite 44 Desktop Edition" | Bazzite 44 Kinoite, image `44.20260915.0`. These are consistent descriptions; the image version is now recorded. |
| Kernel | Version 1 transcription `…-0gc3.1…` | `7.2.4-ogc3.1.fc44.x86_64` |
| Memory | 15.5 GiB usable | 15 GiB total (as `free -h` rounds), 11 GiB available at inspection |

---

## 5. Existing containers (UPE)

### 5.1 Existing Toolbx container (running)

| Item | Value |
|---|---|
| Image | `registry.fedoraproject.org/fedora-toolbox:latest` |
| Image ID and local digest | Recorded during the audit; omitted from the public document (local identifiers) |
| Image label `version` | 44 |
| Distribution inside | Fedora Linux 44 (Toolbx Container Image) |
| Security settings | `privileged=true`, `pid=host`, `ipc=host`, `net=host`, `devices=[]` |
| Read-write mounts | Host `/dev`; the user's entire home directory (`/var/home/<user>`); `/run/user/1000`; host `/` at `/run/host/` |
| Toolchain present | GCC/G++ 16.2.1, CMake 4.3.0, Ninja 1.13.2, Make 4.4.1, Git 2.56.0, Python 3.14.8, wayland-scanner 1.26.0 |
| Toolchain absent | Clang, Clang++, LLD, `llvm-config`, `llvm-config-19`, `llvm-config-20`, all LLVM 19/20 development packages |
| Development libraries present | Wayland, wayland-protocols, xkbcommon, X11/Xi/Xrandr, Mesa GL, EGL, ALSA, PulseAudio (`pkg-config` resolves them); Mesa Vulkan drivers; Vulkan loader |
| `pkg-config vulkan` | Not found: the loader's development package is absent. This does not mean Vulkan is absent at runtime (see next row). |
| Vulkan inside container | Enumerates the Intel integrated GPU (physical) and llvmpipe (software) |
| Container Mesa version | Not supplied (UNK) |

### 5.2 Previous-attempt container (stopped)

| Item | Value |
|---|---|
| Image | `registry.fedoraproject.org/fedora:latest` |
| Image ID and local digest | Recorded during the audit; omitted from the public document (local identifiers) |
| Image label `version` | 44 |
| State | Exited, code 143. Cause not inferred. |
| Policy | **Must not be started, reused or modified** without explicit developer approval. By its name it most likely belongs to a previous attempt (TI), and previous attempts must not become the foundation. |

### 5.3 Assessment

- **Floating tags.** Both images are tagged `:latest`, which is mutable. The local image IDs and digests that identify exactly the inspected images are kept out of this public document. Re-pulling `:latest` later may produce a different Fedora release, which is why the canonical environment must be pinned by digest (§7.1).
- **The existing Toolbx container is a full host-integration container:**
  - Privileged mode.
  - Host process, IPC and network namespaces.
  - Read-write access to host `/dev`, the entire home directory, the user's session runtime directory, and host `/`.
  - Because Podman runs rootless here (TI: it is invoked as the user), this grants the user's own permissions, not host root.
- **What the Toolbx-container evidence establishes** (UPE; details in §6):
  - The GPU's DRM device nodes (its render node and card node under `/dev/dri/`) are visible inside the container.
  - UID 1000 has read/write **filesystem permissions** on those DRM nodes.
  - The Wayland, PipeWire, PulseAudio and D-Bus sockets exist and have read/write filesystem permissions for UID 1000.
  - Vulkan enumerates the physical Intel integrated GPU and llvmpipe.
- **What it does NOT establish:**
  - Successful Wayland, PipeWire, PulseAudio or D-Bus connection handshakes.
  - ModernGekko window creation.
  - Actual OpenGL or Vulkan rendering.
  - Audio playback.
  - Which GPU ModernGekko will select.
- **Why the existing Toolbx container is unsuitable as the canonical, reproducible, least-privilege build environment:**
  1. **Hidden inputs.** Builds can absorb host state: dotfiles, caches in `$HOME`, environment leakage, visible host processes.
  2. **No manifest.** Packages accumulated over time are not recorded, and the `:latest` tag cannot recreate them.
  3. **Excessive access.** It has far more access than build tasks require.
  4. **Hard to audit.** Results would be difficult for others to reproduce or review.
- **What it is useful for:** a **reference** for what Fedora 44 toolbox provides, and for the device-visibility and permission evidence listed above. It is not the canonical environment, and that evidence is not proof of working graphics, audio or session integration.

---

## 6. Session and device access in the existing Toolbx container (UPE)

The developer checked access as UID 1000 with `podman exec --user 1000 <toolbx-container> …`. The container reported UID 1000 (`<user>`), GID 1000, groups 1000 and 65534.

| Resource | Result |
|---|---|
| `/run/user/1000/wayland-0` | Socket, read/write |
| `/run/user/1000/pipewire-0` | Socket, read/write |
| `/run/user/1000/pulse/native` | Socket, read/write |
| `/run/user/1000/bus` | Socket, read/write |
| `/dev/dri/renderD<N>` (GPU render node) | Character device, read/write |
| `/dev/dri/card<N>` (GPU card node) | Character device, read/write |

The directory listing shows the Wayland, PipeWire and D-Bus sockets owned by UID/GID 1000.

**What this establishes:** the sockets and devices exist and have read/write **file permissions** for UID 1000 inside this container.

**What remains NOT TESTED:**
- Actual connection handshakes (Wayland, PipeWire, PulseAudio, D-Bus).
- Window creation.
- Vulkan or OpenGL rendering by ModernGekko.
- Choosing the Intel GPU over llvmpipe.
- Audio playback and controller input.

A previous check run as container UID 0 inspected `/run/user/0`, not `/run/user/1000`. It was superseded by the UID 1000 check above.

---

## 7. Canonical build environment (D2)

**Status: APPROVED (2026-10-30), NOT CREATED.** The base-image digest has not been selected. The developer's two existing containers (§5) are left untouched.

### 7.1 Base image

- A Fedora 44 image, matching the host's Fedora 44 base so that host-run binaries are likely compatible (TI).
- Pinned **by digest**. Candidates include the already-pulled Fedora 44 images in §5. **No digest has been selected yet.**
- Once selected, the approved immutable digest is recorded here. The digest and a full `rpm -qa` package list must be recorded after provisioning.

### 7.2 Packages

These are **candidate** Fedora names, to be confirmed with `rpm`/`dnf` during Phase 1:

- `gcc`, `gcc-c++`, `cmake`, `ninja-build`, `make`, `git`, `python3`, `pkgconf`
- **`llvm20-devel`**: 20.1.8 is listed in Fedora 44's package database; installation and suitability are NOT TESTED
- `wayland-devel`, `wayland-protocols-devel`, `libxkbcommon-devel`
- `libX11-devel`, `libXi-devel`, `libXrandr-devel`
- `mesa-libGL-devel` / `libglvnd-devel`
- `alsa-lib-devel`, `pulseaudio-libs-devel`

Whether `llvm20-static` is also needed depends on how Fedora's `llvm20-devel` exposes LLVM (UNK).

### 7.3 Mounts and permissions

- Mount only the SR-ZGS project directory, plus an optional cache directory.
- No privileged mode; no host PID or IPC namespaces; no host `/`; no full `$HOME`.
- Files owned by the developer's UID.
- Network access as required for dependency fetching (exact policy to be decided).
- Whether Distrobox 1.8.2.5 or Toolbox 0.3 can be configured this restrictively is UNK. Plain Podman gives the most control. The tool choice belongs to the developer.

### 7.4 Runtime-test environment (later, Phase 4)

Graphics and audio tests need session sockets and the render node, which a build container does not. Options to decide later:
- **(a)** Run the built binaries on the host with Bazzite's Mesa 26.2.2.
- **(b)** A separate test container granted only the GPU's DRM render node (`/dev/dri/renderD<N>`) and the Wayland and PipeWire/PulseAudio sockets.

---

## 8. Constraints and guidance

- **Parallelism.**
  - Start the ModernGekko/Dolphin build at **2 jobs**, measure peak memory, then adjust.
  - `moderngekko-port` runs `dolrecomp` and the module build with the full hardware thread count (4) and offers no flag to change that (SC). Measure before mitigating.
- **Memory.** 11 GiB were available at inspection. ZRAM swap consumes CPU and RAM under pressure.
- **HDD.** Expect slow submodule checkouts, slow C++ builds and linking of thousands of chunk objects, and a per-run hash of the whole game `files/` tree (TI). Measure these in Phases 1, 3 and 6.
- **Graphics.**
  - Vulkan enumerates the physical Intel GPU and llvmpipe (UPE), but ModernGekko rendering is **NOT TESTED**.
  - The runner defaults to Vulkan on Linux; OpenGL can be selected with `--graphics`.
  - Confirm the selected GPU is the Intel GPU, not llvmpipe.
- **60 FPS** is a goal to be measured, not an assumed capability.
- **Host system.** No host changes, package layering or driver changes without explanation and developer approval.

---

## 9. Still unverified

- Any build of DolRecomp, ModernGekko or RecompCore, with any toolchain.
- LLVM 20 installation and Fedora's LLVM linking mode.
- Compatibility of GCC 16.2.1, CMake 4.3.0 and Python 3.14.x with the pinned upstream revisions.
- Mesa version and the `hasvk` ICD inside any future container.
- All runtime behavior in §6 marked NOT TESTED.

---

## 10. Read-only inspection commands used in Phase 0

These are diagnostic only. Do not install, remove, update or reconfigure anything while running them. If a utility is unavailable, record it as unavailable.

Their output can include personal or machine-specific identifiers (usernames, home paths, device models, image IDs). Record only the values the build needs, and keep the rest out of public documents.

### 10.1 Host

```bash
# Operating system and deployment information
cat /etc/os-release
rpm-ostree status

# Kernel and host architecture
uname -a
uname -r
uname -m

# CPU model, topology, flags; supported x86-64 levels
lscpu
/lib64/ld-linux-x86-64.so.2 --help | grep -E 'x86-64-v[234]'

# Memory, swap, storage, disk type
free -h
df -h / "$HOME"
lsblk -d -o NAME,ROTA,SIZE,MODEL

# GPU and bound kernel driver; installed Vulkan ICDs
lspci -nnk | grep -A4 -E 'VGA compatible controller|3D controller|Display controller'
ls /usr/share/vulkan/icd.d/

# Graphics utilities, if already installed
command -v vulkaninfo && vulkaninfo --summary
command -v glxinfo && glxinfo -B

# Toolchain and container tooling availability
for t in distrobox toolbox podman gcc g++ clang clang++ llvm-config llvm-config-20 lld cmake ninja make git python3 pkg-config wayland-scanner; do
  printf '%-16s ' "$t"
  command -v "$t" >/dev/null && { command -v "$t"; "$t" --version 2>&1 | head -1; } || echo "not found"
done
```

Placeholders in angle brackets (`<previous-attempt-container>`, `<toolbx-container>`, `<N>`) stand for local container names and device-node numbers, which are omitted from this public document. Replace them with the local values before running a command.

### 10.2 Existing containers (metadata only; the previous-attempt container is never started)

```bash
podman container inspect <previous-attempt-container> <toolbx-container> --format '{{.Name}} | image={{.ImageName}} | id={{.Image}} | state={{.State.Status}} exit={{.State.ExitCode}} | created={{.Created}}'
for c in <previous-attempt-container> <toolbx-container>; do
  img=$(podman container inspect "$c" --format '{{.Image}}')
  podman image inspect "$img" --format "$c: digest={{.Digest}} created={{.Created}} labels={{.Labels}}"
done
podman container inspect <toolbx-container> --format 'privileged={{.HostConfig.Privileged}} pid={{.HostConfig.PidMode}} ipc={{.HostConfig.IpcMode}} net={{.HostConfig.NetworkMode}} devices={{.HostConfig.Devices}}'
podman container inspect <toolbx-container> --format '{{range .Mounts}}{{.Source}} -> {{.Destination}} ({{.Type}}, rw={{.RW}}){{"\n"}}{{end}}'
```

### 10.3 Session and device access as UID 1000 (inside the running Toolbx container)

```bash
podman exec --user 1000 <toolbx-container> sh -c 'id; for s in /run/user/1000/wayland-0 /run/user/1000/pipewire-0 /run/user/1000/pulse/native /run/user/1000/bus /dev/dri/renderD<N> /dev/dri/card<N>; do printf "%-30s " "$s"; if [ -e "$s" ]; then printf "exists "; [ -S "$s" ] && printf "socket "; [ -c "$s" ] && printf "chardev "; [ -r "$s" ] && printf "r" || printf "-"; [ -w "$s" ] && echo "w" || echo "-"; else echo "absent"; fi; done; ls -ln /run/user/1000/ | grep -E "wayland|pipewire|pulse|bus"'
```

Each `podman exec` creates a short-lived exec session in Podman's runtime state. It changes no container files or configuration.

---

## 11. Instructions for SR-ZGS development

1. Keep reported values (§2) and developer-supplied observed values (§3–6, UPE) separate. Correct reported values only with evidence, and note the correction.
2. Verify LLVM and DolRecomp compatibility before selecting compiler versions or build flags.
3. Verify ModernGekko's actual graphics, audio and input requirements before choosing system dependencies.
4. Do not treat Vulkan enumeration or socket permissions as proof that ModernGekko renders or plays audio.
5. Do not use aggressive build parallelism by default. Select job counts from measured memory use.
6. Do not use the existing Toolbx container as the canonical build environment, and do not start or reuse the previous-attempt container.
7. Do not change the host system, install packages, create containers or modify drivers without explaining the need and obtaining the developer's approval.
8. Re-verify the environment inside the canonical build container once it exists, and record that evidence here.

---

## 12. Status

| Item | Status |
|---|---|
| Reported baseline | Recorded; kernel corrected |
| Host environment | Documented from developer-supplied output (UPE) |
| Existing containers | Documented (UPE); not suitable as the canonical environment |
| Canonical build environment | **NOT CREATED**; D2 approved 2026-10-30; image digest not selected |
| LLVM 19/20 | **Not installed anywhere** (blocker) |
| Any build or runtime test | **NOT TESTED** |

**Sources:** the developer-provided system-information screenshot (§2); developer-supplied terminal output, 2026-10-30 (§3–6).
