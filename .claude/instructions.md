# Claude Instructions for MelChat iOS Development

## 🎯 Primary Objective

You are helping develop **MelChat**, a privacy-first, end-to-end encrypted messaging iOS app using Swift 6 + SwiftUI + SwiftData.

---

## 📚 MANDATORY: Always Read These Files First

Before making ANY code changes, you MUST read these files in order:

### 1. **PLAN.md** (Master Architecture)
- Full project vision
- Hybrid P2P architecture
- Security requirements
- Original specifications

### 2. **README.md** (iOS Overview)
- Current implementation status
- Project structure
- Setup instructions

### 3. **Documentation/iOS_TASKS.md** (What to Build)
- Detailed task list with priorities
- What's completed vs pending
- Code examples for each task
- Time estimates

### 4. **Documentation/iOS_ROADMAP.md** (How to Build)
- 4-week development plan
- Architecture patterns (MVVM)
- Design system
- Testing strategy

---

## ⚠️ CRITICAL RULES

### Before Writing Any Code:

1. **Check if it already exists**
   ```
   - Search for similar files/components
   - Check iOS_TASKS.md for completion status
   - Look for duplicate implementations
   ```

2. **Verify you're not repeating work**
   ```
   - Is this feature already implemented?
   - Is there a TODO comment for this?
   - Has this been tried before?
   ```

3. **Follow existing patterns**
   ```
   - Look at similar components first
   - Use the same architecture (MVVM)
   - Match the code style
   ```

### Example Check Process:

```markdown
User asks: "Add a settings screen"

✅ CORRECT APPROACH:
1. Read iOS_TASKS.md → "Settings Screen Completion" is at P1
2. Check if SettingsView.swift exists → YES, it exists but basic
3. Read SettingsView.swift to see current implementation
4. Read SettingsViewModel.swift
5. Propose IMPROVEMENTS to existing code, not full rewrite
6. Reference iOS_TASKS.md for specific requirements

❌ WRONG APPROACH:
- Immediately write new SettingsView without checking
- Create duplicate files
- Ignore existing implementation
- Don't check task list
```

---

## 🗂️ Project Structure (Memorize This)

```
MelChat/
├── PLAN.md                          ⭐ MASTER PLAN - Read first
├── README.md                        ⭐ iOS overview
├── Documentation/
│   ├── iOS_TASKS.md                 ⭐ Task list - Check before coding
│   ├── iOS_ROADMAP.md               Development plan
│   ├── ENCRYPTION_IMPLEMENTATION.md Crypto details
│   └── Features/                    Feature docs
│
├── MelChat/
│   ├── App/
│   │   ├── MelChatApp.swift         App entry point
│   │   └── AppState.swift           Global state
│   │
│   ├── Core/
│   │   ├── Encryption/
│   │   │   ├── EncryptionManager.swift  ⚠️ DON'T TOUCH - Works perfectly
│   │   │   └── KeychainManager.swift    ⚠️ DON'T TOUCH - Critical
│   │   │
│   │   ├── Network/
│   │   │   └── APIClient.swift          Backend communication
│   │   │
│   │   ├── Storage/
│   │   │   └── Models/Models.swift      ⚠️ SwiftData models - BE CAREFUL
│   │   │
│   │   └── Utils/
│   │       ├── HapticManager.swift      Haptic feedback
│   │       └── DateExtensions.swift     Time formatting
│   │
│   ├── Features/
│   │   ├── Auth/                        Login/signup
│   │   ├── Chat/                        Messaging
│   │   └── Settings/                    Settings (needs work)
│   │
│   └── UI/
│       └── AvatarView.swift             Reusable avatar
```

---

## 🔐 Security-Critical Files (Handle with Extreme Care)

### NEVER modify these without explicit permission:

1. **EncryptionManager.swift**
   - Signal Protocol implementation
   - Curve25519 + AES-GCM-256
   - Works perfectly, tested
   - ⚠️ Any change could break E2E encryption

2. **KeychainManager.swift**
   - Secure key storage
   - iOS Keychain integration
   - Critical for security

3. **Models.swift** (SwiftData)
   - Database schema
   - Changes require migration
   - Ask before modifying

### If user asks to modify these:
```
❌ DON'T: Immediately modify
✅ DO:
   1. Explain current implementation
   2. Show why it works
   3. Ask: "Are you sure? This is security-critical"
   4. If yes, make minimal changes
   5. Test thoroughly
```

---

## 📋 Task Management Protocol

### When User Asks to Add a Feature:

**STEP 1: Check iOS_TASKS.md**
```markdown
Q: "Is this feature already listed?"
   - YES → What's the priority? What's the status?
   - NO → Is it in the roadmap?
```

**STEP 2: Check Existing Code**
```bash
# Search for related files
grep -r "FeatureName" MelChat/MelChat/

# Check if similar component exists
ls -la MelChat/MelChat/Features/*/Views/
```

**STEP 3: Propose Plan**
```markdown
"I found [existing implementation]. According to iOS_TASKS.md,
this is [P0/P1/P2] priority. Here's what I'll do:

1. [Specific change]
2. [Specific change]
3. [Test approach]

Should I proceed?"
```

---

## 🎨 Code Style Guidelines

### Swift Naming
```swift
// ✅ CORRECT
class ChatViewModel: ObservableObject {
    @Published var messages: [Message] = []
    @Published var isLoading = false

    func loadMessages() async {
        // Implementation
    }
}

// ❌ WRONG
class chat_view_model { // Don't use snake_case
    var Messages: [Message] = [] // Don't capitalize vars
}
```

### SwiftUI Patterns
```swift
// ✅ CORRECT - MVVM Pattern
struct ChatView: View {
    @StateObject private var viewModel = ChatViewModel()

    var body: some View {
        // UI only, no business logic
    }
}

// ❌ WRONG - Business logic in View
struct ChatView: View {
    var body: some View {
        Button {
            // Don't put encryption logic here!
        }
    }
}
```

### Error Handling
```swift
// ✅ CORRECT
do {
    try await someAsyncOperation()
} catch {
    errorMessage = error.localizedDescription
    NetworkLogger.shared.log("❌ Error: \(error)")
    HapticManager.shared.error()
}

// ❌ WRONG
try! await someAsyncOperation() // Never force-try
```

---

## 🧪 Testing Protocol

### Before Marking Task Complete:

1. **Compile Check**
   ```
   - Does it build? (⌘+B)
   - Any warnings?
   ```

2. **Runtime Check**
   ```
   - Run on simulator (⌘+R)
   - Test the specific feature
   - Check console for errors
   ```

3. **Integration Check**
   ```
   - Does it work with existing features?
   - Any UI glitches?
   - Haptic feedback working?
   ```

---

## 🚫 Anti-Patterns (Never Do These)

### 1. **Don't Create Duplicate Files**
```
❌ Creating ChatView2.swift when ChatViews.swift exists
❌ Creating NewEncryptionManager.swift
✅ Modify existing files
✅ Ask before creating new files
```

### 2. **Don't Ignore SwiftData**
```
❌ Creating custom JSON persistence
❌ Using UserDefaults for messages
✅ Use existing SwiftData models
✅ Follow Models.swift patterns
```

### 3. **Don't Break Encryption**
```
❌ Storing plaintext messages
❌ Logging encryption keys
❌ Sending unencrypted data
✅ Always use EncryptionManager
✅ Verify encryption working
```

### 4. **Don't Skip Documentation**
```
❌ Writing code without reading iOS_TASKS.md
❌ Not updating task status
✅ Check docs first
✅ Update iOS_TASKS.md when complete
```

---

## 📱 Common User Requests & Responses

### "Add a new feature"
```
✅ Response:
"Let me check iOS_TASKS.md first...
[reads file]
I see this is listed as [Priority] in the task list.
Here's the current status: [status]
Should I proceed with [specific approach]?"
```

### "Fix a bug"
```
✅ Response:
"Can you show me:
1. Which file has the bug?
2. What's the expected behavior?
3. What's actually happening?

Let me read the relevant code first..."
[reads file, understands context]
"I found the issue. It's [explanation]. Fix: [solution]"
```

### "Improve UI"
```
✅ Response:
"Let me check our design system in iOS_ROADMAP.md...
[reads design guidelines]
According to our design system:
- Colors: [guideline]
- Spacing: [guideline]
Here's the improvement: [code]"
```

---

## 🔄 Workflow Template

```markdown
USER REQUEST: [Feature/Fix/Improvement]

STEP 1: Read Documentation
- [ ] PLAN.md (if architecture-related)
- [ ] iOS_TASKS.md (check priority & status)
- [ ] Relevant feature docs

STEP 2: Check Existing Code
- [ ] Search for similar implementations
- [ ] Read related files
- [ ] Check for duplicates

STEP 3: Verify Approach
- [ ] Matches MVVM pattern?
- [ ] Uses existing components?
- [ ] Follows design system?
- [ ] Security implications?

STEP 4: Implement
- [ ] Write code
- [ ] Add comments
- [ ] Handle errors
- [ ] Add haptic feedback (if UI)

STEP 5: Verify
- [ ] Compiles?
- [ ] Runs on simulator?
- [ ] No console errors?
- [ ] Matches requirements?

STEP 6: Document
- [ ] Update iOS_TASKS.md if needed
- [ ] Add code comments
- [ ] Note any issues
```

---

## 💬 Communication Style

### When Uncertain:
```
❌ "I'll create a new EncryptionManager"
✅ "I see EncryptionManager already exists and handles X, Y, Z.
    Do you want me to modify it or are you experiencing issues?"
```

### When Proposing Changes:
```
❌ "Done! Here's the new code."
✅ "According to iOS_TASKS.md, this is P1 priority.
    I'll modify [file] to add [feature].
    This will take approximately [time].
    Should I proceed?"
```

### After Completing:
```
❌ "Finished."
✅ "✅ Completed: [Feature]
    Files modified:
    - [file1.swift]: [changes]
    - [file2.swift]: [changes]

    Test it by: [steps]

    Next in iOS_TASKS.md: [next task]"
```

---

## 🎯 Success Metrics

You're doing well if:

- ✅ No duplicate files created
- ✅ No broken encryption
- ✅ Task list status is accurate
- ✅ Code follows existing patterns
- ✅ User doesn't have to repeat requests
- ✅ Build succeeds on first try
- ✅ Features work as expected

You need to improve if:

- ❌ Creating files that already exist
- ❌ Breaking working features
- ❌ Not checking documentation first
- ❌ Ignoring task priorities
- ❌ Not testing before marking complete

---

## 🚀 Quick Reference

### Current MVP Status: 85% Complete

**Working Features:**
- ✅ E2E Encryption (perfect, don't touch)
- ✅ Auth (email verification)
- ✅ Messaging (encryption/decryption)
- ✅ Modern UX (haptics, animations)

**Pending (Check iOS_TASKS.md):**
- [ ] Message persistence (P0)
- [ ] Media upload (P1)
- [ ] Voice messages (P2)
- [ ] WebSocket (P2)

**Critical Files:**
- Don't modify: EncryptionManager.swift, KeychainManager.swift
- Be careful: Models.swift (SwiftData schema)
- Safe to modify: Views, ViewModels, UI components

---

## 📞 When Stuck

1. Read PLAN.md for architecture context
2. Read iOS_TASKS.md for specific requirements
3. Check similar existing implementations
4. Ask user for clarification
5. Propose solution with reasoning

---

**Remember:**
- 📚 Documentation first, code second
- 🔍 Check before creating
- 🎯 Follow the task list
- 🔐 Protect encryption
- ✅ Test before completing

**You are building production-grade software. Quality over speed.**

---

## 📝 Work Log Protocol (MANDATORY)

### After EVERY Task Completion:

**YOU MUST create/update `.claude/work-log.md`** with this format:

```markdown
## [DATE] - [TIME] - [TASK_NAME]

### Request
User asked: "[exact user request]"

### Files Read Before Starting
- [x] PLAN.md
- [x] iOS_TASKS.md
- [x] [other docs read]
- [x] [existing files checked]

### What I Did
1. [Specific action 1]
2. [Specific action 2]
3. [Specific action 3]

### Files Modified
- `path/to/file1.swift`: [what changed]
- `path/to/file2.swift`: [what changed]

### Files Created
- `path/to/newfile.swift`: [purpose]

### Testing Done
- [x] Compiles successfully
- [x] Runs on simulator
- [x] Feature works as expected
- [x] No console errors

### Task List Updated
- [x] iOS_TASKS.md: Marked [task] as complete

### Next Recommended Task
According to iOS_TASKS.md: [next priority task]

### Duration
Estimated: [X] minutes
Actual: [Y] minutes

---
```

### Example Log Entry:

```markdown
## 2024-12-24 - 22:00 - Add Message Persistence

### Request
User asked: "Integrate SwiftData for message persistence"

### Files Read Before Starting
- [x] PLAN.md (confirmed SwiftData requirement)
- [x] iOS_TASKS.md (Task #1, P0 priority)
- [x] Models.swift (reviewed Message model)
- [x] ChatViewModel.swift (existing implementation)

### What I Did
1. Added @Environment(\.modelContext) to ChatViewModel
2. Implemented saveMessage() function using SwiftData
3. Modified sendMessage() to call saveMessage()
4. Added loadMessages() to fetch from local DB on view appear
5. Handled sync logic (local + server)

### Files Modified
- `Features/Chat/ViewModels/ChatViewModel.swift`:
  - Added modelContext injection
  - Added saveMessage() function (lines 45-52)
  - Modified sendMessage() to save locally (line 78)
  - Added loadMessages() with SwiftData query (lines 90-105)

### Files Created
None (modified existing)

### Testing Done
- [x] Compiles successfully
- [x] Runs on simulator (iPhone 15)
- [x] Messages persist after app restart
- [x] No console errors
- [x] Sync with server works

### Task List Updated
- [x] iOS_TASKS.md: Marked "Message Persistence" as ✅ completed

### Next Recommended Task
According to iOS_TASKS.md: "Display Decrypted Messages in UI" (P0)

### Duration
Estimated: 2 hours
Actual: 1.5 hours

### Notes
- SwiftData integration worked smoothly
- No migration needed (schema unchanged)
- Performance good with 1000+ messages

---
```

---

## 🔍 Before Starting Any Task: Check Work Log

**ALWAYS do this:**

```bash
1. Open .claude/work-log.md
2. Search for similar task keywords
3. Check if already done
4. Check what approach was used before
```

### Example Check:

```markdown
User: "Add haptic feedback to send button"

YOU:
1. Check work-log.md → Search "haptic"
2. Find entry: "2024-12-23 - Added haptic feedback throughout app"
3. See: HapticManager.shared.medium() already used in sendMessage()
4. Response: "Haptic feedback is already implemented in ChatViews.swift line 327.
   Would you like me to verify it's working or change the haptic type?"

INSTEAD OF:
❌ "I'll add HapticManager..." (duplicate work)
```

---

## 📊 Work Log Benefits

### For You (Claude):
- ✅ Never repeat the same work
- ✅ Reference your past solutions
- ✅ See patterns in user requests
- ✅ Track progress accurately

### For User:
- ✅ See full development history
- ✅ Understand what's been done
- ✅ No duplicate work = faster dev
- ✅ Better continuity between sessions

---

## 🎯 Work Log File Location

**Path:** `MelChat/.claude/work-log.md`

Create it if doesn't exist. Append new entries at the TOP (newest first).

---

## 📋 Work Log Template (Copy This)

```markdown
# MelChat iOS Development Work Log

Track all development work to prevent duplication and maintain continuity.

---

## [YYYY-MM-DD] - [HH:MM] - [TASK_NAME]

### Request
User asked: "[exact request]"

### Files Read Before Starting
- [x] [file1]
- [x] [file2]

### What I Did
1. [action]
2. [action]

### Files Modified
- `path/to/file`: [changes]

### Files Created
- `path/to/file`: [purpose]

### Testing Done
- [ ] Compiles
- [ ] Runs
- [ ] Feature works
- [ ] No errors

### Task List Updated
- [ ] iOS_TASKS.md updated

### Next Task
[recommendation]

### Duration
Est: [X] / Act: [Y]

---
```

---

## ⚠️ CRITICAL: Work Log is MANDATORY

**YOU MUST:**
- ✅ Check work-log.md BEFORE starting ANY task
- ✅ Update work-log.md AFTER completing ANY task
- ✅ Be specific in entries (no vague descriptions)
- ✅ Include actual file paths and line numbers

**If you don't:**
- ❌ You'll duplicate work
- ❌ User will waste time
- ❌ Progress will be unclear
- ❌ Sessions won't have continuity

---

## 🚀 Quick Work Log Commands

### Check Log:
```bash
# Search for task
grep -i "feature_name" .claude/work-log.md

# See last 5 entries
head -100 .claude/work-log.md
```

### Add Entry:
```markdown
1. Copy template
2. Fill in details
3. Prepend to work-log.md (newest at top)
4. Save
```

---

**Remember: The work log is your memory between sessions!**

---

Last Updated: 24 December 2024
Version: 1.1

