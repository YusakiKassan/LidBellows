#!/bin/sh
# Runs the unit tests. With only Command Line Tools installed (no Xcode), SwiftPM does not
# find Testing.framework on its own, so point it there.
set -e
cd "$(dirname "$0")"
CLT=/Library/Developer/CommandLineTools/Library/Developer
if [ -d "$CLT/Frameworks/Testing.framework" ] && ! xcode-select -p | grep -q Xcode.app; then
    exec swift test -Xswiftc -F -Xswiftc "$CLT/Frameworks" \
        -Xlinker -F -Xlinker "$CLT/Frameworks" \
        -Xlinker -rpath -Xlinker "$CLT/Frameworks" -Xlinker -rpath -Xlinker "$CLT/usr/lib" "$@"
fi
exec swift test "$@"
