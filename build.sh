#!/usr/bin/env bash
set -euo pipefail
cd -- "$(dirname -- "$0")"

version=${2:-1.3.0-1}
arch=${1:-x86_64}
format=${3:-ipk}
name=luci-app-speedtest
description='Live multi-source WAN speed testing in LuCI, with bundled Better-Speedtest.'
dependencies=(libc luci-lua-runtime flock ca-bundle)
config_path=/etc/luci-speedtest/config.json

list_architectures() {
  # OpenWrt 25.12 no longer publishes a package feed for mips_4kec.
  awk -v format="$1" '!/^#/ {
    for (i = 3; i <= NF; i++) if (format != "apk" || $i != "mips_4kec") print $i
  }' architectures.tsv
}

validate_format() {
  if [[ $1 != ipk && $1 != apk ]]; then
    printf 'Unsupported package format: %s (expected ipk or apk)\n' "$1" >&2
    exit 2
  fi
}

if [[ $arch == --list ]]; then
  validate_format "${2:-ipk}"
  list_architectures "${2:-ipk}"
  exit 0
fi
validate_format "$format"
if [[ ! $version =~ ^[0-9]+\.[0-9]+\.[0-9]+-[1-9][0-9]*$ ]]; then
  printf 'Invalid package version: %s\n' "$version" >&2
  exit 2
fi
if [[ $arch == all ]]; then
  architectures=$(list_architectures "$format")
  for target in $architectures; do
    bash ./build.sh "$target" "$version" "$format"
  done
  exit 0
fi
if ! read -r engine engine_sha < <(awk -v arch="$arch" '
  !/^#/ { for (i = 3; i <= NF; i++) if ($i == arch) { print $1, $2; exit } }
' architectures.tsv); then
  printf 'Unsupported architecture: %s. Run bash build.sh --list for the supported values.\n' "$arch" >&2
  exit 2
fi
if ! grep -Fxq "$arch" < <(list_architectures "$format"); then
  printf 'Architecture %s is not supported for %s.\n' "$arch" "$format" >&2
  exit 2
fi
if [[ $format == apk && ( $EUID != 0 || $(uname -m) != x86_64 ) ]]; then
  printf 'Build APK packages as root on x86-64 Linux to set root ownership in the archive.\n' >&2
  exit 2
fi
asset="better-speedtest-linux-$engine"
engine_url="https://github.com/Gaimoydev/better-speedtest/releases/download/v0.0.3/$asset"
epoch=${SOURCE_DATE_EPOCH:-1783089639}
umask 022
stage=$(mktemp -d)
trap 'rm -rf -- "$stage"' EXIT

mkdir -p .build-cache dist "$stage/control" "$stage/data" "$stage/archive"
if [[ ! -f .build-cache/$asset ]]; then
  curl --fail --location --show-error --silent --retry 2 "$engine_url" -o "$stage/$asset"
  printf '%s  %s\n' "$engine_sha" "$stage/$asset" | sha256sum -c -
  install -m 0644 "$stage/$asset" ".build-cache/$asset"
fi
printf '%s  %s\n' "$engine_sha" ".build-cache/$asset" | sha256sum -c -

sh -n src/runner
install -D -m 0644 src/index.htm "$stage/data/usr/lib/lua/luci/view/speedtest/index.htm"
install -D -m 0644 src/controller.lua "$stage/data/usr/lib/lua/luci/controller/speedtest.lua"
install -D -m 0644 src/config.json "$stage/data$config_path"
install -D -m 0755 src/runner "$stage/data/usr/libexec/luci-speedtest/runner"
install -D -m 0755 ".build-cache/$asset" "$stage/data/usr/libexec/luci-speedtest/better-speedtest"
for license in LICENSE licenses/*; do
  install -D -m 0644 "$license" "$stage/data/usr/share/luci-speedtest/licenses/$(basename "$license")"
done

cat > "$stage/clear-luci-cache" <<'EOF'
#!/bin/sh
[ -n "${IPKG_INSTROOT:-}${PKG_INSTROOT:-}" ] && exit 0
rm -f /tmp/luci-indexcache /tmp/luci-indexcache.* /tmp/luci-modulecache/* 2>/dev/null || true
EOF

build_ipk() {
  package="${name}_${version}_${arch}.ipk"
  local installed_size depends
  local tar_flags=(--format=gnu --sort=name --mtime="@$epoch" --numeric-owner --owner=0 --group=0)
  installed_size=$(find "$stage/data" -type f -printf '%s\n' | awk '{ sum += $1 } END { print sum }')
  depends=$(printf '%s, ' "${dependencies[@]}")
  cat > "$stage/control/control" <<EOF
Package: $name
Version: $version
Architecture: $arch
Depends: ${depends%, }
Installed-Size: $installed_size
Section: luci
Priority: optional
License: MIT
Description: $description
EOF
  printf '%s\n' "$config_path" > "$stage/control/conffiles"
  install -m 0755 "$stage/clear-luci-cache" "$stage/control/postinst"
  install -m 0755 "$stage/clear-luci-cache" "$stage/control/postrm"
  tar "${tar_flags[@]}" -C "$stage/data" -cf - . | gzip -n > "$stage/archive/data.tar.gz"
  tar "${tar_flags[@]}" -C "$stage/control" -cf - . | gzip -n > "$stage/archive/control.tar.gz"
  printf '2.0\n' > "$stage/archive/debian-binary"
  tar "${tar_flags[@]}" -C "$stage/archive" -cf - ./debian-binary ./data.tar.gz ./control.tar.gz |
    gzip -n > "$stage/$package"
}

build_apk() {
  local apk_version="${version%-*}-r${version##*-}"
  local tool_package=apk-tools-static-3.0.9-r0.apk
  local tool_sha=ea77b2533566e70c9566c03748199b79348010c3199ba02d97e0634cf0fa9ef7
  local tool="$stage/sbin/apk.static"
  local metadata="$stage/data/lib/apk/packages/$name"
  package="${name}-${apk_version}_${arch}.apk"
  if [[ ! -f .build-cache/$tool_package ]]; then
    curl --fail --location --show-error --silent --retry 2 \
      "https://dl-cdn.alpinelinux.org/alpine/v3.23/main/x86_64/$tool_package" -o "$stage/$tool_package"
    printf '%s  %s\n' "$tool_sha" "$stage/$tool_package" | sha256sum -c -
    install -m 0644 "$stage/$tool_package" ".build-cache/$tool_package"
  fi
  printf '%s  %s\n' "$tool_sha" ".build-cache/$tool_package" | sha256sum -c -
  tar --ignore-zeros --no-same-owner --warning=no-unknown-keyword \
    -xzf ".build-cache/$tool_package" -C "$stage" sbin/apk.static
  mkdir -p "$(dirname "$metadata")"
  (cd "$stage/data" && find . -type f -printf '/%P\n' | LC_ALL=C sort) > "$stage/files.list"
  install -m 0644 "$stage/files.list" "$metadata.list"
  printf '%s\n' "$config_path" > "$metadata.conffiles"
  printf '%s %s\n' "$config_path" "$(sha256sum "$stage/data$config_path" | cut -d ' ' -f1)" > "$metadata.conffiles_static"
  find "$stage/data" -exec touch -h -d "@$epoch" {} +
  "$tool" mkpkg --compression deflate \
    --info "name:$name" --info "version:$apk_version" --info "arch:$arch" \
    --info "description:$description" --info "origin:$name" --info 'license:MIT' \
    --info 'url:https://github.com/yxc0915/luci-app-better-speedtest' \
    --info "depends:${dependencies[*]}" \
    --script "post-install:$stage/clear-luci-cache" --script "post-upgrade:$stage/clear-luci-cache" \
    --script "post-deinstall:$stage/clear-luci-cache" --files "$stage/data" --output "$stage/$package"
  "$tool" --allow-untrusted verify "$stage/$package"
}

if [[ $format == ipk ]]; then
  build_ipk
else
  build_apk
fi
cp "$stage/$package" "dist/$package"
(cd dist && sha256sum "$package" > "$package.sha256" && sha256sum -c "$package.sha256")
