from http.server import BaseHTTPRequestHandler, HTTPServer


CALLBACK_HTML = """<!DOCTYPE html>
                   <html>

                   <head>
                       <meta charset="utf-8">
                       <title>Authentication complete</title>
                   </head>

                   <body>
                       <p>Authentication is complete. If this does not happen automatically, please close the window.</p>
                       <script>
                           const message = {
                         "flutter-web-auth-2": window.location.href
                       };

                       const targetOrigins = [
                         "http://localhost:1234",
                         "http://127.0.0.1:1234",
                         "https://srv.ggwpcode.com.br"
                       ];

                       if (window.opener) {
                         for (const origin of targetOrigins) {
                           window.opener.postMessage(message, origin);
                         }
                         window.close();
                       } else if (window.parent && window.parent !== window) {
                         for (const origin of targetOrigins) {
                           window.parent.postMessage(message, origin);
                         }
                       } else {
                         localStorage.setItem("flutter-web-auth-2", window.location.href);
                         window.close();
                       }
                       </script>
                   </body>

                   </html>
"""


class CallbackHandler(BaseHTTPRequestHandler):
    def do_GET(self):
        if self.path.startswith("/callback"):
            html = CALLBACK_HTML.encode("utf-8")

            self.send_response(200)
            self.send_header("Content-Type", "text/html; charset=utf-8")
            self.send_header("Cache-Control", "no-store")
            self.send_header("Content-Length", str(len(html)))
            self.end_headers()
            self.wfile.write(html)
            return

        self.send_response(404)
        self.send_header("Content-Type", "text/plain; charset=utf-8")
        self.end_headers()
        self.wfile.write(b"Not found")


if __name__ == "__main__":
    host = "localhost"
    port = 54322

    server = HTTPServer((host, port), CallbackHandler)

    print(f"Callback server rodando em http://{host}:{port}")
    print(f"Rota disponivel em http://{host}:{port}/callback")

    server.serve_forever()
