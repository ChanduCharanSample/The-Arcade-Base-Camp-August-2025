# 🌐 The Arcade Base Camp – August 2025

## 🚀 Copy and run the below commands in **Google Cloud Shell**

---

### 🔧 Step 1: Set up infrastructure

```bash
# Download the base infrastructure setup script
curl -LO https://raw.githubusercontent.com/ChanduCharanSample/The-Arcade-Base-Camp-August-2025/main/Welcome%20to%20Base%20Camp/Configuring%20Network%20Connectivity%20Center%20as%20a%20Transit%20Hub/CloudCupcake.sh

# Make the script executable
chmod +x CloudCupcake.sh

# Run the infrastructure setup script
./CloudCupcake.sh
```
# ✅ Infrastructure setup complete. Now proceed to Step 2 👇
✨ Step 2: Final verification & lab completion
```
bash
Copy
Edit
# Download the final verification and ping test script
curl -LO https://raw.githubusercontent.com/ChanduCharanSample/The-Arcade-Base-Camp-August-2025/main/Welcome%20to%20Base%20Camp/Configuring%20Network%20Connectivity%20Center%20as%20a%20Transit%20Hub/CloudCupcake1.sh

# Make the script executable
chmod +x CloudCupcake1.sh

# Run the verification script to check tunnels, ping tests, and complete the lab
./CloudCupcake1.sh
```
✅ This script verifies:

VPN Tunnel Status

Cloud Router BGP Sessions

VM Connectivity between spokes

Lab completion with green check ✅

📺 Watch the Lab Walkthrough:
CloudCupcake YouTube Channel

📌 What this script sets up automatically:

Three VPCs: vpc-transit, vpc-a, vpc-b

HA VPN tunnels between vpc-transit ↔ vpc-a and vpc-transit ↔ vpc-b

Cloud Routers with BGP

Network Connectivity Center (NCC) Hub + Spokes

End-to-end VM connectivity test

💡 Pro Tip: If you see ✅ at the end of the script, you’ve completed the lab successfully. Congrats!

📢 Don't forget to subscribe to our channel for more Google Cloud Arcade labs.

Made with ☁️ by CloudCupcake | Arcade Crew

yaml
Copy
Edit

---

Let me know if you want to:
- Add badges (e.g., YouTube, GCP verified)
- Create an `.sh` that prints ASCII art or branding
- Auto-detect errors and retry in the shell script

I can generate those as well 🚀


