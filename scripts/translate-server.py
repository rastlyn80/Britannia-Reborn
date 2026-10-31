"""Local live-translation service for the client (docs/VOICE_AND_TRANSLATION.md).

Runs on 127.0.0.1 only; the game starts it when a translation language is set.
Translation is Argos Translate (offline neural models, CTranslate2 on CPU),
pivoting through English between any two installed languages; the source
language is detected with langid, restricted to installed languages.

  python translate-server.py [--port 47613]      serve
  python translate-server.py --install it,es     install English <-> each language

HTTP (JSON):
  GET  /health                     {"ready": true, "languages": [...]}
  POST /translate {"text","to"}    {"text", "from", "to", "ms"}
  POST /install   {"languages"}    {"installed": [...]}  (downloads models)
"""
import argparse
import json
import os
import sys
import threading
import time
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(HERE)
os.environ.setdefault("ARGOS_PACKAGES_DIR", os.path.join(ROOT, ".tools", "translate", "packages"))
os.environ.setdefault("ARGOS_DEVICE_TYPE", "cpu")

import argostranslate.package as package  # noqa: E402
import argostranslate.translate as translate  # noqa: E402
import langid  # noqa: E402

LOCK = threading.Lock()
CACHE = {}


def installed():
    return sorted({language.code for language in translate.get_installed_languages()})


def install(codes):
    package.update_package_index()
    available = package.get_available_packages()
    done = []
    for code in codes:
        for source, target in (("en", code), (code, "en")):
            if source == target:
                continue
            match = next((p for p in available if p.from_code == source and p.to_code == target), None)
            if match is None:
                print(f"no model for {source} -> {target}", file=sys.stderr)
                continue
            if any(p.from_code == source and p.to_code == target for p in package.get_installed_packages()):
                done.append(f"{source}-{target}")
                continue
            print(f"downloading {source} -> {target}", flush=True)
            package.install_from_path(match.download())
            done.append(f"{source}-{target}")
    with LOCK:
        CACHE.clear()
    return done


def detect(text, choices):
    langid.set_languages(choices)
    code, _ = langid.classify(text)
    return code


def translate_text(text, target):
    languages = installed()
    if target not in languages or len(languages) < 2:
        return text, "", 0
    key = (text, target)
    with LOCK:
        if key in CACHE:
            return CACHE[key][0], CACHE[key][1], 0
    started = time.perf_counter()
    source = detect(text, languages)
    result = text if source == target else translate.translate(text, source, target)
    ms = int((time.perf_counter() - started) * 1000)
    with LOCK:
        if len(CACHE) > 4000:
            CACHE.clear()
        CACHE[key] = (result, source)
    return result, source, ms


class Handler(BaseHTTPRequestHandler):
    def _send(self, code, payload):
        data = json.dumps(payload, ensure_ascii=False).encode("utf-8")
        self.send_response(code)
        self.send_header("Content-Type", "application/json; charset=utf-8")
        self.send_header("Content-Length", str(len(data)))
        self.end_headers()
        self.wfile.write(data)

    def do_GET(self):
        if self.path == "/health":
            self._send(200, {"ready": True, "languages": installed()})
        else:
            self._send(404, {"error": "unknown"})

    def do_POST(self):
        try:
            length = int(self.headers.get("Content-Length", "0"))
            body = json.loads(self.rfile.read(min(length, 65536)).decode("utf-8") or "{}")
            if self.path == "/translate":
                text = str(body.get("text", ""))[:1000]
                target = str(body.get("to", "en"))
                result, source, ms = translate_text(text, target)
                self._send(200, {"text": result, "from": source, "to": target, "ms": ms})
            elif self.path == "/install":
                codes = [c for c in body.get("languages", []) if isinstance(c, str) and c.isalpha() and len(c) <= 3]
                self._send(200, {"installed": install(codes)})
            else:
                self._send(404, {"error": "unknown"})
        except Exception as error:  # report, keep serving
            self._send(500, {"error": str(error)[:300]})

    def log_message(self, *_):
        pass


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--port", type=int, default=47613)
    parser.add_argument("--install", default="")
    parser.add_argument("--warm", default="", help="languages to load before serving")
    args = parser.parse_args()
    if args.install:
        print("installed:", ", ".join(install([c for c in args.install.split(",") if c])))
        return
    # Load the chosen language's models first, so its first line is quick too.
    for code in [c for c in args.warm.split(",") if c in installed()]:
        if code != "en":
            translate.translate("Hello there.", "en", code)
            translate.translate("Hello there.", code, "en")
    server = ThreadingHTTPServer(("127.0.0.1", args.port), Handler)
    print(f"TRANSLATE READY 127.0.0.1:{args.port} {','.join(installed())}", flush=True)
    server.serve_forever()


if __name__ == "__main__":
    main()
