# Local server

In your real Python server directory, with its dependencies/environment ready and `ROBOFLOW_API_KEY` set in the environment, start:

```sh
uvicorn api:app --host 0.0.0.0 --port 8000
```

Keep the key out of this repository. The `reference/pipeline/` copy is read-only; do not run the server from it.

Find the PC's active Wi-Fi/Ethernet IPv4 address: use `ipconfig` on Windows, `ip -4 addr` on Linux, or Network settings on macOS. Choose the LAN interface's address, not loopback, VPN or a virtual adapter. Enter `http://<PC-LAN-IP>:8000` in the app's Settings and Save. The default `http://192.168.1.100:8000` is only a starting value.

Allow inbound TCP **port 8000** through the PC firewall on the private/LAN network.

On the Pixel 6a:

- Connect to the same Wi-Fi/LAN as the PC. Guest Wi-Fi or router **client isolation** can block access even when both devices appear connected.
- Turn off any phone **VPN** while testing.

Open `http://<PC-LAN-IP>:8000/docs` in the phone browser to check reachability, then test the app with “Use mock server” unchecked. Mock mode is persisted by this skeleton; its server implementation comes later.
