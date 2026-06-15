# 🧩 Problem: Writing Markdown files via terminal (heredoc formatting breaks)

## 🎯 Symptom
When creating `.md` files using `cat << 'EOF'`, output may break formatting.

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

cat << 'EOF' > sample.md
# 🧰 Sample Document

This is a clean Markdown file created using heredoc.

## Example
```bash
echo "Hello World"


---

# ⚡ Key lesson

## ✔ You can only have ONE active heredoc at a time

Think:

> ❌ Nested heredocs = broken shell state  
> ✅ One heredoc → close it → then start another  

---

# 🧠 Mental model

A heredoc is like:

> “Everything after this point is a file until I explicitly say STOP.”

If you forget STOP → shell never returns to normal.

---