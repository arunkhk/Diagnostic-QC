#!/bin/bash
# Minimal: Only adds sourceSets to app/build.gradle if missing
# Also creates minimal MainActivity that delegates to android/ folder code
# No preservation folder needed - just injects configuration
# Also fixes plugin compatibility issues (e.g., light_sensor compileSdkVersion)

TARGET_BUILD_GRADLE=".android/app/build.gradle"
MAIN_ACTIVITY_PATH=".android/app/src/main/java/com/example/flutter_module/host/MainActivity.java"

if [ ! -d ".android" ] || [ ! -f "$TARGET_BUILD_GRADLE" ]; then
    exit 0
fi

# Check if sourceSets already exists
if grep -q "sourceSets" "$TARGET_BUILD_GRADLE"; then
    SOURCESETS_EXISTS=true
else
    SOURCESETS_EXISTS=false
fi

# Add sourceSets, Kotlin plugin, and signing config before the closing brace of android block
python3 << 'PYEOF'
import re
import os

with open('.android/app/build.gradle', 'r') as f:
    content = f.read()

# Check if Kotlin plugin is already added
if 'org.jetbrains.kotlin.android' not in content:
    # Add Kotlin plugin after com.android.application
    if 'apply plugin: "com.android.application"' in content:
        content = content.replace(
            'apply plugin: "com.android.application"',
            'apply plugin: "com.android.application"\napply plugin: "org.jetbrains.kotlin.android"'
        )
        print("✅ Added Kotlin plugin to build.gradle")
    elif 'id("com.android.application")' in content:
        # Handle plugins block format
        content = re.sub(
            r'(id\("com\.android\.application"\))',
            r'\1\n    id("org.jetbrains.kotlin.android")',
            content
        )
        print("✅ Added Kotlin plugin to build.gradle")

# Check if key.properties exists in android directory
key_properties_path = '../android/key.properties'
has_signing = os.path.exists(key_properties_path)

# Add signing configuration if key.properties exists (before buildTypes)
signing_config = ''
if has_signing:
    signing_config = '''
    // Load keystore properties for signing
    def keystorePropertiesFile = rootProject.file('../android/key.properties')
    def keystoreProperties = new Properties()
    if (keystorePropertiesFile.exists()) {
        keystoreProperties.load(new FileInputStream(keystorePropertiesFile))
    }

    signingConfigs {
        release {
            if (keystorePropertiesFile.exists()) {
                keyAlias keystoreProperties['keyAlias']
                keyPassword keystoreProperties['keyPassword']
                storeFile file(keystoreProperties['storeFile'])
                storePassword keystoreProperties['storePassword']
            }
        }
    }
'''

# Remove any existing signingConfigs block first (to avoid duplicates)
# Match from "// Load keystore" to end of signingConfigs block
content = re.sub(r'\s*// Load keystore.*?signingConfigs\s*\{[^}]*release\s*\{[^}]*\}[^}]*\}', '', content, flags=re.MULTILINE | re.DOTALL)

# Insert signing config before buildTypes block (MUST be before buildTypes)
if has_signing:
    # Check if signingConfigs block already exists
    if 'signingConfigs {' not in content:
        # Insert signingConfigs block BEFORE buildTypes
        pattern = r'(\s+)(buildTypes\s*\{)'
        replacement = r'\1' + signing_config + r'\n\1\2'
        content = re.sub(pattern, replacement, content)
        print("Inserted signingConfigs before buildTypes")
    
    # Update release buildType to use signing config
    # Check if it already has the conditional logic
    if 'if (keystorePropertiesFile.exists())' not in content or 'signingConfig = signingConfigs.release' not in content:
        # Replace simple signingConfig assignment with conditional
        if 'signingConfig = signingConfigs.debug' in content:
            content = content.replace(
                'signingConfig = signingConfigs.debug',
                'if (keystorePropertiesFile.exists()) {\n                signingConfig = signingConfigs.release\n            } else {\n                signingConfig = signingConfigs.debug\n            }'
            )
        elif 'signingConfig = signingConfigs.release' in content and 'if (keystorePropertiesFile.exists())' not in content:
            # Wrap existing release config with conditional
            content = re.sub(
                r'(release\s*\{[^}]*?)(signingConfig\s*=\s*signingConfigs\.release)',
                r'\1if (keystorePropertiesFile.exists()) {\n                \2\n            } else {\n                signingConfig = signingConfigs.debug\n            }',
                content,
                flags=re.MULTILINE | re.DOTALL
            )

# Find the android block and add sourceSets before closing brace
sourceSets_config = '''
    // Read code directly from android/ folder
    sourceSets {
        main {
            java {
                srcDirs += ['../../../android/app/src/main/java']
            }
            res {
                srcDirs += ['../../../android/app/src/main/res']
            }
        }
    }
'''

# Check if sourceSets already exists
if 'sourceSets' not in content:
    # Insert before the closing brace of android block (before the line with just })
    pattern = r'(\s+)(\})\s*buildDir'
    replacement = r'\1' + sourceSets_config + r'\n\1\2\n\1buildDir'
    content = re.sub(pattern, replacement, content)
    print("✅ Added sourceSets to build.gradle")
else:
    print("✅ sourceSets already exists in build.gradle")

# Add kotlinOptions if not present
if 'kotlinOptions' not in content and 'compileOptions' in content:
    # Add kotlinOptions after compileOptions
    kotlin_options = '''
    kotlinOptions {
        jvmTarget = "17"
    }
'''
    content = re.sub(
        r'(compileOptions\s*\{[^}]*\})',
        r'\1' + kotlin_options,
        content,
        flags=re.DOTALL
    )
    print("✅ Added kotlinOptions to build.gradle")

# Note: minifyEnabled/shrinkResources can cause ClassCastException with Flutter module + split-per-abi.
# Keeping split-per-abi and obfuscate for size reduction; enable minify in app build.gradle if needed.

with open('.android/app/build.gradle', 'w') as f:
    f.write(content)

if has_signing:
    print("✅ Added signing configuration to build.gradle")
PYEOF

# Merge TouchActivity into Flutter module AndroidManifest if it exists in native manifest
FLUTTER_MANIFEST=".android/app/src/main/AndroidManifest.xml"
NATIVE_MANIFEST="../android/app/src/main/AndroidManifest.xml"

# Always try to merge permissions (even if native manifest doesn't exist, add location permissions)
if [ -f "$FLUTTER_MANIFEST" ]; then
    python3 << 'MANIFEST_EOF'
import xml.etree.ElementTree as ET
import os

flutter_manifest = ".android/app/src/main/AndroidManifest.xml"
native_manifest = "../android/app/src/main/AndroidManifest.xml"

if not os.path.exists(flutter_manifest):
    exit(0)

# Parse Flutter manifest
tree_flutter = ET.parse(flutter_manifest)
root_flutter = tree_flutter.getroot()

# Check existing permissions
existing_permissions = set()
for perm in root_flutter.findall("uses-permission"):
    perm_name = perm.get("{http://schemas.android.com/apk/res/android}name")
    if perm_name:
        existing_permissions.add(perm_name)

# Always ensure location permissions exist
required_location_permissions = [
    "android.permission.ACCESS_FINE_LOCATION",
    "android.permission.ACCESS_COARSE_LOCATION"
]

app_flutter = root_flutter.find("application")
app_index = list(root_flutter).index(app_flutter) if app_flutter is not None else -1

permissions_added = 0
for loc_perm in required_location_permissions:
    if loc_perm not in existing_permissions:
        new_perm = ET.Element("uses-permission")
        new_perm.set("{http://schemas.android.com/apk/res/android}name", loc_perm)
        if app_index >= 0:
            root_flutter.insert(app_index, new_perm)
            app_index += 1
        else:
            root_flutter.append(new_perm)
        existing_permissions.add(loc_perm)
        permissions_added += 1
        print(f"✅ Added required location permission: {loc_perm}")

# Parse native manifest if it exists and merge other permissions
if os.path.exists(native_manifest):

    tree_native = ET.parse(native_manifest)
    root_native = tree_native.getroot()
    print(f"✅ Found native manifest at: {native_manifest}")

    # Find TouchActivity in native manifest
    app_native = root_native.find("application")
touch_activity = None
for activity in app_native.findall("activity"):
    if "TouchActivity" in activity.get("android:name", ""):
        touch_activity = activity
        break

    # Check if TouchActivity exists in Flutter manifest
    app_flutter = root_flutter.find("application")
    touch_exists = False
    for activity in app_flutter.findall("activity"):
        if "TouchActivity" in activity.get("android:name", ""):
            touch_exists = True
            break

    # Find TouchActivity in native manifest
    app_native = root_native.find("application")
    touch_activity = None
    for activity in app_native.findall("activity"):
        if "TouchActivity" in activity.get("android:name", ""):
            touch_activity = activity
            break

    # Add permissions from native manifest that don't exist in Flutter manifest
    for perm in root_native.findall("uses-permission"):
        perm_name = perm.get("{http://schemas.android.com/apk/res/android}name")
        if perm_name and perm_name not in existing_permissions and perm_name != "android.permission.INTERNET":
            new_perm = ET.Element("uses-permission")
            new_perm.set("{http://schemas.android.com/apk/res/android}name", perm_name)
            # Copy all attributes
            for key, value in perm.attrib.items():
                if "{http://schemas.android.com/apk/res/android}name" not in key:
                    new_perm.set(key, value)
            # Insert before application
            if app_index >= 0:
                root_flutter.insert(app_index, new_perm)
                app_index += 1  # Update index for next insertion
            else:
                root_flutter.append(new_perm)
            existing_permissions.add(perm_name)
            permissions_added += 1

    # Merge features from native manifest
    existing_features = set()
    for feature in root_flutter.findall("uses-feature"):
        feature_name = feature.get("{http://schemas.android.com/apk/res/android}name")
        if feature_name:
            existing_features.add(feature_name)

    features_added = 0
    for feature in root_native.findall("uses-feature"):
        feature_name = feature.get("{http://schemas.android.com/apk/res/android}name")
        if feature_name and feature_name not in existing_features:
            new_feature = ET.Element("uses-feature")
            for key, value in feature.attrib.items():
                new_feature.set(key, value)
            # Insert before application
            if app_index >= 0:
                root_flutter.insert(app_index, new_feature)
                app_index += 1
            else:
                root_flutter.append(new_feature)
            existing_features.add(feature_name)
            features_added += 1

    # Update app label from native manifest if it exists
    app_native_label = app_native.get("{http://schemas.android.com/apk/res/android}label")
    if app_native_label:
        app_flutter.set("{http://schemas.android.com/apk/res/android}label", app_native_label)
        print(f"✅ Updated app label to: {app_native_label}")

    # Add TouchActivity if it exists in native but not in Flutter
    if touch_activity is not None and not touch_exists:
        # Use fully qualified name for Flutter module
        new_activity = ET.Element("activity")
        new_activity.set("android:name", "com.example.qc.Activity.TouchActivity")
        for key, value in touch_activity.attrib.items():
            if key != "android:name":  # Already set above
                new_activity.set(key, value)
        
        # Insert before meta-data
        meta_data = app_flutter.find("meta-data")
        if meta_data is not None:
            app_flutter.insert(list(app_flutter).index(meta_data), new_activity)
        else:
            app_flutter.append(new_activity)

    # Merge queries from native manifest
    queries_native = root_native.find("queries")
    queries_flutter = root_flutter.find("queries")
    
    if queries_native is not None:
        if queries_flutter is None:
            # Create queries element in Flutter manifest
            queries_flutter = ET.Element("queries")
            root_flutter.append(queries_flutter)
        
        # Get existing intent actions in Flutter queries
        existing_intents = set()
        for intent in queries_flutter.findall("intent"):
            action = intent.find("action")
            if action is not None:
                action_name = action.get("{http://schemas.android.com/apk/res/android}name")
                if action_name:
                    existing_intents.add(action_name)
        
        # Add intents from native that don't exist in Flutter
        for intent_native in queries_native.findall("intent"):
            action_native = intent_native.find("action")
            if action_native is not None:
                action_name = action_native.get("{http://schemas.android.com/apk/res/android}name")
                if action_name and action_name not in existing_intents:
                    # Copy the entire intent element
                    new_intent = ET.Element("intent")
                    for child in intent_native:
                        new_child = ET.Element(child.tag)
                        for key, value in child.attrib.items():
                            new_child.set(key, value)
                        new_intent.append(new_child)
                    queries_flutter.append(new_intent)
                    existing_intents.add(action_name)

# Write back with proper namespace declarations
ET.indent(tree_flutter, space="    ")

# Ensure root has proper namespace declarations (remove duplicates first)
# Remove all xmlns attributes to prevent duplicates
for key in list(root_flutter.attrib.keys()):
    if key.startswith("xmlns"):
        del root_flutter.attrib[key]

# Set namespace declarations properly (only once)
root_flutter.set("xmlns:android", "http://schemas.android.com/apk/res/android")
if os.path.exists(native_manifest):
    tree_native_temp = ET.parse(native_manifest)
    root_native_temp = tree_native_temp.getroot()
    if root_native_temp.get("xmlns:tools"):
        root_flutter.set("xmlns:tools", root_native_temp.get("xmlns:tools"))

# Write to string first, then fix namespace prefixes
import io
output = io.BytesIO()
tree_flutter.write(output, encoding='utf-8', xml_declaration=True)
xml_content = output.getvalue().decode('utf-8')

# Replace generic namespace prefixes with proper ones
xml_content = xml_content.replace('ns0:', 'android:')
xml_content = xml_content.replace('ns1:', 'tools:')
xml_content = xml_content.replace('xmlns:ns0=', 'xmlns:android=')
xml_content = xml_content.replace('xmlns:ns1=', 'xmlns:tools=')

# Clean up any duplicate or malformed xmlns attributes in manifest tag
import re
# Pattern to find and fix manifest tag
manifest_pattern = r'<manifest([^>]*)>'
def clean_manifest_attrs(match):
    attrs = match.group(1)
    # Remove any standalone URLs (malformed attributes)
    attrs = re.sub(r'\s+"http://[^"]*"', '', attrs)
    # Remove duplicate xmlns:android (keep only first)
    android_count = attrs.count('xmlns:android=')
    if android_count > 1:
        # Split by xmlns:android= and keep first occurrence
        parts = re.split(r'xmlns:android=', attrs, maxsplit=1)
        if len(parts) == 2:
            first_part = parts[0]
            # Extract the first complete xmlns:android value
            rest = parts[1]
            # Find the closing quote
            quote_match = re.match(r'("[^"]*")', rest)
            if quote_match:
                first_android_value = quote_match.group(1)
                # Remove all other xmlns:android from the rest
                remaining = re.sub(r'xmlns:android="[^"]*"\s*', '', rest[len(first_android_value):])
                attrs = first_part + 'xmlns:android=' + first_android_value + ' ' + remaining
    # Clean up extra spaces
    attrs = re.sub(r'\s+', ' ', attrs).strip()
    return '<manifest ' + attrs + '>'

xml_content = re.sub(manifest_pattern, clean_manifest_attrs, xml_content)

# Write to file
with open(flutter_manifest, 'w', encoding='utf-8') as f:
    f.write(xml_content)

if permissions_added > 0 or features_added > 0 or (touch_activity is not None and not touch_exists):
    msg = "✅ Merged"
    if permissions_added > 0:
        msg += f" {permissions_added} permissions"
    if features_added > 0:
        msg += f" {features_added} features"
    if touch_activity is not None and not touch_exists:
        msg += " TouchActivity"
    msg += " to Flutter manifest"
    print(msg)
MANIFEST_EOF
fi

# Create minimal MainActivity that delegates to android/ folder (ALWAYS UPDATE - Flutter may overwrite it)
echo "📝 Creating/Updating MainActivity that delegates to android/ folder..."
mkdir -p "$(dirname "$MAIN_ACTIVITY_PATH")"
cat > "$MAIN_ACTIVITY_PATH" << 'MAINACTIVITY_EOF'
package com.example.flutter_module.host;

import io.flutter.embedding.android.FlutterFragmentActivity;
import io.flutter.embedding.engine.FlutterEngine;
import com.example.qc.FlutterHandlerRegistrar;
import android.util.Log;

/**
 * Flutter module's MainActivity - delegates to android/ folder code.
 * All handler registration comes from android/app via sourceSets.
 * This file is automatically updated by preserve_android_code.sh
 */
public class MainActivity extends FlutterFragmentActivity {
    @Override
    public void configureFlutterEngine(FlutterEngine flutterEngine) {
        super.configureFlutterEngine(flutterEngine);
        // Register all native handlers from android/app
        try {
            FlutterHandlerRegistrar.registerHandlers(flutterEngine, this, null, null, null, null, null, null, null, null, null, null, null, null);
            Log.d("MainActivity", "✅ All native handlers registered successfully");
        } catch (Exception e) {
            Log.e("MainActivity", "❌ Failed to register handlers: " + e.getMessage(), e);
        }
    }
}
MAINACTIVITY_EOF
echo "✅ Created/Updated MainActivity that delegates to android/ folder"

# Fix plugin compatibility issues (e.g., light_sensor compileSdkVersion)
PLUGIN_PATH="$HOME/.pub-cache/hosted/pub.dev/light_sensor-3.0.1/android/build.gradle"

if [ -f "$PLUGIN_PATH" ]; then
    # Check if already patched
    if grep -q "compileSdkVersion 34" "$PLUGIN_PATH"; then
        echo "✅ light_sensor plugin already patched"
    else
        # Patch the compileSdkVersion
        if sed -i '' 's/compileSdkVersion 30/compileSdkVersion 34/g' "$PLUGIN_PATH" 2>/dev/null || \
           sed -i 's/compileSdkVersion 30/compileSdkVersion 34/g' "$PLUGIN_PATH" 2>/dev/null; then
            echo "✅ Patched light_sensor plugin: compileSdkVersion 30 → 34"
        else
            echo "⚠️  Failed to patch light_sensor plugin (may need manual fix)"
        fi
    fi
fi
