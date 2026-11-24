# LuCI Better-Speedtest

在 **网络 → 网络测速** 查看实时仪表盘、下载与上传曲线、延迟和抖动。测速源常驻底部，可选自动择优、全球网测、Ookla、CDN 和中科大测速官网。中科大会在浏览器中打开官网，其余来源由路由器发起测速。测速核心按需启动。

## 安装

发布包适用于使用 opkg 的 OpenWrt 24.10，x86‑64 版也适用于 iStoreOS 24.10。可以运行 `opkg print-architecture`，按设备列出的架构选择包。

| 架构 | 常见设备 |
| --- | --- |
| `x86_64` | Intel / AMD 64 位软路由 |
| `mips_24kc` | 大端 MIPS，例如部分 ath79 设备 |
| `mipsel_24kc` | 小端 MIPS，例如 ramips/mt7621 设备 |

每个 `.ipk` 都包含对应架构的 Better-Speedtest 核心，系统依赖由 opkg 安装。使用 iStore 的「手动安装」，或在 LuCI 的「系统 → 软件包」中上传安装。安装后刷新 LuCI，进入「网络 → 网络测速」。

[在 Releases 下载 `.ipk` 和 SHA-256 校验文件](https://github.com/yxc0915/luci-app-better-speedtest/releases/latest)

## 构建

在 Linux 或 WSL 上运行以下命令，需要 Bash、curl 和 GNU coreutils、tar、gzip。构建脚本会下载 Better-Speedtest v0.0.3 对应架构的核心并核对 SHA-256。产物在 `dist/`。

```sh
bash build.sh x86_64
bash build.sh mips_24kc
bash build.sh mipsel_24kc
```

## 许可

界面和测速核心基于 [Gaimoydev/better-speedtest](https://github.com/Gaimoydev/better-speedtest)，按 MIT 许可发布。核心及其依赖的许可证随安装包提供，见 [LICENSE](LICENSE) 和 [licenses](licenses/)。
