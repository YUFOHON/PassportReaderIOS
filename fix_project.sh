#!/bin/bash
echo "🧹 Removing CocoaPods from project.pbxproj..."

PROJECT_FILE="PassportReader.xcodeproj/project.pbxproj"
BACKUP_FILE="$PROJECT_FILE.backup_$(date +%s)"

# Backup
cp "$PROJECT_FILE" "$BACKUP_FILE"

# Remove Pods build phases and references
sed -i '' '/PODS_ROOT/d' "$PROJECT_FILE"
sed -i '' '/Pods_/d' "$PROJECT_FILE"
sed -i '' '/\[CP\]/d' "$PROJECT_FILE"
sed -i '' '/XCBBuildConfiguration/d' "$PROJECT_FILE" 2>/dev/null || true

echo "✅ Project cleaned. Backup at: $BACKUP_FILE"
