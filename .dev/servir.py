"""Servidor estatico para probar el build web.

Existe porque `python -m http.server` no conoce `.wasm` y lo entrega como
octet-stream: el navegador rechaza el modulo y SQLite nunca arranca.
"""
import http.server, socketserver, mimetypes, sys

mimetypes.add_type('application/wasm', '.wasm')
mimetypes.add_type('text/javascript', '.js')
mimetypes.add_type('application/json', '.json')

class Handler(http.server.SimpleHTTPRequestHandler):
    def __init__(self, *a, **kw):
        super().__init__(*a, directory='build/web', **kw)

    def end_headers(self):
        # Sin cache: si no, cada rebuild queda invisible detras del anterior.
        self.send_header('Cache-Control', 'no-store')
        super().end_headers()

    def log_message(self, *a):
        pass

puerto = int(sys.argv[1]) if len(sys.argv) > 1 else 5599
socketserver.TCPServer.allow_reuse_address = True
with socketserver.TCPServer(('127.0.0.1', puerto), Handler) as srv:
    print(f'sirviendo build/web en http://127.0.0.1:{puerto}')
    srv.serve_forever()
