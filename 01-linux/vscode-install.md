# 🧩 Problem: VS Code Install on Kali Linux (Correct Microsoft Setup)

## 🎯 Symptom
- `code` command not found OR installs wrong package
- VS Code behaves inconsistently when launched
- System installs `code-oss` instead of official VS Code

---

## 📍 Cause
- Kali Linux repo provides `code-oss` (not Microsoft VS Code)
- Missing official Microsoft repository setup
- Running `code` in terminal launches GUI in foreground

---

## 🛠️ Solution (Clean Install)

### Step 1 — Remove old versions
```bash
sudo apt remove code code-oss -y
sudo apt autoremove -y

### Step 2 - Install Dependencies
```bash
sudo apt update
sudo apt install wget gpg apt-transport-https -y

### Step 3 — Add Microsoft Key
```bash
wget -qO- https://packages.microsoft.com/keys/microsoft.asc | gpg --dearmor > microsoft.gpg
sudo install -o root -g root -m 644 microsoft.gpg /etc/apt/keyrings/microsoft.gpg

### Step 4 — Add Repo
echo "deb [arch=amd64 signed-by=/etc/apt/keyrings/microsoft.gpg] https://packages.microsoft.com/repos/code stable main" | sudo tee /etc/apt/sources.list.d/vscode.list

### Step 5 — Install VS Code
sudo apt update
sudo apt install code -y

## Verification
code --version
which code

🧠 Notes
Always use Microsoft repo on Kali
Use code & to avoid terminal blocking