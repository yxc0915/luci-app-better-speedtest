#!/usr/bin/env bash
set -euo pipefail
cd -- "$(dirname -- "$0")"

version=${2:-1.2.0-1}
arch=${1:-x86_64}

list_architectures() {
  awk '!/^#/ { for (i = 3; i <= NF; i++) print $i }' architectures.tsv
}

if [[ $arch == --list ]]; then
  list_architectures
  exit 0
fi
if [[ ! $version =~ ^[0-9]+\.[0-9]+\.[0-9]+-[1-9][0-9]*$ ]]; then
  printf 'Invalid package version: %s\n' "$version" >&2
  exit 2
fi
if [[ $arch == all ]]; then
  architectures=$(list_architectures)
  for target in $architectures; do
    bash ./build.sh "$target" "$version"
  done
  exit 0
fi
if ! read -r engine engine_sha < <(awk -v arch="$arch" '
  !/^#/ { for (i = 3; i <= NF; i++) if ($i == arch) { print $1, $2; exit } }
' architectures.tsv); then
  printf 'Unsupported architecture: %s. Run bash build.sh --list for the supported values.\n' "$arch" >&2
  exit 2
fi
asset="better-speedtest-linux-$engine"
engine_url="https://github.com/Gaimoydev/better-speedtest/releases/download/v0.0.3/$asset"
package="luci-app-speedtest_${version}_${arch}.ipk"
epoch=${SOURCE_DATE_EPOCH:-1783089639}
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
install -D -m 0644 src/config.json "$stage/data/etc/luci-speedtest/config.json"
install -D -m 0755 src/runner "$stage/data/usr/libexec/luci-speedtest/runner"
install -D -m 0755 ".build-cache/$asset" "$stage/data/usr/libexec/luci-speedtest/better-speedtest"
for license in LICENSE licenses/*; do
  install -D -m 0644 "$license" "$stage/data/usr/share/luci-speedtest/licenses/$(basename "$license")"
done

cat > "$stage/control/control" <<EOF
Package: luci-app-speedtest
Version: $version
Architecture: $arch
Depends: libc, luci-lua-runtime, flock, ca-bundle
Installed-Size: $(find "$stage/data" -type f -printf '%s\n' | awk '{ sum += $1 } END { print sum }')
Section: luci
Priority: optional
License: MIT
Description: Live multi-source WAN speed testing in LuCI, with bundled Better-Speedtest.
EOF
printf '%s\n' /etc/luci-speedtest/config.json > "$stage/control/conffiles"
cat > "$stage/control/postinst" <<'EOF'
#!/bin/sh
[ -n "${IPKG_INSTROOT:-}" ] && exit 0
rm -f /tmp/luci-indexcache /tmp/luci-indexcache.* /tmp/luci-modulecache/* 2>/dev/null || true
EOF
chmod 0755 "$stage/control/postinst"
cp -p "$stage/control/postinst" "$stage/control/postrm"

tar_flags=(--format=gnu --sort=name --mtime="@$epoch" --numeric-owner --owner=0 --group=0)
tar "${tar_flags[@]}" -C "$stage/data" -cf - . | gzip -n > "$stage/archive/data.tar.gz"
tar "${tar_flags[@]}" -C "$stage/control" -cf - . | gzip -n > "$stage/archive/control.tar.gz"
printf '2.0\n' > "$stage/archive/debian-binary"
tar "${tar_flags[@]}" -C "$stage/archive" -cf - ./debian-binary ./data.tar.gz ./control.tar.gz |
  gzip -n > "$stage/$package"
cp "$stage/$package" "dist/$package"
(cd dist && sha256sum "$package" > "$package.sha256" && sha256sum -c "$package.sha256")
