# LuCI Better-Speedtest

在 **网络 → 网络测速** 查看实时仪表盘、下载与上传曲线、延迟和抖动。测速源常驻底部，可选自动择优、全球网测、Ookla、CDN 和中科大测速官网。中科大会在浏览器中打开官网，其余来源由路由器发起测速。测速核心按需启动。

## 安装

发布包适用于使用 opkg 的 OpenWrt 24.10，x86‑64 版也适用于 iStoreOS 24.10。可以运行 `opkg print-architecture`，按设备列出的架构选择包。

| 处理器 | `.ipk` 架构后缀 |
| --- | --- |
| x86 | `x86_64`、`i386_pentium4` |
| ARM64 | `aarch64_generic`、`aarch64_cortex-a53`、`aarch64_cortex-a72`、`aarch64_cortex-a76` |
| ARMv7 | `arm_cortex-a5_vfpv4`、`arm_cortex-a7`、`arm_cortex-a7_neon-vfpv4`、`arm_cortex-a7_vfpv4`、`arm_cortex-a8_vfpv3`、`arm_cortex-a9`、`arm_cortex-a9_neon`、`arm_cortex-a9_vfpv3-d16`、`arm_cortex-a15_neon-vfpv4` |
| MIPS 大端 | `mips_24kc`、`mips_4kec`、`mips_mips32` |
| MIPS 小端 | `mipsel_24kc`、`mipsel_24kc_24kf`、`mipsel_74kc`、`mipsel_mips32` |

每个 `.ipk` 都包含对应架构的 Better-Speedtest 核心，系统依赖由 opkg 安装。使用 iStore 的「手动安装」，或在 LuCI 的「系统 → 软件包」中上传安装。安装后刷新 LuCI，进入「网络 → 网络测速」。

[在 Releases 下载 `.ipk` 和 SHA-256 校验文件](https://github.com/yxc0915/luci-app-better-speedtest/releases/latest)

## 构建

在 Linux 或 WSL 上运行以下命令，需要 Bash、curl、awk 和 GNU coreutils、findutils、tar、gzip。构建脚本会下载 Better-Speedtest v0.0.3 对应架构的核心并核对 SHA-256。产物在 `dist/`。

```sh
bash build.sh --list
bash build.sh aarch64_generic
bash build.sh all
```

[GitHub Actions](https://github.com/yxc0915/luci-app-better-speedtest/actions/workflows/build.yml) 会在向 `main` 推送、提交拉取请求或手动运行时构建所有安装包。推送 `vX.Y.Z` 标签后，会用该版本构建并将安装包和校验文件发布到 Releases。

## 许可

界面和测速核心基于 [Gaimoydev/better-speedtest](https://github.com/Gaimoydev/better-speedtest)，按 MIT 许可发布。核心及其依赖的许可证随安装包提供，见 [LICENSE](LICENSE) 和 [licenses](licenses/)。
