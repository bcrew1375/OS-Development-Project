#!/usr/bin/env python3
from http.server import SimpleHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path
import argparse
import functools
import os


class DocumentationRequestHandler(SimpleHTTPRequestHandler):
    extensions_map = {
        **SimpleHTTPRequestHandler.extensions_map,
        ".html": "text/html; charset=utf-8",
        ".js": "text/javascript; charset=utf-8",
        ".wasm": "application/wasm",
        ".tar": "application/x-tar",
    }

    def end_headers(self):
        self.send_header("Cache-Control", "no-store, max-age=0")
        self.send_header("Pragma", "no-cache")
        self.send_header("Expires", "0")
        self.send_header("Cross-Origin-Opener-Policy", "same-origin")
        self.send_header("Cross-Origin-Embedder-Policy", "require-corp")
        self.send_header("Cross-Origin-Resource-Policy", "same-origin")
        super().end_headers()

    def do_GET(self):
        if self.path.split("?", 1)[0] == "/main.js":
            self.serve_patched_main_js()
            return
        super().do_GET()

    def serve_patched_main_js(self):
        main_js_path = Path(self.directory) / "main.js"
        try:
            content = main_js_path.read_text(encoding="utf-8")
        except OSError:
            self.send_error(404, "main.js not found")
            return

        content = patch_main_js(content)
        encoded = content.encode("utf-8")
        self.send_response(200)
        self.send_header("Content-Type", "text/javascript; charset=utf-8")
        self.send_header("Content-Length", str(len(encoded)))
        self.end_headers()
        self.wfile.write(encoded)


def patch_main_js(content: str) -> str:
    content = content.replace(
        '    let wasm_promise = fetch("main.wasm");\n',
        '''    function showLoadError(error) {
      console.error(error);
      domStatus.textContent = "Failed to load documentation: " + (error && error.message ? error.message : String(error));
      domStatus.classList.remove("hidden");
      domErrorsText.textContent += String(error && error.stack ? error.stack : error) + "\\n";
      domErrors.classList.remove("hidden");
    }

    function fetchArrayBuffer(name) {
      return fetch(name, { cache: "no-store" }).then(function(response) {
        if (!response.ok) throw new Error("unable to download " + name + ": HTTP " + response.status);
        return response.arrayBuffer();
      }).catch(function(error) {
        throw new Error("unable to fetch " + name + ": " + (error && error.message ? error.message : String(error)));
      });
    }

    let wasm_promise = fetchArrayBuffer("main.wasm");
''',
        1,
    )
    content = content.replace(
        '    let sources_promise = fetch("sources.tar").then(function(response) {\n      if (!response.ok) throw new Error("unable to download sources");\n      return response.arrayBuffer();\n    });\n',
        '    let sources_promise = fetchArrayBuffer("sources.tar");\n',
        1,
    )
    content = content.replace(
        '    WebAssembly.instantiateStreaming(wasm_promise, {\n',
        '    wasm_promise.then(function(bytes) {\n      return WebAssembly.instantiate(bytes, {\n',
        1,
    )
    content = content.replace(
        '    }).then(function(obj) {\n      wasm_exports = obj.instance.exports;\n',
        '      });\n    }).then(function(obj) {\n      wasm_exports = obj.instance.exports;\n',
        1,
    )
    content = content.replace(
        '      });\n    });\n\n    function renderTitle() {\n',
        '      }).catch(showLoadError);\n    }).catch(showLoadError);\n\n    function renderTitle() {\n',
        1,
    )
    return content


def main() -> None:
    parser = argparse.ArgumentParser(description="Serve generated Zig documentation.")
    parser.add_argument("directory", type=Path, help="Generated documentation directory to serve")
    parser.add_argument("--bind", default="127.0.0.1", help="Address to bind")
    parser.add_argument("--port", default=8765, type=int, help="Port to bind")
    args = parser.parse_args()

    directory = args.directory.resolve()
    if not directory.is_dir():
        raise SystemExit(f"documentation directory does not exist: {directory}")

    handler = functools.partial(DocumentationRequestHandler, directory=os.fspath(directory))
    server = ThreadingHTTPServer((args.bind, args.port), handler)
    print(f"Serving documentation from {directory} at http://{args.bind}:{args.port}/", flush=True)
    server.serve_forever()


if __name__ == "__main__":
    main()
