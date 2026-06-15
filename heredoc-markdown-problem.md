# 🧩 Problem: Writing Markdown files via terminal (heredoc formatting breaks)

## 🎯 Symptom
When creating `.md` files using `cat << 'EOF'`, output may break formatting in some cases.

## 📍 Cause
- Unclosed heredoc
- Copy-paste artifacts
- Terminal prompt accidentally included

---

## 🛠️ Solution

Always close heredoc properly:

```bash
cat << 'EOF' > filename.md
content here
