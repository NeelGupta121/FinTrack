#!/usr/bin/env python3
"""Serve a Flutter web build with SPA rewrite, bound to loopback only.

`python3 -m http.server` 404s on any client-side route (/expenses, /settings),
so deep links cannot be verified with it. This falls back to index.html for any
path that is not a real file -- the same rewrite rule the production host
applies -- which makes every screen directly addressable for screenshots.
"""
import argparse
import os
from http.server import SimpleHTTPRequestHandler, ThreadingHTTPServer


class SpaHandler(SimpleHTTPRequestHandler):
    def do_GET(self):  # noqa: N802
        path = self.translate_path(self.path)
        if not os.path.isfile(path) and not os.path.isdir(path):
            self.path = "/index.html"
        return super().do_GET()

    def log_message(self, *args):  # keep the console quiet
        pass


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--directory", required=True)
    ap.add_argument("--port", type=int, default=8192)
    # Loopback only, always explicit -- never rely on the default bind.
    ap.add_argument("--bind", default="127.0.0.1")
    args = ap.parse_args()

    os.chdir(args.directory)
    srv = ThreadingHTTPServer((args.bind, args.port), SpaHandler)
    print(f"serving {args.directory} on http://{args.bind}:{args.port} (SPA rewrite)")
    srv.serve_forever()


if __name__ == "__main__":
    main()
