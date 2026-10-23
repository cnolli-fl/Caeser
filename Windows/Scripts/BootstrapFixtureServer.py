"""CI-only loopback fixture. Never included in the online executable."""
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path
import sys
import time

payload, port_file = Path(sys.argv[1]).resolve(strict=True), Path(sys.argv[2])

class Handler(BaseHTTPRequestHandler):
    def log_message(self, *args):
        pass

    def do_GET(self):
        if self.path == '/redirect':
            self.send_response(302)
            self.send_header('Location', 'https://example.invalid/setup.exe')
            self.end_headers()
            return
        self.send_response(200)
        self.send_header('Content-Type', 'application/octet-stream')
        self.send_header('Content-Length', str(payload.stat().st_size))
        self.end_headers()
        try:
            with payload.open('rb') as stream:
                first = True
                while data := stream.read(65536 if self.path == '/slow' else 1024 * 1024):
                    if self.path == '/corrupt' and first:
                        data = data[:32] + bytes([data[32] ^ 1]) + data[33:]
                    if self.path == '/truncated':
                        self.wfile.write(data[:1000])
                        self.close_connection = True
                        return
                    self.wfile.write(data)
                    self.wfile.flush()
                    first = False
                    time.sleep(0.08 if self.path == '/slow' else 0.02)
        except (BrokenPipeError, ConnectionResetError, ConnectionAbortedError):
            pass

server = ThreadingHTTPServer(('127.0.0.1', 0), Handler)
port_file.write_text(str(server.server_port), encoding='ascii')
server.serve_forever()
