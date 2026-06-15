# 🧰 Tech Playbook

A personal, modular cheat sheet system for real-world technical problems, fixes, and recovery workflows.

This repository is a **practical knowledge base**, not theory notes.

- Fast to read
- Easy to copy-paste
- Focused on real-world fixes

---

## ⚡ Quick Start

```bash
git clone https://github.com/LenViews/tech-playbook.git
cd tech-playbook
# Browse folders or search for your issue
```

---

## 🎯 Purpose

Modern tech workflows often repeat troubleshooting steps across systems.

This repo acts as:
- A troubleshooting memory system
- A copy-paste command library
- A system recovery guide
- A learning log of real fixes

---

## 🧱 Structure

```text
tech-playbook/
├── 00-index/          # Quick navigation & search index
├── 01-linux/          # Ubuntu, systemd, package managers
├── 02-windows/        # PowerShell, WSL, registry fixes
├── 03-networking/     # DNS, SSH, Wi-Fi troubleshooting
├── 04-dev-tools/      # Git workflows, Docker, VS Code
├── 05-recovery-flows/ # Boot recovery, data rescue, backups
└── templates/         # Template files for common setups
```

---

## 🧩 How to Use

Navigate to the relevant folder and open the file.

Example:

```bash
cd 01-linux
cat vscode-install.md
```

---

## 🔍 Finding Things

- Use `grep` or your editor's search: `grep -r "your-error-term" .`
- Files follow pattern: `problem-name.md`
- Each file is self-contained—copy-paste ready

---

## 📋 File Format

Each fix follows this pattern:

**Problem** → What broke?  
**Symptoms** → What do you see?  
**Solution** → Step-by-step fix  
**Prevention** → How to avoid next time  
**Related** → Links to similar issues  

---

## 📝 Contributing

Found a fix twice? Add it here:

1. Create a new `.md` file in the relevant folder
2. Use the template: `templates/fix-template.md`
3. Include: Problem → Root Cause → Solution → Prevention
4. Open a PR with a clear commit message

---

## ⚡ Rule

If you fix it twice → document it here.
