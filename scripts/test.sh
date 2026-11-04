#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
source scripts/toolchain.sh
mkdir -p .build/parser-tests
swiftc "${SWIFT_FLAGS[@]}" -parse-as-library -emit-module -emit-object -module-name PowerCore Sources/PowerCore/PowerReading.swift -o .build/parser-tests/PowerCore.o -emit-module-path .build/parser-tests/PowerCore.swiftmodule
swiftc "${SWIFT_FLAGS[@]}" -I .build/parser-tests scripts/test-parser.swift .build/parser-tests/PowerCore.o -o .build/parser-tests/test-parser
.build/parser-tests/test-parser
