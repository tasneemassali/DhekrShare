"""Reproduce the checked-in Xcode project without third-party generators."""
from pathlib import Path
import hashlib
import json
import plistlib

ROOT = Path(__file__).resolve().parents[1]
def ident(s): return hashlib.sha1(s.encode()).hexdigest()[:24].upper()
def q(s): return json.dumps(s)
objects = []
def obj(name, body):
    key = ident(name)
    objects.append(f'{key} = {{ {body} }};')
    return key

def array(ids): return '(' + ', '.join(ids) + ',)'
sources = []
files = []
for path in sorted((ROOT / 'DhekrShare').rglob('*.swift')):
    name = str(path.relative_to(ROOT))
    ref = obj(name, f'isa = PBXFileReference; lastKnownFileType = sourcecode.swift; path = {q(name)}; sourceTree = SOURCE_ROOT;')
    files.append(ref)
    sources.append(obj('build-' + name, f'isa = PBXBuildFile; fileRef = {ref};'))
asset = obj('assets', 'isa = PBXFileReference; lastKnownFileType = folder.assetcatalog; path = DhekrShare/Resources/Assets.xcassets; sourceTree = SOURCE_ROOT;')
files.append(asset)
assetbuild = obj('assetbuild', f'isa = PBXBuildFile; fileRef = {asset};')
product = obj('product', 'isa = PBXFileReference; explicitFileType = wrapper.application; path = DhekrShare.app; sourceTree = BUILT_PRODUCTS_DIR;')
local = obj('config', 'isa = PBXFileReference; lastKnownFileType = text.xcconfig; path = Config/Base.xcconfig; sourceTree = SOURCE_ROOT;')
files.append(local)
products = obj('products', f'isa = PBXGroup; children = {array([product])}; name = Products; sourceTree = "<group>";')
group = obj('group', f'isa = PBXGroup; children = {array(files + [products])}; sourceTree = "<group>";')
package = obj('firebase', 'isa = XCRemoteSwiftPackageReference; repositoryURL = "https://github.com/firebase/firebase-ios-sdk.git"; requirement = {kind = upToNextMajorVersion; minimumVersion = 12.0.0;};')
deps=[]
frameworks=[]
for name in ['FirebaseAuth', 'FirebaseCore', 'FirebaseFunctions', 'FirebaseMessaging', 'FirebaseAppCheck']:
    dep = obj(name, f'isa = XCSwiftPackageProductDependency; package = {package}; productName = {name};')
    deps.append(dep)
    frameworks.append(obj('link'+name, f'isa = PBXBuildFile; productRef = {dep};'))
sourcephase = obj('sources', f'isa = PBXSourcesBuildPhase; buildActionMask = 2147483647; files = {array(sources)}; runOnlyForDeploymentPostprocessing = 0;')
resourcephase = obj('resources', f'isa = PBXResourcesBuildPhase; buildActionMask = 2147483647; files = {array([assetbuild])}; runOnlyForDeploymentPostprocessing = 0;')
frameworkphase = obj('frameworks', f'isa = PBXFrameworksBuildPhase; buildActionMask = 2147483647; files = {array(frameworks)}; runOnlyForDeploymentPostprocessing = 0;')
script = '''set -eu
CONFIG="$SRCROOT/Config/GoogleService-Info.plist"
DEST="$TARGET_BUILD_DIR/$UNLOCALIZED_RESOURCES_FOLDER_PATH/GoogleService-Info.plist"
if [ -f "$CONFIG" ]; then
  cp "$CONFIG" "$DEST"
else
  rm -f "$DEST"
  echo "warning: Firebase is not configured; app will show setup mode."
fi
'''
configphase = obj('copyconfig', f'isa = PBXShellScriptBuildPhase; buildActionMask = 2147483647; files = (); inputPaths = (); outputPaths = (); alwaysOutOfDate = 1; name = "Copy local Firebase configuration"; runOnlyForDeploymentPostprocessing = 0; shellPath = /bin/sh; shellScript = {q(script)};')
projectconfigs=[]
targetconfigs=[]
for mode in ['Debug', 'Release']:
    settings = 'CLANG_ENABLE_MODULES = YES; SDKROOT = iphoneos; IPHONEOS_DEPLOYMENT_TARGET = 17.0; SWIFT_VERSION = 5.0;'
    projectconfigs.append(obj('proj'+mode, f'isa = XCBuildConfiguration; buildSettings = {{{settings}}}; name = {mode};'))
    settings = '''PRODUCT_NAME = "$(TARGET_NAME)"; TARGETED_DEVICE_FAMILY = 1; SUPPORTED_PLATFORMS = "iphoneos iphonesimulator";
    SUPPORTS_MACCATALYST = NO; GENERATE_INFOPLIST_FILE = NO; INFOPLIST_FILE = DhekrShare/Resources/Info.plist;
    CODE_SIGN_STYLE = Automatic; CODE_SIGN_ENTITLEMENTS = DhekrShare/Resources/DhekrShare.entitlements;
    ASSETCATALOG_COMPILER_APPICON_NAME = AppIcon; ENABLE_USER_SCRIPT_SANDBOXING = NO;
    LD_RUNPATH_SEARCH_PATHS = "$(inherited) @executable_path/Frameworks"; OTHER_LDFLAGS = "$(inherited) -ObjC";
    CURRENT_PROJECT_VERSION = 1; MARKETING_VERSION = 1.0; SWIFT_STRICT_CONCURRENCY = targeted;'''
    settings += ' SWIFT_OPTIMIZATION_LEVEL = "-Onone"; SWIFT_ACTIVE_COMPILATION_CONDITIONS = DEBUG; APS_ENVIRONMENT = development;' if mode == 'Debug' else ' SWIFT_OPTIMIZATION_LEVEL = "-O"; APS_ENVIRONMENT = production;'
    targetconfigs.append(obj('target'+mode, f'isa = XCBuildConfiguration; baseConfigurationReference = {local}; buildSettings = {{{settings}}}; name = {mode};'))
pc = obj('pc', f'isa = XCConfigurationList; buildConfigurations = {array(projectconfigs)}; defaultConfigurationIsVisible = 0; defaultConfigurationName = Release;')
tc = obj('tc', f'isa = XCConfigurationList; buildConfigurations = {array(targetconfigs)}; defaultConfigurationIsVisible = 0; defaultConfigurationName = Release;')
target = obj('target', f'isa = PBXNativeTarget; buildConfigurationList = {tc}; buildPhases = {array([sourcephase,frameworkphase,resourcephase,configphase])}; buildRules = (); dependencies = (); name = DhekrShare; packageProductDependencies = {array(deps)}; productName = DhekrShare; productReference = {product}; productType = "com.apple.product-type.application";')
project = obj('project', f'isa = PBXProject; attributes = {{BuildIndependentTargetsInParallel = YES; LastUpgradeCheck = 1600; TargetAttributes = {{{target} = {{SystemCapabilities = {{com.apple.Push = {{enabled = 1;}}; com.apple.AppAttest = {{enabled = 1;}};}};}};}};}}; buildConfigurationList = {pc}; compatibilityVersion = "Xcode 14.0"; developmentRegion = ar; hasScannedForEncodings = 0; knownRegions = (ar,en,Base); mainGroup = {group}; packageReferences = {array([package])}; productRefGroup = {products}; projectDirPath = ""; projectRoot = ""; targets = {array([target])};')
folder = ROOT / 'DhekrShare.xcodeproj'
folder.mkdir(exist_ok=True)
(folder / 'project.pbxproj').write_text('// !$*UTF8*$!\n{ archiveVersion = 1; classes = {}; objectVersion = 56; objects = {\n' + '\n'.join(objects) + f'\n}}; rootObject = {project}; }}\n')
schemes = folder / 'xcshareddata/xcschemes'
schemes.mkdir(parents=True, exist_ok=True)
ref = f'<BuildableReference BuildableIdentifier="primary" BlueprintIdentifier="{target}" BuildableName="DhekrShare.app" BlueprintName="DhekrShare" ReferencedContainer="container:DhekrShare.xcodeproj"/>'
(schemes / 'DhekrShare.xcscheme').write_text(f'''<?xml version="1.0" encoding="UTF-8"?>
<Scheme LastUpgradeVersion="1600" version="1.3">
<BuildAction parallelizeBuildables="YES" buildImplicitDependencies="YES"><BuildActionEntries><BuildActionEntry buildForTesting="YES" buildForRunning="YES" buildForProfiling="YES" buildForArchiving="YES" buildForAnalyzing="YES">{ref}</BuildActionEntry></BuildActionEntries></BuildAction>
<TestAction buildConfiguration="Debug" shouldUseLaunchSchemeArgsEnv="YES"/>
<LaunchAction buildConfiguration="Debug" selectedDebuggerIdentifier="Xcode.DebuggerFoundation.Debugger.LLDB" selectedLauncherIdentifier="Xcode.IDEFoundation.Launcher.LLDB" launchStyle="0" useCustomWorkingDirectory="NO" ignoresPersistentStateOnLaunch="NO" debugDocumentVersioning="YES" allowLocationSimulation="YES"><BuildableProductRunnable runnableDebuggingMode="0">{ref}</BuildableProductRunnable></LaunchAction>
<ProfileAction buildConfiguration="Release" shouldUseLaunchSchemeArgsEnv="YES" savedToolIdentifier="" useCustomWorkingDirectory="NO" debugDocumentVersioning="YES"><BuildableProductRunnable runnableDebuggingMode="0">{ref}</BuildableProductRunnable></ProfileAction>
<AnalyzeAction buildConfiguration="Debug"/><ArchiveAction buildConfiguration="Release" revealArchiveInOrganizer="YES"/>
</Scheme>''')
