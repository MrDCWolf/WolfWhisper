# WolfWhisper & macOS Sequoia Accessibility Issue

## 🐛 Known Issue

**Problem**: macOS Sequoia has a system bug where sandboxed apps cannot properly request accessibility permissions.

**Symptoms**:
- App doesn't prompt for accessibility permissions
- App doesn't appear in System Settings > Privacy & Security > Accessibility
- Global hotkeys don't work

**Affected Versions**:
- ✅ macOS Ventura (13.x): Works fine
- ✅ macOS Sonoma (14.x): Works fine  
- ❌ macOS Sequoia (15.x): **Broken** (all versions including stable)
- ❌ macOS 26.0 beta: **Broken**

## ✅ Solution

WolfWhisper uses a **non-sandboxed version** to work around this macOS bug.

**Security**: The app is still:
- ✅ Properly code signed with Developer ID Application certificate
- ✅ Notarized by Apple
- ✅ Uses minimal required permissions
- ✅ Includes privacy manifest

## 🔮 Future

When Apple fixes this Sequoia bug, WolfWhisper will return to using a sandboxed version for enhanced security.

## 📝 Technical Details

- **Issue**: Sandbox + `com.apple.security.personal-information.accessibility` = broken on Sequoia
- **Workaround**: `com.apple.security.app-sandbox = false`
- **Apple Bug Report**: [To be filed]

---
*This issue affects many accessibility-based apps on Sequoia, not just WolfWhisper.* 