"""Store reports POSTed by the runtimes ISO.

Write-only: nothing can be read back over HTTP. Reports arrive age-encrypted to the
jury's keys, so this host, and the Cloudflare edge in front of it, only ever hold
ciphertext. Uploads must carry the ISO's bearer token; only its SHA-256 lives here.

Usage:
  receiver.py <host:port> <directory> <token-sha256-file>   serve
  receiver.py export <directory>                            tar of the reports to
                                                            stdout, for `docker exec`
"""

import hashlib
import hmac
import secrets
import sys
import tarfile
from datetime import datetime, timezone
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path

# Reports carry the complete bt logs. Cloudflare refuses request bodies over 100 MB,
# so anything near that would never arrive anyway.
MAX_BODY = 95 * 1024 * 1024
CHUNK = 1024 * 1024
AGE_HEADER = b"age-encryption.org/v1\n"


class Handler(BaseHTTPRequestHandler):
    server_version = "runtimes-receiver"
    sys_version = ""

    def do_POST(self):
        if self.path != "/api/reports":
            return self.reply(404, "not found")

        auth = self.headers.get("Authorization", "")
        token = auth.removeprefix("Bearer ").strip() if auth.startswith("Bearer ") else ""
        digest = hashlib.sha256(token.encode()).hexdigest()
        if not hmac.compare_digest(digest, self.server.token_hash):
            return self.reply(401, "unauthorized")

        try:
            length = int(self.headers["Content-Length"])
        except (TypeError, ValueError):
            return self.reply(411, "length required")
        if length > MAX_BODY:
            return self.reply(413, "report too large")
        head = self.rfile.read(min(length, len(AGE_HEADER)))
        if head != AGE_HEADER:
            return self.reply(400, "not an age-encrypted report")

        # Streamed to disk, so a large report never has to fit in memory. The dot
        # prefix keeps a half-written upload out of `export`.
        now = datetime.now(timezone.utc)
        report_id = f"{now:%Y%m%dT%H%M%SZ}-{secrets.token_hex(4)}"
        partial = self.server.directory / f".{report_id}.partial"
        remaining = length - len(head)
        with open(partial, "xb") as f:
            f.write(head)
            while remaining > 0:
                chunk = self.rfile.read(min(remaining, CHUNK))
                if not chunk:
                    break
                f.write(chunk)
                remaining -= len(chunk)
        if remaining > 0:
            partial.unlink()
            return self.reply(400, "upload cut short")
        partial.rename(self.server.directory / f"{report_id}.age")
        self.reply(201, report_id)

    def do_GET(self):
        self.reply(404, "not found")

    def reply(self, status, text):
        body = f"{text}\n".encode()
        self.send_response(status)
        self.send_header("Content-Type", "text/plain; charset=utf-8")
        self.send_header("Content-Length", str(len(body)))
        self.end_headers()
        self.wfile.write(body)


def export(directory):
    with tarfile.open(fileobj=sys.stdout.buffer, mode="w|") as tar:
        for path in sorted(Path(directory).glob("*.age")):
            tar.add(path, arcname=path.name)


def main():
    if sys.argv[1] == "export":
        return export(sys.argv[2])
    address, directory, token_hash_file = sys.argv[1:]
    token_hash = Path(token_hash_file).read_text().strip().lower()
    if len(token_hash) != 64:
        sys.exit(f"{token_hash_file} does not hold a SHA-256 hex digest")
    host, port = address.rsplit(":", 1)
    server = ThreadingHTTPServer((host, int(port)), Handler)
    server.directory = Path(directory)
    server.token_hash = token_hash
    server.serve_forever()


if __name__ == "__main__":
    main()
