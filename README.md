<div align="center">

# NIGHTSENSE

> Advanced resolver and ragebot automation for Neverlose.cc

[![Discord Support](https://img.shields.io/badge/Discord-Support-5865F2?style=flat-square&logo=discord&logoColor=white)](https://discord.gg/kg6udfrA3p)

</div>

---

## 🗺️ How It Works (User Flow)

This simplified flow shows how NightSense helps you hit desyncing players:

```mermaid
flowchart LR
    classDef step fill:#111215,stroke:#30363d,stroke-width:1px,color:#c9d1d9;
    classDef focus fill:#1f2335,stroke:#7aa2f7,stroke-width:1px,color:#7aa2f7;

    A[1. Detect Target] --> B(2. Analyze Desync & Jitter)
    B --> C(3. Predict Angle & Exploit Ticks)
    C --> D[4. Auto-Adjust Safepoint & Damage]
    D --> E((5. High-Accuracy Hit))

    class B,C,D focus;
```
---

## Project Metadata & Support

* **Developer:** ImSynZx
* **Discord Server Support:** [Join Server](https://discord.gg/kg6udfrA3p)
* **Official Sources:**
  * **Azura:** https://azura.uno/market?id=c7cfdb4e-5b00-41f0-833a-e6b25262152b&type=script
  * **GitLab:** https://gitlab.com/ntduckien1/neverlose-support
  * **GitHub:** https://github.com/ImSynZx/Neverlose-Lua