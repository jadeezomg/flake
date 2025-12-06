# Flake Organization Issues & Improvements

## ✅ Fixed Issues
1. **Empty `modules/system/` directory** - Removed

## 🔍 Organizational Issues Found

### 1. Missing Module Categories (from rhodium structure)
Your flake is missing several module categories that rhodium has:

- **`modules/nixos/network/`** - Separate from `networking/` for advanced network services (Tailscale, VPN, etc.)
- **`modules/nixos/rules/`** - For udev rules and device-specific rules (keyboard, displays, etc.)
- **`modules/nixos/manager/`** - Display manager configurations (GDM, SDDM, greetd, etc.)
- **`modules/nixos/shell/`** - System-level shell configurations (available shells, nix-index, etc.)
- **`modules/nixos/virtualization/`** - Docker, VMs, containers

### 2. Missing Top-Level Directories
- **`lib/`** - Utility functions, generators, formatters (rhodium has this)
- **`overlays/`** - Custom package overlays (rhodium has this)

### 3. Missing Flake Outputs
- **`apps`** - Convenience commands for build/switch/etc (nixos-config has this)
- **`devShells`** - Development shell environments (both reference flakes have this)

### 4. Host Configuration Pattern
- **Current**: Hosts import `modules/nixos` which aggregates all modules
- **Rhodium**: Hosts import modules directly (more explicit, easier to see what's used)
- **Recommendation**: Current approach is fine, but rhodium's is more explicit

### 5. Data Structure
- **Current**: Users are embedded in `data/hosts/hosts.nix`
- **Rhodium**: Separate `data/users/` from `data/hosts/`
- **Recommendation**: Current approach works, but separation might be cleaner for multi-user setups

## 📋 Recommendations

### High Priority
1. ✅ Remove empty `modules/system/` directory (DONE)
2. Consider adding missing module categories if you need them:
   - `network/` - if you use Tailscale/VPN
   - `rules/` - if you need udev rules
   - `manager/` - if you want to configure display managers
   - `shell/` - if you want system-level shell configs
   - `virtualization/` - if you use Docker/VMs

### Medium Priority
3. Add `overlays/` directory if you need custom package overlays
4. Add `lib/` directory if you need utility functions
5. Add `apps` output for convenience commands (build, switch, clean, etc.)
6. Add `devShells` output for development environments

### Low Priority
7. Consider separating users from hosts in data structure (only if multi-user)
8. Consider more explicit module imports in hosts (like rhodium)

## 🎯 Current Structure Assessment

**Strengths:**
- ✅ Clean separation of shared/nixos/darwin modules
- ✅ Good Home Manager organization (shared/nixos/darwin)
- ✅ Centralized host data in `data/hosts/hosts.nix`
- ✅ Modular hardware configuration
- ✅ Proper locale configuration separation

**Areas for Improvement:**
- Missing some module categories that might be useful
- No overlays or lib utilities (may not be needed)
- No convenience apps or devShells (nice to have)

