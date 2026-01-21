#!/usr/bin/env python3
"""
Framework Conversion Helper
Interactive tool to guide framework conversion
"""

import json
import os
import sys
import shutil
from pathlib import Path
import argparse

class ConversionHelper:
    def __init__(self, project_path: str):
        self.project_path = Path(project_path)
        self.report_file = self.project_path / "project_analysis_report.json"
        
        if not self.report_file.exists():
            print("❌ No analysis report found. Run analyzer first.")
            print("   python3 analyze_project.py <project_path>")
            sys.exit(1)
            
        with open(self.report_file, 'r') as f:
            self.report = json.load(f)
    
    def interactive_mode(self):
        """Interactive conversion guidance"""
        print("\n" + "="*60)
        print("🛠️  FRAMEWORK CONVERSION HELPER")
        print("="*60)
        
        while True:
            print("\nWhat would you like to do?")
            print("1. View framework candidates")
            print("2. Generate framework structure")
            print("3. Create migration checklist")
            print("4. Generate Swift Package Manager manifest")
            print("5. Generate Xcode build scripts")
            print("6. Exit")
            
            choice = input("\nEnter choice (1-6): ").strip()
            
            if choice == "1":
                self.show_framework_candidates()
            elif choice == "2":
                self.generate_framework_structure()
            elif choice == "3":
                self.generate_migration_checklist()
            elif choice == "4":
                self.generate_spm_manifest()
            elif choice == "5":
                self.generate_build_scripts()
            elif choice == "6":
                print("Goodbye! 👋")
                break
            else:
                print("Invalid choice. Try again.")
    
    def show_framework_candidates(self):
        """Display framework candidate files"""
        candidates = self.report.get("framework_candidates", [])
        
        if not candidates:
            print("❌ No framework candidates found in report.")
            return
        
        print(f"\n✅ Found {len(candidates)} framework candidate files:")
        print("-" * 60)
        
        # Group by directory
        candidates_by_dir = {}
        for candidate in candidates:
            dir_path = os.path.dirname(candidate)
            candidates_by_dir.setdefault(dir_path, []).append(os.path.basename(candidate))
        
        for directory, files in candidates_by_dir.items():
            print(f"\n📁 {directory}/")
            for file in files[:10]:  # Show first 10 files per directory
                print(f"   • {file}")
            if len(files) > 10:
                print(f"   ... and {len(files) - 10} more")
        
        print(f"\n💡 These files are good candidates to move to your framework.")
        print("   They typically include:")
        print("   - Models, Managers, Services")
        print("   - Utilities, Helpers")
        print("   - Network layers")
        print("   - Reusable UI components")
    
    def generate_framework_structure(self):
        """Generate recommended folder structure"""
        print("\n📂 Generating framework structure...")
        
        framework_name = self.report.get("project_info", {}).get("project_name", "MyFramework")
        if framework_name.endswith("Tests") or framework_name.endswith("UITests"):
            framework_name = framework_name.replace("Tests", "").replace("UITests", "")
        
        framework_name = f"{framework_name}Framework"
        
        structure = f"""
Recommended Framework Structure:
────────────────────────────────
{FrameworkName}/
├── Sources/
│   ├── {framework_name}/
│   │   ├── Models/          # Data models
│   │   ├── Networking/      # API clients, endpoints
│   │   ├── Utilities/       # Helpers, extensions
│   │   ├── UI/             # Reusable UI components
│   │   ├── Services/       # Business logic
│   │   └── Resources/      # Internal resources
│   └── {framework_name}.swift  # Main framework file
├── Tests/
│   └── {framework_name}Tests/
│       ├── UnitTests/      # Unit tests
│       ├── Mocks/          # Test doubles
│       └── TestHelpers/    # Testing utilities
├── Resources/              # Public resources
│   ├── Assets.xcassets
│   ├── Localizable.strings
│   └── Fonts/
├── Documentation/          # API documentation
├── Examples/              # Example usage
└── Package.swift          # Swift Package Manager manifest
"""
        print(structure)
        
        # Ask if user wants to create the structure
        create = input("\nCreate this structure? (y/n): ").lower()
        if create == 'y':
            self._create_directory_structure(framework_name)
    
    def _create_directory_structure(self, framework_name: str):
        """Create the directory structure"""
        base_path = self.project_path / framework_name
        
        directories = [
            f"Sources/{framework_name}/Models",
            f"Sources/{framework_name}/Networking",
            f"Sources/{framework_name}/Utilities",
            f"Sources/{framework_name}/UI",
            f"Sources/{framework_name}/Services",
            f"Sources/{framework_name}/Resources",
            f"Tests/{framework_name}Tests/UnitTests",
            f"Tests/{framework_name}Tests/Mocks",
            f"Tests/{framework_name}Tests/TestHelpers",
            "Resources",
            "Documentation",
            "Examples"
        ]
        
        for directory in directories:
            dir_path = base_path / directory
            dir_path.mkdir(parents=True, exist_ok=True)
            print(f"📁 Created: {dir_path.relative_to(self.project_path)}")
        
        # Create placeholder files
        placeholder_files = [
            (f"Sources/{framework_name}/{framework_name}.swift", 
             f"""// Main framework file
import Foundation

public class {framework_name} {{
    public static let shared = {framework_name}()
    
    private init() {{ }}
    
    public func configure() {{
        // Framework configuration
    }}
}}
"""),
            (f"Sources/{framework_name}/Networking/APIClient.swift",
             """// Example API Client
import Foundation

public class APIClient {
    public static let shared = APIClient()
    
    private init() { }
    
    public func fetchData<T: Decodable>(from endpoint: String) async throws -> T {
        // Implementation
        fatalError("Implement this method")
    }
}
"""),
            ("Package.swift",
             f"""// swift-tools-version:5.7
import PackageDescription

let package = Package(
    name: "{framework_name}",
    platforms: [
        .iOS(.v{self._get_ios_version()})
    ],
    products: [
        .library(
            name: "{framework_name}",
            targets: ["{framework_name}"])
    ],
    targets: [
        .target(
            name: "{framework_name}",
            dependencies: [],
            path: "Sources/{framework_name}",
            resources: [.process("Resources")]
        ),
        .testTarget(
            name: "{framework_name}Tests",
            dependencies: ["{framework_name}"],
            path: "Tests/{framework_name}Tests"
        )
    ]
)
""")
        ]
        
        for file_path, content in placeholder_files:
            full_path = base_path / file_path
            with open(full_path, 'w') as f:
                f.write(content)
            print(f"📄 Created: {full_path.relative_to(self.project_path)}")
        
        print(f"\n✅ Framework structure created at: {base_path.relative_to(self.project_path)}")
    
    def _get_ios_version(self) -> str:
        """Extract iOS version from deployment target"""
        deployment_target = self.report.get("project_info", {}).get("deployment_target", "13.0")
        # Extract major version
        version_match = re.search(r'(\d+)\.', deployment_target)
        if version_match:
            return version_match.group(1)
        return "13"
    
    def generate_migration_checklist(self):
        """Generate migration checklist"""
        print("\n📋 GENERATING MIGRATION CHECKLIST")
        print("="*60)
        
        candidates = self.report.get("framework_candidates", [])
        app_files = self.report.get("app_specific_files", [])
        
        checklist = f"""
MIGRATION CHECKLIST
───────────────────

PHASE 1: PREPARATION
☐ Backup project and create git branch
☐ Analyze dependencies (see report)
☐ Decide on distribution method (SPM/CocoaPods/Manual)

PHASE 2: CREATE FRAMEWORK STRUCTURE
☐ Create new Framework target in Xcode
☐ Set deployment target: {self.report.get("project_info", {}).get("deployment_target", "13.0")}
☐ Configure build settings:
  - Build Libraries for Distribution: YES
  - Skip Install: NO
  - Defines Module: YES

PHASE 3: MOVE FILES ({len(candidates)} files identified)
"""
        
        # Add file migration items
        for i, candidate in enumerate(candidates[:20], 1):
            checklist += f"☐ Move: {candidate}\n"
        
        if len(candidates) > 20:
            checklist += f"... and {len(candidates) - 20} more files\n"
        
        checklist += f"""
PHASE 4: UPDATE ACCESS CONTROL
☐ Add public/open access modifiers to all public APIs
☐ Create bundle helper for resource loading
☐ Update imports in main app

PHASE 5: HANDLE RESOURCES
☐ Move shared assets to framework
☐ Update asset loading to use framework bundle
☐ Move localization strings if shared

PHASE 6: TESTING
☐ Create unit tests for framework
☐ Test integration with main app
☐ Test on device and simulator

PHASE 7: DISTRIBUTION
☐ Choose version number (recommend: 1.0.0)
☐ Build .xcframework for distribution
☐ Update documentation
"""
        
        print(checklist)
        
        # Save checklist to file
        checklist_path = self.project_path / "framework_migration_checklist.md"
        with open(checklist_path, 'w') as f:
            f.write(checklist)
        
        print(f"✅ Checklist saved to: {checklist_path.relative_to(self.project_path)}")
    
    def generate_spm_manifest(self):
        """Generate Swift Package Manager manifest"""
        print("\n📦 GENERATING SWIFT PACKAGE MANAGER MANIFEST")
        print("="*60)
        
        framework_name = self.report.get("project_info", {}).get("project_name", "MyFramework")
        if framework_name.endswith("Tests") or framework_name.endswith("UITests"):
            framework_name = framework_name.replace("Tests", "").replace("UITests", "")
        
        framework_name = f"{framework_name}Framework"
        ios_version = self._get_ios_version()
        
        # Check for dependencies
        dependencies_section = ""
        if self.report.get("pod_dependencies"):
            dependencies_section = "\n    dependencies: [\n"
            for pod in self.report.get("pod_dependencies", [])[:5]:
                pod_name = pod.split("/")[-1] if "/" in pod else pod
                dependencies_section += f'        .package(url: "https://github.com/{pod}", from: "1.0.0"),\n'
            dependencies_section += "    ],\n"
        
        manifest = f"""// swift-tools-version:5.7
import PackageDescription

let package = Package(
    name: "{framework_name}",
    platforms: [
        .iOS(.v{ios_version}),
        .macCatalyst(.v{ios_version})
    ],
    products: [
        .library(
            name: "{framework_name}",
            targets: ["{framework_name}"])
    ],{dependencies_section}
    targets: [
        .target(
            name: "{framework_name}",
            dependencies: [],
            path: "Sources/{framework_name}",
            resources: [
                .process("Resources")
            ],
            swiftSettings: [
                .define("DEBUG", .when(configuration: .debug))
            ]
        ),
        .testTarget(
            name: "{framework_name}Tests",
            dependencies: ["{framework_name}"],
            path: "Tests/{framework_name}Tests"
        )
    ]
)

// Additional Configuration:
// 1. To add resources: Include in resources array above
// 2. To add dependencies: Add to dependencies array
// 3. To exclude files: Add exclude parameter to target
"""
        
        print(manifest)
        
        # Save manifest
        save = input("\nSave as Package.swift? (y/n): ").lower()
        if save == 'y':
            manifest_path = self.project_path / "Package.swift"
            with open(manifest_path, 'w') as f:
                f.write(manifest)
            print(f"✅ Package.swift saved to: {manifest_path}")
    
    def generate_build_scripts(self):
        """Generate build scripts for framework"""
        print("\n⚙️ GENERATING BUILD SCRIPTS")
        print("="*60)
        
        framework_name = self.report.get("project_info", {}).get("project_name", "MyFramework")
        if framework_name.endswith("Tests") or framework_name.endswith("UITests"):
            framework_name = framework_name.replace("Tests", "").replace("UITests", "")
        
        framework_name = f"{framework_name}Framework"
        
        # Build script
        build_script = f"""#!/bin/bash

# Build Script for {framework_name}
# Run with: chmod +x build_framework.sh && ./build_framework.sh

set -e  # Exit on error

# Configuration
FRAMEWORK_NAME="{framework_name}"
CONFIGURATION="Release"
OUTPUT_DIR="Build"

# Colors for output
RED='\\033[0;31m'
GREEN='\\033[0;32m'
YELLOW='\\033[1;33m'
BLUE='\\033[0;34m'
NC='\\033[0m' # No Color

print_step() {{
    echo -e "${{BLUE}}▶ $1${{NC}}"
}}

print_success() {{
    echo -e "${{GREEN}}✓ $1${{NC}}"
}}

print_error() {{
    echo -e "${{RED}}✗ $1${{NC}}"
}}

print_warning() {{
    echo -e "${{YELLOW}}⚠ $1${{NC}}"
}}

# Clean up previous builds
clean() {{
    print_step "Cleaning previous builds..."
    rm -rf "${{OUTPUT_DIR}}"
    rm -rf "*.xcarchive"
    xcodebuild clean -scheme "${{FRAMEWORK_NAME}}"
}}

# Build for iOS devices
build_ios() {{
    print_step "Building for iOS devices..."
    xcodebuild archive \\
        -scheme "${{FRAMEWORK_NAME}}" \\
        -configuration "${{CONFIGURATION}}" \\
        -destination "generic/platform=iOS" \\
        -archivePath "${{OUTPUT_DIR}}/${{FRAMEWORK_NAME}}-iOS.xcarchive" \\
        -sdk iphoneos \\
        BUILD_LIBRARIES_FOR_DISTRIBUTION=YES \\
        SKIP_INSTALL=NO \\
        | xcpretty || exit 1
}}

# Build for iOS Simulator
build_simulator() {{
    print_step "Building for iOS Simulator..."
    xcodebuild archive \\
        -scheme "${{FRAMEWORK_NAME}}" \\
        -configuration "${{CONFIGURATION}}" \\
        -destination "generic/platform=iOS Simulator" \\
        -archivePath "${{OUTPUT_DIR}}/${{FRAMEWORK_NAME}}-Simulator.xcarchive" \\
        -sdk iphonesimulator \\
        BUILD_LIBRARIES_FOR_DISTRIBUTION=YES \\
        SKIP_INSTALL=NO \\
        | xcpretty || exit 1
}}

# Create XCFramework
create_xcframework() {{
    print_step "Creating XCFramework..."
    
    IOS_FRAMEWORK="${{OUTPUT_DIR}}/${{FRAMEWORK_NAME}}-iOS.xcarchive/Products/Library/Frameworks/${{FRAMEWORK_NAME}}.framework"
    SIMULATOR_FRAMEWORK="${{OUTPUT_DIR}}/${{FRAMEWORK_NAME}}-Simulator.xcarchive/Products/Library/Frameworks/${{FRAMEWORK_NAME}}.framework"
    
    if [ ! -d "${{IOS_FRAMEWORK}}" ]; then
        print_error "iOS framework not found at: ${{IOS_FRAMEWORK}}"
        exit 1
    fi
    
    if [ ! -d "${{SIMULATOR_FRAMEWORK}}" ]; then
        print_error "Simulator framework not found at: ${{SIMULATOR_FRAMEWORK}}"
        exit 1
    fi
    
    xcodebuild -create-xcframework \\
        -framework "${{IOS_FRAMEWORK}}" \\
        -framework "${{SIMULATOR_FRAMEWORK}}" \\
        -output "${{OUTPUT_DIR}}/${{FRAMEWORK_NAME}}.xcframework"
    
    print_success "XCFramework created at: ${{OUTPUT_DIR}}/${{FRAMEWORK_NAME}}.xcframework"
}}

# Verify architectures
verify_architectures() {{
    print_step "Verifying architectures..."
    
    XCFRAMEWORK="${{OUTPUT_DIR}}/${{FRAMEWORK_NAME}}.xcframework"
    
    if [ -d "${{XCFRAMEWORK}}" ]; then
        echo "XCFramework contains:"
        find "${{XCFRAMEWORK}}" -name "*.framework" -exec basename {{}} \\; | while read framework; do
            echo "  - $framework"
            lipo -info "${{XCFRAMEWORK}}/$framework/${{FRAMEWORK_NAME}}" 2>/dev/null || true
        done
    fi
}}

# Create ZIP for distribution
create_zip() {{
    print_step "Creating distribution ZIP..."
    
    cd "${{OUTPUT_DIR}}"
    zip -r "${{FRAMEWORK_NAME}}.xcframework.zip" "${{FRAMEWORK_NAME}}.xcframework"
    cd - > /dev/null
    
    print_success "ZIP created at: ${{OUTPUT_DIR}}/${{FRAMEWORK_NAME}}.xcframework.zip"
    
    # Print SHA256 for verification
    print_step "SHA256 checksum:"
    shasum -a 256 "${{OUTPUT_DIR}}/${{FRAMEWORK_NAME}}.xcframework.zip"
}}

# Main execution
main() {{
    echo -e "${{BLUE}}================================${{NC}}"
    echo -e "${{BLUE}}  Building ${{FRAMEWORK_NAME}}  ${{NC}}"
    echo -e "${{BLUE}}================================${{NC}}"
    
    # Create output directory
    mkdir -p "${{OUTPUT_DIR}}"
    
    # Execute steps
    clean
    build_ios
    build_simulator
    create_xcframework
    verify_architectures
    
    # Ask about creating ZIP
    read -p "Create distribution ZIP? (y/n): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        create_zip
    fi
    
    print_success "Build completed successfully!"
    echo -e "${{GREEN}}XCFramework location: ${{OUTPUT_DIR}}/${{FRAMEWORK_NAME}}.xcframework${{NC}}"
}}

# Run main function
main "$@"
"""
        
        print(build_script)
        
        # Save script
        save = input("\nSave as build_framework.sh? (y/n): ").lower()
        if save == 'y':
            script_path = self.project_path / "build_framework.sh"
            with open(script_path, 'w') as f:
                f.write(build_script)
            
            # Make executable
            import stat
            script_path.chmod(script_path.stat().st_mode | stat.S_IEXEC)
            
            print(f"✅ Build script saved to: {script_path}")
            print("   Make executable with: chmod +x build_framework.sh")

def main():
    parser = argparse.ArgumentParser(description="iOS Framework Conversion Helper")
    parser.add_argument("--project", "-p", default=".", 
                       help="Path to iOS project (default: current directory)")
    parser.add_argument("--task", "-t", choices=["checklist", "spm", "build", "structure"],
                       help="Run specific task without interactive mode")
    
    args = parser.parse_args()
    
    helper = ConversionHelper(args.project)
    
    if args.task:
        if args.task == "checklist":
            helper.generate_migration_checklist()
        elif args.task == "spm":
            helper.generate_spm_manifest()
        elif args.task == "build":
            helper.generate_build_scripts()
        elif args.task == "structure":
            helper.generate_framework_structure()
    else:
        helper.interactive_mode()

if __name__ == "__main__":
    import re  # Import here since it's used in methods
    main()
