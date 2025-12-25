# .claude Configuration Directory

This directory contains configuration and tracking files for Claude-assisted development.

## 📁 Files

### `instructions.md` ⭐ MAIN CONFIG
**Purpose:** Complete instructions for Claude on how to develop MelChat iOS app

**Contains:**
- Mandatory file reading order (PLAN.md → iOS_TASKS.md → etc.)
- Project structure overview
- Security-critical files list
- Code style guidelines
- Anti-duplication rules
- Testing protocols
- Work log requirements

**Claude must read this file at the start of EVERY session!**

### `work-log.md` 📝 WORK LOG
**Purpose:** Track all development work to prevent duplication

**Format:**
- Newest entries at top
- Detailed task descriptions
- Files modified/created
- Testing checklist
- Duration tracking

**Claude must:**
1. Check this BEFORE starting any task
2. Update this AFTER completing any task

## 🚀 How It Works

### For Every Task:

```
1. User makes request
   ↓
2. Claude reads instructions.md (if not already)
   ↓
3. Claude checks work-log.md for duplicates
   ↓
4. Claude reads PLAN.md + iOS_TASKS.md
   ↓
5. Claude checks existing files
   ↓
6. Claude proposes approach
   ↓
7. User approves
   ↓
8. Claude implements
   ↓
9. Claude tests
   ↓
10. Claude updates work-log.md
```

## ✅ Benefits

### Prevents:
- ❌ Duplicate work
- ❌ Breaking existing features
- ❌ Ignoring documentation
- ❌ Creating duplicate files
- ❌ Loss of context between sessions

### Ensures:
- ✅ Consistent code quality
- ✅ Following MVVM patterns
- ✅ Protecting critical files
- ✅ Proper testing
- ✅ Full development history

## 📊 Usage Stats

Check `work-log.md` for:
- Total tasks completed
- Files created/modified
- Time spent per task
- Build/test status
- Progress towards MVP

## 🔧 Maintenance

### User Should:
- Read work-log.md periodically
- Verify completed tasks
- Clear old entries (optional, after 30 days)

### Claude Should:
- Keep entries detailed
- Update after every task
- Check before every task
- Maintain accurate statistics

---

**Created:** 2024-12-24
**Version:** 1.0
**Status:** Active
