# Shared compiler setup. Sourced by build.sh and test.sh.
SDK="${POWERMETER_SDK:-$(xcrun --show-sdk-path)}"
SWIFT_FLAGS=(-swift-version 5 -sdk "$SDK")
CLT_INCLUDE="$(xcode-select -p)/usr/include/swift"
if [[ -f "$CLT_INCLUDE/module.modulemap" && -f "$CLT_INCLUDE/bridging.modulemap" ]] && /usr/bin/grep -q 'module SwiftBridging' "$CLT_INCLUDE/module.modulemap"; then
  mkdir -p .build/toolchain
  : > .build/toolchain/empty.modulemap
  python3 - "$CLT_INCLUDE/module.modulemap" "$PWD/.build/toolchain/empty.modulemap" "$PWD/.build/toolchain/overlay.json" <<'PY'
import json, sys
with open(sys.argv[3], 'w') as output:
    json.dump({'version': 0, 'roots': [{'type': 'file', 'name': sys.argv[1], 'external-contents': sys.argv[2]}]}, output)
PY
  SWIFT_FLAGS+=(-vfsoverlay "$PWD/.build/toolchain/overlay.json")
  echo 'Using local overlay for duplicate SwiftBridging module map (system files unchanged).'
fi
