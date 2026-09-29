#!/usr/bin/env python3
"""Serve only the exported game on loopback, with WebAssembly's required MIME type."""
import argparse
from functools import partial
from http.server import SimpleHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path


class GameHandler(SimpleHTTPRequestHandler):
    extensions_map = {
        **SimpleHTTPRequestHandler.extensions_map,
        ".wasm": "application/wasm",
        ".pck": "application/octet-stream",
        ".js": "text/javascript",
        ".html": "text/html",
    }

    def end_headers(self):
        self.send_header("Cache-Control", "no-store")
        super().end_headers()

    def list_directory(self, path):
        self.send_error(404, "Export file not found")
        return None


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--port", type=int, default=8060)
    parser.add_argument("--directory", type=Path, default=Path(__file__).resolve().parents[1] / "build" / "web")
    args = parser.parse_args()
    directory = args.directory.resolve()
    if not (directory / "index.html").is_file():
        parser.error(f"No Web export at {directory}; run sh scripts/build-web.sh first.")
    if not 1 <= args.port <= 65535:
        parser.error("Port must be between 1 and 65535.")
    handler = partial(GameHandler, directory=str(directory))
    with ThreadingHTTPServer(("127.0.0.1", args.port), handler) as server:
        print(f"PRs please: http://127.0.0.1:{args.port}/ (Ctrl-C to stop)", flush=True)
        try:
            server.serve_forever()
        except KeyboardInterrupt:
            pass


if __name__ == "__main__":
    main()
