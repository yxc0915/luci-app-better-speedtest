#!/usr/bin/env bash
set -euo pipefail
cd -- "$(dirname -- "$0")"

version=1.1.1-1
arch=${1:-x86_64}
case "$arch" in
  x86_64)
    asset=better-speedtest-linux-amd64
    engine_sha=d035456877a545a8dc47d5bb5c9420531806a98c83c1f0c55b3fc2397529b532
    ;;
  mips_24kc)
    asset=better-speedtest-linux-mips
    engine_sha=6eb81b250207e81d2c6889e43c129bd8c220a7f722158faf013be277400e44ba
    ;;
  mipsel_24kc)
    asset=better-speedtest-linux-mipsle
    engine_sha=462ba637cf7512d6dc7f7de3627567f45d5b8312d265764e3b470def5a44f1b1
    ;;
  *)
    printf 'Usage: %s [x86_64|mips_24kc|mipsel_24kc]\n' "$0" >&2
    exit 2
    ;;
esac
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
Installed-Size: $(du -sb "$stage/data" | cut -f1)
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
