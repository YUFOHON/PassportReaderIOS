#!/usr/bin/env python3
"""
iOS Project Framework Analyzer
Scans your Xcode project and provides conversion recommendations
"""

import os
import sys
import json
import re
import subprocess
import glob
import plistlib
from pathlib import Path
from typing import Dict, List, Set, Tuple, Optional
import argparse

class ProjectAnalyzer:
    def __init__(self, project_path: str):
        self.project_path = Path(project_path).resolve()
        self.project_data = {}
        self.findings = {
            "project_info": {},
            "files": [],
            "dependencies": [],
            "issues": [],
            "recommendations": [],
            "conversion_plan": []
        }
        
    def analyze(self):
        """Main analysis method"""
        print(f"🔍 Analyzing project at: {self.project_path}")
        
        # Find Xcode project file
        xcodeproj_path = self._find_xcodeproj()
        if not xcodeproj_path:
            print("❌ No Xcode project found!")
            return False
            
        print(f"📁 Found project: {xcodeproj_path.name}")
        
        # Extract project information
        self._extract_project_info(xcodeproj_path)
        
        # Analyze directory structure
        self._analyze_directory_structure()
        
        # Analyze Swift files
        self._analyze_swift_files()
        
        # Analyze dependencies
        self._analyze_dependencies()
        
        # Generate report
        self._generate_report()
        
        return True
    
    def _find_xcodeproj(self) -> Optional[Path]:
        """Find .xcodeproj or .xcworkspace file"""
        # Look for .xcodeproj
        xcodeproj_files = list(self.project_path.glob("*.xcodeproj"))
        if xcodeproj_files:
            return xcodeproj_files[0]
            
        # Look for .xcworkspace
        xcworkspace_files = list(self.project_path.glob("*.xcworkspace"))
        if xcworkspace_files:
            return xcworkspace_files[0]
            
        # Search recursively
        for root, dirs, files in os.walk(self.project_path):
            if "project.pbxproj" in files:
                return Path(root)
                
        return None
    
    def _extract_project_info(self, xcodeproj_path: Path):
        """Extract basic project information"""
        pbxproj_path = xcodeproj_path / "project.pbxproj"
        
        if pbxproj_path.exists():
            try:
                with open(pbxproj_path, 'r', encoding='utf-8') as f:
                    content = f.read()
                    
                # Extract project name
                project_name = xcodeproj_path.stem.replace(".xcodeproj", "").replace(".xcworkspace", "")
                
                # Look for targets
                targets_match = re.findall(r'name = (.*?);', content)
                
                # Look for deployment target
                deployment_match = re.search(r'IPHONEOS_DEPLOYMENT_TARGET = (.*?);', content)
                
                self.findings["project_info"] = {
                    "project_name": project_name,
                    "path": str(xcodeproj_path),
                    "targets": list(set(targets_match))[:10],  # Limit to 10
                    "deployment_target": deployment_match.group(1) if deployment_match else "Unknown",
                    "has_workspace": xcodeproj_path.suffix == ".xcworkspace"
                }
                
            except Exception as e:
                print(f"⚠️ Error reading project file: {e}")
    
    def _analyze_directory_structure(self):
        """Analyze project directory structure"""
        print("📂 Analyzing directory structure...")
        
        file_types = {
            ".swift": 0,
            ".m": 0,
            ".h": 0,
            ".storyboard": 0,
            ".xib": 0,
            ".json": 0,
            ".plist": 0,
            ".png": 0,
            ".jpg": 0,
            ".strings": 0
        }
        
        total_lines = 0
        swift_files = []
        
        for root, dirs, files in os.walk(self.project_path):
            # Skip certain directories
            skip_dirs = {'.git', 'Pods', 'DerivedData', 'build', 'Carthage'}
            dirs[:] = [d for d in dirs if d not in skip_dirs]
            
            for file in files:
                file_path = Path(root) / file
                ext = file_path.suffix.lower()
                
                if ext in file_types:
                    file_types[ext] += 1
                    
                # Analyze Swift files
                if ext == ".swift":
                    swift_files.append(str(file_path))
                    lines = self._count_lines(str(file_path))
                    total_lines += lines
                    
                    # Check if it's a ViewController
                    if "ViewController" in file:
                        self.findings["issues"].append({
                            "type": "ViewController",
                            "file": str(file_path.relative_to(self.project_path)),
                            "message": "ViewControllers are usually app-specific"
                        })
        
        self.findings["stats"] = {
            "file_types": file_types,
            "total_swift_files": file_types[".swift"],
            "total_objc_files": file_types[".m"] + file_types[".h"],
            "total_lines_of_code": total_lines,
            "ui_files": file_types[".storyboard"] + file_types[".xib"]
        }
        
        # Analyze some Swift files in detail
        if swift_files:
            sample_files = swift_files[:5]  # Analyze first 5 files
            for file_path in sample_files:
                self._analyze_swift_file_content(file_path)
    
    def _count_lines(self, file_path: str) -> int:
        """Count lines in a file"""
        try:
            with open(file_path, 'r', encoding='utf-8') as f:
                return len(f.readlines())
        except:
            return 0
    
    def _analyze_swift_file_content(self, file_path: str):
        """Analyze content of a Swift file"""
        try:
            with open(file_path, 'r', encoding='utf-8') as f:
                content = f.read()
                
            relative_path = str(Path(file_path).relative_to(self.project_path))
            
            # Check for common patterns
            issues = []
            recommendations = []
            
            # Check for UIKit imports (likely UI components)
            if "import UIKit" in content:
                if "class" in content and "UIViewController" in content:
                    issues.append("Contains ViewController - might be app-specific")
                elif "UIView" in content and "class" in content:
                    recommendations.append("Potential reusable UI component")
            
            # Check for Foundation-only imports
            if "import Foundation" in content and "import UIKit" not in content:
                recommendations.append("Good candidate for framework (no UI dependency)")
            
            # Check for access control
            if "public " in content or "open " in content:
                recommendations.append("Already has public API design")
            else:
                issues.append("No public access modifiers - will need to add them")
            
            # Check for testability
            if "@testable" in content:
                recommendations.append("Has testable imports - good for testing")
            
            if issues or recommendations:
                self.findings["files"].append({
                    "path": relative_path,
                    "issues": issues,
                    "recommendations": recommendations
                })
                
        except Exception as e:
            print(f"⚠️ Error analyzing {file_path}: {e}")
    
    def _analyze_swift_files(self):
        """Analyze Swift files for framework suitability"""
        print("📄 Analyzing Swift files...")
        
        # Look for common patterns across all Swift files
        framework_candidates = []
        app_specific_files = []
        
        swift_files = list(self.project_path.rglob("*.swift"))
        
        for swift_file in swift_files[:20]:  # Limit to 20 files for performance
            try:
                relative_path = str(swift_file.relative_to(self.project_path))
                
                with open(swift_file, 'r', encoding='utf-8') as f:
                    content = f.read()
                
                # Skip test files
                if "Tests/" in str(swift_file) or "Test.swift" in str(swift_file):
                    continue
                
                # Check file characteristics
                is_framework_candidate = self._is_framework_candidate(content, str(swift_file))
                
                if is_framework_candidate:
                    framework_candidates.append(relative_path)
                else:
                    app_specific_files.append(relative_path)
                    
            except Exception as e:
                continue
        
        self.findings["framework_candidates"] = framework_candidates[:50]
        self.findings["app_specific_files"] = app_specific_files[:20]
    
    def _is_framework_candidate(self, content: str, file_path: str) -> bool:
        """Determine if a file is a good framework candidate"""
        # Files that are definitely NOT framework candidates
        if any(keyword in file_path for keyword in [
            "AppDelegate", "SceneDelegate", "Info.plist", 
            "Main.storyboard", "Assets.xcassets"
        ]):
            return False
        
        # Files that contain app-specific patterns
        app_specific_patterns = [
            r"UIApplication\.shared",
            r"UserDefaults\.standard",
            r"Bundle\.main",
            r"@main\s",
            r"@UIApplicationMain",
            r"window\s*=\s*UIWindow",
            r"AppDelegate"
        ]
        
        for pattern in app_specific_patterns:
            if re.search(pattern, content):
                return False
        
        # Files that are GOOD framework candidates
        framework_patterns = [
            r"class.*Manager",
            r"class.*Service",
            r"class.*Helper",
            r"class.*Utils",
            r"struct.*Model",
            r"protocol.*",
            r"extension.*",
            r"public\s+(class|struct|func|var)",
            r"open\s+(class|func|var)"
        ]
        
        for pattern in framework_patterns:
            if re.search(pattern, content, re.IGNORECASE):
                return True
        
        # If it's a utility or model without UI dependencies
        if "import Foundation" in content and "import UIKit" not in content:
            return True
        
        return False
    
    def _analyze_dependencies(self):
        """Analyze project dependencies"""
        print("📦 Analyzing dependencies...")
        
        # Check for CocoaPods
        podfile_path = self.project_path / "Podfile"
        if podfile_path.exists():
            self.findings["dependencies"].append({
                "type": "CocoaPods",
                "file": "Podfile",
                "message": "Project uses CocoaPods for dependency management"
            })
            
            # Try to parse Podfile for common dependencies
            try:
                with open(podfile_path, 'r') as f:
                    podfile_content = f.read()
                    
                # Find pod declarations
                pods = re.findall(r"pod\s+['\"]([^'\"]+)['\"]", podfile_content)
                self.findings["pod_dependencies"] = pods[:20]
                
            except:
                pass
        
        # Check for Swift Package Manager
        package_path = self.project_path / "Package.swift"
        if package_path.exists():
            self.findings["dependencies"].append({
                "type": "Swift Package Manager",
                "file": "Package.swift",
                "message": "Project uses SPM for dependency management"
            })
        
        # Check for Carthage
        cartfile_path = self.project_path / "Cartfile"
        if cartfile_path.exists():
            self.findings["dependencies"].append({
                "type": "Carthage",
                "file": "Cartfile",
                "message": "Project uses Carthage for dependency management"
            })
        
        # Check for project dependencies
        frameworks_dir = self.project_path / "Frameworks"
        if frameworks_dir.exists():
            frameworks = list(frameworks_dir.glob("*.framework"))
            if frameworks:
                self.findings["dependencies"].append({
                    "type": "Embedded Frameworks",
                    "count": len(frameworks),
                    "message": f"Found {len(frameworks)} embedded frameworks"
                })
    
    def _generate_report(self):
        """Generate analysis report and recommendations"""
        print("\n" + "="*60)
        print("📊 ANALYSIS REPORT")
        print("="*60)
        
        # Project Info
        project_info = self.findings["project_info"]
        print(f"\n📱 Project: {project_info.get('project_name', 'Unknown')}")
        print(f"📍 Path: {project_info.get('path', 'Unknown')}")
        print(f"🎯 Deployment Target: {project_info.get('deployment_target', 'Unknown')}")
        
        # Statistics
        stats = self.findings.get("stats", {})
        if stats:
            print(f"\n📈 Statistics:")
            print(f"   Swift Files: {stats.get('total_swift_files', 0)}")
            print(f"   Objective-C Files: {stats.get('total_objc_files', 0)}")
            print(f"   Storyboard/XIB Files: {stats.get('ui_files', 0)}")
            print(f"   Estimated Lines of Code: {stats.get('total_lines_of_code', 0):,}")
            
            file_types = stats.get('file_types', {})
            if file_types:
                print(f"\n   File Type Breakdown:")
                for ext, count in file_types.items():
                    if count > 0:
                        print(f"   {ext}: {count}")
        
        # Dependencies
        if self.findings.get("dependencies"):
            print(f"\n📦 Dependencies Found:")
            for dep in self.findings["dependencies"]:
                print(f"   • {dep['type']}: {dep.get('message', '')}")
        
        # Framework Candidates
        candidates = self.findings.get("framework_candidates", [])
        if candidates:
            print(f"\n✅ FRAMEWORK CANDIDATES ({len(candidates)} files):")
            for i, candidate in enumerate(candidates[:10], 1):
                print(f"   {i}. {candidate}")
            if len(candidates) > 10:
                print(f"   ... and {len(candidates) - 10} more")
        
        # App-Specific Files
        app_files = self.findings.get("app_specific_files", [])
        if app_files:
            print(f"\n📱 APP-SPECIFIC FILES ({len(app_files)} files):")
            for i, file in enumerate(app_files[:5], 1):
                print(f"   {i}. {file}")
            if len(app_files) > 5:
                print(f"   ... and {len(app_files) - 5} more")
        
        # Issues
        if self.findings.get("issues"):
            print(f"\n⚠️ POTENTIAL ISSUES:")
            for issue in self.findings["issues"][:5]:
                print(f"   • {issue.get('message', 'Unknown issue')}")
        
        # Generate Conversion Plan
        self._generate_conversion_plan()
        
        print(f"\n" + "="*60)
        print("🚀 RECOMMENDED ACTION PLAN")
        print("="*60)
        
        for i, step in enumerate(self.findings["conversion_plan"], 1):
            print(f"\n{i}. {step}")
        
        # Save report to file
        self._save_report()
        
        print(f"\n💾 Full report saved to: project_analysis_report.json")
        print(f"\n📋 To get started, run the conversion helper script:")
        print(f"   python3 conversion_helper.py --project=\"{self.project_path}\"")
    
    def _generate_conversion_plan(self):
        """Generate step-by-step conversion plan"""
        plan = []
        
        # Step 1: Preparation
        plan.append("BACKUP YOUR PROJECT before starting")
        plan.append("Create a new branch in git: git checkout -b framework-conversion")
        
        # Step 2: Create framework target
        plan.append("Open project in Xcode and add new Framework target")
        plan.append("Name it: {project_name}Framework (e.g., MyAppFramework)")
        
        # Step 3: Organize files
        plan.append(f"Create folder structure in project:")
        plan.append("  - Sources/ (for framework code)")
        plan.append("  - Resources/ (for assets, strings)")
        plan.append("  - Tests/ (for framework unit tests)")
        
        # Step 4: Move files
        candidates = self.findings.get("framework_candidates", [])
        if candidates:
            plan.append(f"Move {len(candidates)} framework candidate files to new Sources folder")
        
        # Step 5: Update access control
        plan.append("Update access modifiers in framework files:")
        plan.append("  - Change 'class' to 'public class' for public APIs")
        plan.append("  - Change 'func' to 'public func' for public methods")
        plan.append("  - Use 'open' for classes meant to be subclassed")
        
        # Step 6: Handle resources
        stats = self.findings.get("stats", {})
        if stats.get('ui_files', 0) > 0:
            plan.append("Update resource loading to use framework bundle")
        
        # Step 7: Build and test
        plan.append("Build framework target (Cmd+B)")
        plan.append("Create unit tests for framework")
        plan.append("Test integration with main app")
        
        # Step 8: Distribution
        plan.append("Choose distribution method:")
        plan.append("  - Swift Package Manager (recommended)")
        plan.append("  - CocoaPods")
        plan.append("  - Manual .xcframework distribution")
        
        self.findings["conversion_plan"] = plan
    
    def _save_report(self):
        """Save analysis report to JSON file"""
        report_path = self.project_path / "project_analysis_report.json"
        try:
            with open(report_path, 'w', encoding='utf-8') as f:
                json.dump(self.findings, f, indent=2, default=str)
        except Exception as e:
            print(f"⚠️ Could not save report: {e}")

def main():
    parser = argparse.ArgumentParser(description="Analyze iOS project for framework conversion")
    parser.add_argument("path", nargs="?", default=".", 
                       help="Path to iOS project (default: current directory)")
    parser.add_argument("--output", "-o", default="report.json",
                       help="Output file name for detailed report")
    
    args = parser.parse_args()
    
    analyzer = ProjectAnalyzer(args.path)
    if analyzer.analyze():
        print("\n✅ Analysis complete!")
        print("\n📝 Next steps:")
        print("1. Review the framework candidates above")
        print("2. Run the conversion helper for specific guidance")
        print("3. Create framework target in Xcode")
        print("4. Move identified files to framework")
    else:
        print("❌ Analysis failed. Make sure you're in an iOS project directory.")
        sys.exit(1)

if __name__ == "__main__":
    main()
