#!/usr/bin/env python3
"""Test the built macOS proxy helper against a local HTTP origin; no VPN."""
import argparse
import http.server
import json
import pathlib
import select
import socket
import subprocess
import tempfile
import threading
import time


class Origin(http.server.BaseHTTPRequestHandler):
    def do_GET(self):
        if self.path == "/traffic":
            chunk = b"x" * 65536
            self.send_response(200)
            self.send_header("Content-Length", str(len(chunk) * 32))
            self.end_headers()
            for _ in range(32):
                self.wfile.write(chunk)
                self.wfile.flush()
                time.sleep(0.03)
            return
        body = b"hako-local-proxy-test"
        self.send_response(200)
        self.send_header("Content-Length", str(len(body)))
        self.end_headers()
        self.wfile.write(body)

    def do_POST(self):
        remaining = int(self.headers["Content-Length"])
        while remaining:
            body = self.rfile.read(min(remaining, 65536))
            if not body:
                break
            remaining -= len(body)
        self.send_response(200)
        self.send_header("Content-Length", "0")
        self.end_headers()

    def log_message(self, *_):
        pass


def free_port():
    with socket.socket() as sock:
        sock.bind(("127.0.0.1", 0))
        return sock.getsockname()[1]


def close(child):
    child.stdin.close()
    try:
        child.wait(timeout=8)
    except subprocess.TimeoutExpired:
        child.kill()
        child.wait()
        raise AssertionError("Proxy helper did not stop on stdin EOF")


def launch(executable, directory, port, rule="MATCH,DIRECT", extra=None, anonymous=False, routing=None):
    config = {"tun": {"enable": True, "auto-route": True},
              "mixed-port": free_port(), "external-controller": "0.0.0.0:9090",
              "dns": {"enable": False}, "proxies": [], "rules": [rule]}
    config.update(extra or {})
    request = {"yaml": json.dumps(config), "resourceDirectory": directory,
               "port": port, "username": "" if anonymous else "hako-test", "password": "" if anonymous else "test-only-password",
               "routing": routing}
    child = subprocess.Popen([str(executable)], stdin=subprocess.PIPE,
                             stdout=subprocess.PIPE, stderr=subprocess.DEVNULL, text=True)
    try:
        child.stdin.write(json.dumps(request) + "\n")
        child.stdin.flush()
        ready, _, _ = select.select([child.stdout], [], [], 25)
        assert ready, "Proxy helper startup timed out"
        reply = json.loads(child.stdout.readline())
        return child, reply, config["mixed-port"]
    except BaseException:
        close(child)
        raise


def request(port, origin_port, scheme, password="test-only-password", host="127.0.0.1", anonymous=False):
    command = [
        "curl", "--silent", "--show-error", "--fail", "--max-time", "5", "--noproxy", "",
        "--proxy", f"{scheme}://{host}:{port}"
    ]
    if not anonymous:
        command += ["--proxy-user", f"hako-test:{password}"]
    command.append(f"http://127.0.0.1:{origin_port}/")
    return subprocess.run(command, capture_output=True)


def traffic(child):
    child.stdin.write("traffic\n")
    child.stdin.flush()
    ready, _, _ = select.select([child.stdout], [], [], 3)
    assert ready, "Traffic sample timed out"
    result = json.loads(child.stdout.readline())["traffic"]
    assert set(result) == {"up", "down", "upTotal", "downTotal"}, result
    return result


class MarkerProxy(http.server.BaseHTTPRequestHandler):
    marker = b"proxy"

    def do_CONNECT(self):
        self.send_response(200)
        self.end_headers()
        while self.rfile.readline().strip():
            pass
        self.wfile.write(b"HTTP/1.1 200 OK\r\nContent-Length: " + str(len(self.marker)).encode()
                         + b"\r\nConnection: close\r\n\r\n" + self.marker)

    def do_GET(self):
        self.send_response(200)
        self.send_header("Content-Length", str(len(self.marker)))
        self.end_headers()
        self.wfile.write(self.marker)

    def log_message(self, *_):
        pass


def set_routing(child, mode, selections):
    child.stdin.write(json.dumps({"routing": {"mode": mode, "selections": selections}}) + "\n")
    child.stdin.flush()
    ready, _, _ = select.select([child.stdout], [], [], 3)
    assert ready, "Routing update timed out"
    reply = json.loads(child.stdout.readline())
    assert not reply.get("error"), reply
    assert reply["routing"]["mode"] == mode, reply
    return reply["routing"]


def test_global_routing(executable, directory, port, origin_port):
    first = http.server.ThreadingHTTPServer(("127.0.0.1", 0), type("FirstProxy", (MarkerProxy,), {"marker": b"proxy-one"}))
    second = http.server.ThreadingHTTPServer(("127.0.0.1", 0), type("SecondProxy", (MarkerProxy,), {"marker": b"proxy-two"}))
    for server in [first, second]:
        threading.Thread(target=server.serve_forever, daemon=True).start()
    try:
        extra = {"mode": "global", "proxies": [
            {"name": "first", "type": "http", "server": "127.0.0.1", "port": first.server_port},
            {"name": "second", "type": "http", "server": "127.0.0.1", "port": second.server_port}]}
        child, reply, _ = launch(executable, directory, port, anonymous=True, extra=extra,
                                 routing={"mode": "global", "selections": {"GLOBAL": "first"}})
        try:
            assert not reply.get("error"), reply
            assert reply["routing"]["globalProxy"] == "first", reply
            assert request(port, origin_port, "socks5h", anonymous=True).stdout == b"proxy-one", "Saved GLOBAL choice was not used"
            set_routing(child, "direct", {"GLOBAL": "first"})
            assert request(port, origin_port, "socks5h", anonymous=True).stdout == b"hako-local-proxy-test"
            result = set_routing(child, "global", {"GLOBAL": "second"})
            assert result["globalProxy"] == "second", result
            assert request(port, origin_port, "socks5h", anonymous=True).stdout == b"proxy-two", "Live proxy selection was not applied"
        finally:
            close(child)
    finally:
        for server in [first, second]:
            server.shutdown()
            server.server_close()
    print("PASS: saved GLOBAL selection, real proxy egress and live mode/node switching", flush=True)


def test_traffic(child, port, origin_port, anonymous):
    before = traffic(child)
    results = []
    command = ["curl", "--silent", "--show-error", "--fail", "--max-time", "10", "--noproxy", "",
               "--proxy", f"http://127.0.0.1:{port}"]
    if not anonymous:
        command += ["--proxy-user", "hako-test:test-only-password"]
    url = f"http://127.0.0.1:{origin_port}/traffic"

    def transfer():
        results.append(subprocess.run(command + ["--header", "Expect:", "--data-binary", "@-", url],
                                      input=b"u" * (2 * 1024 * 1024), capture_output=True))
        results.append(subprocess.run(command + [url], capture_output=True))

    worker = threading.Thread(target=transfer, daemon=True)
    worker.start()
    samples = []
    deadline = time.monotonic() + 4
    try:
        while time.monotonic() < deadline:
            samples.append(traffic(child))
            time.sleep(0.1)
    finally:
        worker.join(timeout=12)
    assert len(results) == 2 and all(r.returncode == 0 for r in results), [r.stderr for r in results]
    assert any(s["up"] > 0 for s in samples), "No upload rate was reported"
    assert any(s["down"] > 0 for s in samples), "No download rate was reported"
    assert samples[-1]["upTotal"] - before["upTotal"] >= 2 * 1024 * 1024
    assert samples[-1]["downTotal"] - before["downTotal"] >= 2 * 1024 * 1024
    assert samples[-1]["up"] == 0 and samples[-1]["down"] == 0, "Idle rates did not return to zero"


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("helper", type=pathlib.Path)
    parser.add_argument("--lan-host", help="Also test the Mac's LAN interface address")
    args = parser.parse_args()
    origin = http.server.ThreadingHTTPServer(("127.0.0.1", 0), Origin)
    threading.Thread(target=origin.serve_forever, daemon=True).start()
    try:
        with tempfile.TemporaryDirectory(prefix="hako-proxy-test-") as directory:
            port = free_port()
            for attempt in range(2):
                child, reply, suppressed_port = launch(args.helper.resolve(), directory, port)
                try:
                    assert not reply.get("error"), reply
                    status = json.loads(reply["status"])
                    assert status["enabled"] and status["port"] == port, status
                    assert status["authenticationRequired"], status
                    assert set(status["protocols"]) == {"http", "socks5"}, status
                    for scheme in ["http", "socks5h"]:
                        result = request(port, origin.server_port, scheme)
                        assert result.returncode == 0 and result.stdout == b"hako-local-proxy-test", result.stderr
                        rejected = request(port, origin.server_port, scheme, password="wrong")
                        assert rejected.returncode != 0, "Invalid credentials were accepted"
                    with socket.socket() as probe:
                        assert probe.connect_ex(("127.0.0.1", suppressed_port)) != 0, "Profile listener was exposed"
                    if attempt == 0:
                        other, conflict, _ = launch(args.helper.resolve(), directory, port)
                        try:
                            assert conflict.get("error") == "portInUse", conflict
                        finally:
                            close(other)
                        other, conflict, _ = launch(args.helper.resolve(), directory, port, anonymous=True)
                        try:
                            assert conflict.get("error") == "portInUse", conflict
                        finally:
                            close(other)
                        print("PASS: HTTP/SOCKS5 forwarding, authentication and port conflict", flush=True)
                        test_traffic(child, port, origin.server_port, anonymous=False)
                        print("PASS: authenticated upload/download rates, totals and idle reset", flush=True)
                        if args.lan_host:
                            for scheme in ["http", "socks5h"]:
                                result = request(port, origin.server_port, scheme, host=args.lan_host)
                                assert result.returncode == 0 and result.stdout == b"hako-local-proxy-test", result.stderr
                            print("PASS: HTTP/SOCKS5 through the Mac's LAN address", flush=True)
                finally:
                    close(child)
                with socket.socket() as probe:
                    assert probe.connect_ex(("127.0.0.1", port)) != 0, "Proxy listener survived shutdown"
            print("PASS: EOF shutdown, port release and restart", flush=True)
            child, reply, _ = launch(args.helper.resolve(), directory, port, rule="MATCH,REJECT")
            try:
                assert not reply.get("error"), reply
                for scheme in ["http", "socks5h"]:
                    assert request(port, origin.server_port, scheme).returncode != 0, "Profile routing was bypassed"
            finally:
                close(child)
            print("PASS: selected profile's REJECT rule is enforced", flush=True)
            providers = pathlib.Path(directory) / "providers"
            providers.mkdir()
            (providers / "nodes.yaml").write_text(json.dumps({"proxies": [{"name": "file-direct", "type": "direct"}]}))
            extra = {"proxy-providers": {"local": {"type": "file", "path": "providers/nodes.yaml"}},
                     "proxy-groups": [{"name": "Chosen", "type": "select", "use": ["local"]}]}
            child, reply, _ = launch(args.helper.resolve(), directory, port, rule="MATCH,Chosen", extra=extra)
            try:
                assert not reply.get("error"), reply
                for scheme in ["http", "socks5h"]:
                    result = request(port, origin.server_port, scheme)
                    assert result.returncode == 0 and result.stdout == b"hako-local-proxy-test", result.stderr
            finally:
                close(child)
            print("PASS: relative file provider and selected proxy group", flush=True)
            # Empty fields explicitly override any credentials in the profile.
            child, reply, _ = launch(args.helper.resolve(), directory, port, anonymous=True,
                                     extra={"authentication": ["old:password"]})
            try:
                assert not reply.get("error"), reply
                status = json.loads(reply["status"])
                assert status["enabled"] and not status["authenticationRequired"], status
                for host in ["127.0.0.1"] + ([args.lan_host] if args.lan_host else []):
                    for scheme in ["http", "socks5h"]:
                        result = request(port, origin.server_port, scheme, host=host, anonymous=True)
                        assert result.returncode == 0 and result.stdout == b"hako-local-proxy-test", result.stderr
                with socket.create_connection(("127.0.0.1", port), timeout=3) as sock:
                    sock.sendall(bytes([5, 1, 0]))
                    assert sock.recv(2) == bytes([5, 0]), "SOCKS5 did not select no-authentication"
                test_traffic(child, port, origin.server_port, anonymous=True)
            finally:
                close(child)
            with socket.socket() as probe:
                assert probe.connect_ex(("127.0.0.1", port)) != 0, "Anonymous listener survived shutdown"
            print("PASS: anonymous HTTP/SOCKS5, profile credential override, LAN access and shutdown", flush=True)
            test_global_routing(args.helper.resolve(), directory, port, origin.server_port)
    finally:
        origin.shutdown()
        origin.server_close()


if __name__ == "__main__":
    main()
