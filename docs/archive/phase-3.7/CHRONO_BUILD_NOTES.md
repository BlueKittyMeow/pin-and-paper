# Chrono.js Build Notes for Phase 3.7

## Critical Fix: UMD Bundle Required

### Problem
The chrono-node v2.7.6 package does not provide a pre-built browser bundle. The ESM bundle from esm.sh contains `export` statements that QuickJS (used by flutter_js) cannot parse, resulting in:

```
SyntaxError: unsupported keyword: export
```

### Solution
Create a UMD (Universal Module Definition) bundle using browserify that wraps chrono-node for QuickJS compatibility.

### Build Process

```bash
# 1. Install dependencies
cd /tmp
npm init -y
npm install chrono-node@2.7.6 browserify terser --save-dev

# 2. Create entry file
cat > chrono-entry.js << 'EOF'
const chrono = require('chrono-node');
globalThis.chrono = chrono;
EOF

# 3. Bundle with browserify (creates UMD wrapper)
./node_modules/.bin/browserify chrono-entry.js -o chrono-bundle.js --standalone chrono

# 4. Minify
npx terser chrono-bundle.js -c -m -o chrono.min.js

# 5. Copy to assets
cp chrono.min.js /path/to/pin_and_paper/assets/js/chrono.min.js
```

### Bundle Size
- Unminified: ~750KB
- Minified: ~236KB

### UMD Format
The browserify bundle creates a UMD wrapper that:
1. Detects the environment (CommonJS, AMD, or global)
2. Sets `globalThis.chrono` for browser/QuickJS compatibility
3. Exposes all chrono-node exports

### flutter_js Linux Plugin Issue

**Problem**: The `libquickjs_c_bridge_plugin.so` native library exists in the flutter_js package but isn't being copied to the build bundle automatically.

**Temporary Workaround**:
```bash
cp ~/.pub-cache/hosted/pub.dev/flutter_js-0.8.5/linux/shared/libquickjs_c_bridge_plugin.so \
   build/linux/x64/debug/bundle/lib/
```

**Root Cause**: The flutter_js plugin's CMakeLists.txt has an install step that should copy the library, but it may not be executing properly in the build process.

**Permanent Fix**: This should be resolved by:
1. flutter_js package maintainers fixing the Linux build
2. Or creating a post-build script to copy the library

### Verification

Test the bundle loads correctly:

```dart
final jsRuntime = getJavascriptRuntime();
final result = jsRuntime.evaluate('''
  const text = "tomorrow";
  const parsed = chrono.parse(text);
  JSON.stringify(parsed);
''');
print(result.stringResult); // Should output parsed result
```

### Important Notes

1. **Do NOT use esm.sh bundles** - They contain ES6 module syntax
2. **Do NOT use npm CDN bundles** - chrono-node v2.x has no dist/ directory
3. **Always use browserify** to create QuickJS-compatible bundles
4. **Test on actual device** - QuickJS is only available on mobile/desktop, not in tests

### Future Improvements

Consider alternatives if chrono-node becomes unmaintained:
- chrono (original, lighter weight)
- date-fns with custom parser
- Day.js with custom parsing plugin
- Native platform date parsing (platform channels)
