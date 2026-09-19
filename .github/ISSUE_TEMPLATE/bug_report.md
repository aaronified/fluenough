---
name: Bug report
about: Something is not working
labels: bug
---

**What happened, and what you expected instead**

**Steps to reproduce**

**Device** — model, Android or iOS version, app version

**Deck and drill mode** — which deck, and which of recognition / production /
listening / grammar

---

### If audio is silent, please answer this first

**Were you on a physical device, an emulator, or Waydroid?**

Waydroid images ship without Google Play Services, which is what provides the
TTS voices, so listening drills are silent there. This is the most common cause
of "audio is broken" reports and is not a bug in Fluenough.

**Is a voice for the language installed?** On Android: Settings → Accessibility
→ Text-to-speech output → install voice data.
