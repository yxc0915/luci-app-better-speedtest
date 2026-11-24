# LuCI Better-Speedtest

在 **网络 → 网络测速** 查看实时仪表盘、下载与上传曲线、延迟和抖动。测速源常驻底部，可选自动择优、全球网测、Ookla、CDN 和中科大测速官网。中科大会在浏览器中打开官网，其余来源由路由器发起测速。测速核心按需启动。

## 安装

- OpenWrt 24.10（opkg）使用 `.ipk`，运行 `opkg print-architecture` 查看设备架构。
- OpenWrt 25.12（apk）使用 `.apk`，运行 `apk --print-arch` 查看设备架构。
- iStoreOS 对应版本使用相同的包格式，x86‑64 设备选择 `x86_64`。

| 处理器 | 安装包架构后缀 |
| --- | --- |
| x86 | `x86_64`、`i386_pentium4` |
| ARM64 | `aarch64_generic`、`aarch64_cortex-a53`、`aarch64_cortex-a72`、`aarch64_cortex-a76` |
| ARMv7 | `arm_cortex-a5_vfpv4`、`arm_cortex-a7`、`arm_cortex-a7_neon-vfpv4`、`arm_cortex-a7_vfpv4`、`arm_cortex-a8_vfpv3`、`arm_cortex-a9`、`arm_cortex-a9_neon`、`arm_cortex-a9_vfpv3-d16`、`arm_cortex-a15_neon-vfpv4` |
| MIPS 大端 | `mips_24kc`、`mips_4kec`（仅 `.ipk`）、`mips_mips32` |
| MIPS 小端 | `mipsel_24kc`、`mipsel_24kc_24kf`、`mipsel_74kc`、`mipsel_mips32` |

每个安装包都包含对应架构的 Better-Speedtest 核心，包管理器会解析系统依赖。可以使用 iStore 的「手动安装」，或在 LuCI 的「系统 → 软件包」中上传安装。安装后刷新 LuCI，进入「网络 → 网络测速」。

GitHub 发布的 `.apk` 未使用固件软件源的密钥签名。核对 SHA-256 后，若使用命令行手动安装，可运行 `apk add --allow-untrusted /tmp/安装包.apk`，该选项仅用于这次安装。

[在 Releases 下载安装包和 SHA-256 校验文件](https://github.com/yxc0915/luci-app-better-speedtest/releases/latest)

## 构建

在 Linux 或 WSL 上运行以下命令，需要 Bash、curl、awk 和 GNU coreutils、findutils、tar、gzip。构建脚本会下载 Better-Speedtest v0.0.3 对应架构的核心并核对 SHA-256。产物在 `dist/`。

```sh
bash build.sh --list
bash build.sh --list apk
bash build.sh aarch64_generic
bash build.sh all
sudo bash build.sh all 1.3.0-1 apk
```

APK 在 x86‑64 Linux 上以 root 构建，确保包内文件属主正确。构建脚本会从 Alpine 官方仓库获取并校验固定版本的 `apk-tools-static`。

[GitHub Actions](https://github.com/yxc0915/luci-app-better-speedtest/actions/workflows/build.yml) 会在向 `main` 推送、提交拉取请求或手动运行时构建两种格式。先将发布提交推送到 `main`，再单独推送 `vX.Y.Z` 标签，Actions 会用该版本构建并将安装包和校验文件发布到 Releases。

## 许可

界面和测速核心基于 [Gaimoydev/better-speedtest](https://github.com/Gaimoydev/better-speedtest)，按 MIT 许可发布。核心及其依赖的许可证随安装包提供，见 [LICENSE](LICENSE) 和 [licenses](licenses/)。
