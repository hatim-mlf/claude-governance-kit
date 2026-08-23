---
name: swift-xcode-audit
description: Perform a comprehensive code audit of an iOS/Swift/SwiftUI/Xcode project.
  Use this skill whenever the user asks to audit, review, analyze code quality,
  find bugs, find memory leaks, find race conditions, find thread safety issues,
  find performance problems, check architectural patterns, or review any Swift or
  SwiftUI or Xcode project. Also triggers for: "review my Swift code", "what's
  wrong with my iOS app", "find issues in my project", "code quality check",
  "is my Swift code good", "audit my codebase".
---

# Swift / Xcode Code Audit Skill

## Overview
Perform a thorough, evidence-based audit of an iOS Swift/SwiftUI project.
Every finding must cite the exact file name and line number. Never guess.
Always read the actual source files before reporting findings.

---

## Audit Checklist

### P0 — Security (check first)
- [ ] Hardcoded secrets: API keys, tokens, passwords in source files
  - Search: grep -r "anonKey\|apiKey\|secret\|password\|token" --include="*.swift"
  - Fix pattern: Move to .xcconfig (gitignored) → read via Bundle.main.infoDictionary
- [ ] Info.plist exposure of sensitive data
- [ ] Keychain used for all sensitive storage (never UserDefaults for tokens)
- [ ] URLSession using https:// not http://
- [ ] No certificate pinning gaps on sensitive endpoints

### P0 — Crash Risks
- [ ] fatalError() in production paths (acceptable only in init() for unrecoverable programmer error)
  - Search: grep -rn "fatalError" --include="*.swift"
- [ ] Force unwrap (!) on optionals that could be nil at runtime
  - Search: grep -n "!\." --include="*.swift" (filter out comments and strings)
- [ ] Array index access without bounds check
- [ ] Implicitly unwrapped optionals (@IBOutlet excluded) used as regular optionals

### P1 — Threading & Concurrency
- [ ] @MainActor missing on @Published ObservableObject classes
- [ ] DispatchQueue.main.asyncAfter used instead of async/await
  - Search: grep -rn "asyncAfter" --include="*.swift"
- [ ] Task.detached accessing MainActor-isolated state without await MainActor.run
- [ ] Actors used correctly (no shared mutable state accessed from multiple threads)
- [ ] NotificationCenter.addObserver without weak self (retain cycle)
- [ ] Completion handlers mixed with async/await (bridge using withCheckedContinuation correctly)
- [ ] withCheckedContinuation that might never call resume (permanent hang)

### P1 — Memory Management
- [ ] Timer.publish / Timer.scheduledTimer without invalidation on view disappear
  - Search: grep -rn "Timer.publish\|Timer.scheduled" --include="*.swift"
- [ ] Closure captures without [weak self] where self could outlive the closure
- [ ] Combine sink without storing AnyCancellable (subscription fires once and dies)
- [ ] AnyCancellable not stored in Set<AnyCancellable> on long-lived objects
- [ ] NotificationCenter observers not removed on deinit
- [ ] AVPlayer / AVAudioSession not deactivated when done

### P1 — SwiftUI Patterns
- [ ] .sheet(isPresented:) with optional data (race condition — use .sheet(item:) instead)
- [ ] @StateObject initialized with arguments (use init-less pattern or factory)
- [ ] @EnvironmentObject not provided via .environmentObject() in parent
- [ ] ObservableObject with @Published arrays — mutating from background thread
- [ ] onAppear called multiple times (use .task instead for async work)
- [ ] GeometryReader nested inside ScrollView (performance issue)
- [ ] Large computed var bodies in SwiftUI body (extract to @ViewBuilder or subview)
- [ ] ZStack hit-testing: transparent layers blocking taps (add .allowsHitTesting(false))
- [ ] .frame(maxWidth: .infinity, maxHeight: .infinity) on panel views blocking full screen input

### P1 — Performance
- [ ] O(n) computed properties recalculated on every SwiftUI render
  - Check: computed vars inside View structs that iterate activityStore.activities
- [ ] MKPolyline overlays used at scale (>1000 overlays → Metal GPU exhaustion)
  - Fix: MKMapSnapshotter + Core Graphics for heatmaps
- [ ] Synchronous disk/network I/O on main thread
- [ ] print() statements in hot paths (GPS update loop, sync, map rendering)
  - Search: grep -rn "^    print\|^        print" --include="*.swift" | wc -l
- [ ] UserDefaults.standard called on every frame/update
- [ ] ActivityStore.persist() called synchronously without debounce

### P2 — Architecture
- [ ] God View pattern: SwiftUI View > 300 lines with business logic
  - Check: wc -l on all View files
- [ ] Singleton overuse: count static let shared instances
  - Search: grep -rn "static let shared" --include="*.swift"
- [ ] Missing dependency injection (singletons not mockable for testing)
- [ ] Notification names as raw strings (typo-prone — use typed extension)
- [ ] Magic numbers without named constants
- [ ] Dead code / unused files in project

### P2 — Data & Persistence
- [ ] UserDefaults used for large or complex data (use GRDB/CoreData instead)
- [ ] Per-user UserDefaults keys without uid prefix (conflict risk on shared device)
- [ ] GRDB migrations run in correct order with version check
- [ ] Sync conflicts handled (last-write-wins timestamp present on all synced models)
- [ ] Offline queue for failed network operations

### P2 — Error Handling
- [ ] try? silencing errors that should be surfaced to user
- [ ] Empty catch blocks
- [ ] Network errors not propagated to UI
- [ ] No retry logic on transient network failures

### P3 — Code Quality
- [ ] No unit tests (XCTest targets present but empty)
- [ ] No SwiftLint configuration
- [ ] Inconsistent naming conventions
- [ ] Missing /// documentation on public APIs
- [ ] Deprecated APIs (check against current iOS deployment target)
- [ ] Unused imports

---

## Severity Definitions

| Level | Label | Meaning |
|-------|-------|---------|
| P0 | Critical | Ship blocker — security risk or guaranteed crash |
| P1 | High | Fix this sprint — memory leak, race condition, broken feature |
| P2 | Medium | Fix next sprint — architecture, performance, maintainability |
| P3 | Low | Tech debt backlog — style, docs, nice-to-haves |

---

## Audit Output Format

For each finding, write:

```
### [SEVERITY] [SHORT TITLE]
**File:** `Filename.swift` line N
**Evidence:**
[exact code snippet from file]
**Impact:** [what goes wrong if not fixed]
**Fix:** [concrete actionable fix — code snippet if helpful]
```

---

## Search Commands to Run

```bash
# Count print statements
grep -rn "^\s*print(" --include="*.swift" [PROJECT_PATH] | wc -l

# Find fatalError
grep -rn "fatalError" --include="*.swift" [PROJECT_PATH]

# Find asyncAfter
grep -rn "asyncAfter" --include="*.swift" [PROJECT_PATH]

# Find Timer.publish
grep -rn "Timer\.publish\|Timer\.scheduled" --include="*.swift" [PROJECT_PATH]

# Find singletons
grep -rn "static let shared" --include="*.swift" [PROJECT_PATH]

# Find force unwrap (rough)
grep -rn "[^!]![^=]" --include="*.swift" [PROJECT_PATH] | grep -v "//"

# Find hardcoded secrets
grep -rn "anonKey\|apiKey\|secret\|Bearer\|password" --include="*.swift" [PROJECT_PATH]

# Find .sheet(isPresented:) pattern
grep -rn "sheet(isPresented:" --include="*.swift" [PROJECT_PATH]

# Count lines per file (find god views)
find [PROJECT_PATH] -name "*.swift" | xargs wc -l | sort -rn | head -30

# Find dead/old files
find [PROJECT_PATH] -name "* old *" -o -name "*_old*" -o -name "*_OLD*"
```

---

## Notes for Velox / GPXViewer specifically
- Supabase anon key known to be hardcoded (P0-1 confirmed)
- DatabaseManager.fatalError known (P0-2 confirmed)  
- 355 print() confirmed (P1-1 confirmed)
- 55 DispatchQueue.main.asyncAfter confirmed (P1-2 confirmed)
- ContentView.swift is 1,058+ lines (P1-5 confirmed)
- .sheet(isPresented:) race in HomeView confirmed (P1-SwiftUI confirmed)
- Timer.publish in RideReplayView without cleanup (P1-Memory confirmed)
- HomeView computed streak is O(n×days) (P1-Performance confirmed)