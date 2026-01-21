#!/bin/bash
echo "=== Checking Pod Dependencies ==="

# Find all Swift files
find . -name "*.swift" -type f | while read file; do
    echo "=== $file ==="
    grep -E "import (?!Foundation|UIKit|CoreNFC|AVFoundation|CoreGraphics|CoreImage|SystemConfiguration|Security|LocalAuthentication)" "$file" || true
done | grep "import " | sort | uniq

echo "=== Podfile.lock Dependencies ==="
grep "  - " Podfile.lock | sort
