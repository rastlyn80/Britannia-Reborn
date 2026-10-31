# Voice chat and live translation (31 October 2026)

Owner request: voice chat that stays open (V or the on-screen microphone to switch it on and off), and every client seeing everything in their own language, chosen in game, translated instantly.

## Open microphone

- **Tap V or click the microphone** by the talk line: the microphone opens and stays open. Every sentence you say is recognized and said in game, then it listens again. Tap V or click again to close it.
- **Hold V:** push-to-talk as before; release to send.
- **Sentence detection:** a sentence ends after 1.8 s of quiet by default (owner: 0.9 s cut sentences short). *Pause before sending* in the menu offers 1.2, 1.8, 2.5 or 3.5 s. While nobody speaks, only a 0.4 s lead-in is kept, so the open microphone never accumulates silence.
- **Recognition:** on this computer, with whisper.cpp (`scripts/setup-speech.ps1`), or Windows speech recognition without it. Only the recognized text is sent, as ordinary speech.

Code: `Viewer/Network/VoiceChat.gd` (tap/hold, open loop), `Viewer/DevEdit/DevEditVoice.gd` (`open_mic`, `silence_seconds`, `cancel()`).

## Live translation

- **Choosing a language:** Game menu › Voice and translation › *Show everything in* (off, English, Italiano, Español, Français, Deutsch, Português, Nederlands, Polski, Svenska, Русский, Українська, Türkçe, العربية, हिन्दी, 日本語, 한국어, 中文). It is saved per character, and each player picks their own.
- **What is translated:** the journal (speech, system and server messages) and the speech floating over heads.
- **Presentation only:** game logic (cooldowns, cast bar, tools) still reads the server's own text, and what you send is your own words; the others' clients translate it.
- **Engine:** Argos Translate (MIT) neural models, run offline on the CPU by CTranslate2, with the source language detected by langid (BSD). Any two installed languages translate via English.
  - `scripts/translate-server.py` serves `127.0.0.1:47613` only; nothing leaves the computer.
  - `Viewer/Network/Translator.gd` starts it on demand (or reuses one already running) and downloads a newly chosen language's models once.
- **Order and fallbacks:** lines keep the order they arrived in. A line not translated within 2.5 s, or one with nothing to translate (numbers, commands), is shown as said. Translations are cached.
- **Setup:** `scripts/setup-translation.ps1 [-Languages it,es,fr,de]` creates `.tools/translate` (about 1.9 GB with the PyTorch dependency of Argos's sentence splitter) and installs English ↔ each language. Nothing is committed.

**Measured on this machine:**

| | Time |
|---|---:|
| Service start (Python and model load, in the background on entering the world) | about 33 s |
| Translated line, first per language pair | 0.5–1 s |
| Translated line, after that | 35–80 ms |
| Translated line, Italian → German via English | about 0.5 s |

**Checks:**
- `Viewer/Network/TranslatorTests.gd` (10 checks, in `scripts/verify.ps1`): order, holding back behind a pending line, cache, timeout fallback, off and untranslatable lines, language names, splitting long speech.
- An end-to-end run through `Translator.gd` against the real service translated English and Spanish lines into Italian.

## Remaining gaps

- **What is not translated yet:** gumps, item names, and the client's own interface text. The same `Translator.deliver` can serve them next.
- **Live voice check:** the open microphone has not been exercised live with a microphone in this pass; the recorder and Whisper path are unchanged.
- **Start-up time:** about 33 s, mostly importing the libraries; it could be shortened by a lighter sentence splitter.
