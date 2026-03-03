# Mesh Sync Skill

## Purpose
Re-establish and verify communication between ALPHA and BETA in a Claude Mesh dual-agent system.

## When to Use
- On first launch to confirm comms are live
- Anytime comms seem down or unresponsive
- After a crash, restart, or reconnect
- When the user says "run sync", "sync up", "check comms"

## How It Works

### If you are ALPHA:
1. Send a sync check to BETA:
```bash
python3 -c "import urllib.request, json; data=json.dumps({'author': 'ALPHA', 'content': 'SYNC CHECK — respond with SYNC OK'}).encode(); req=urllib.request.Request('http://localhost:9998/api/submit', data=data, headers={'Content-Type': 'application/json'}); urllib.request.urlopen(req)"
```
2. Wait 10 seconds, then check your inbox:
```bash
curl -s http://localhost:9997/api/all
```
3. Look for a message from BETA containing "SYNC OK"
4. If found → report to user: "Comms with BETA are live."
5. If not found → wait another 10 seconds and check again
6. If still nothing after 30 seconds → report to user: "BETA is not responding. Comms may be down."

### If you are BETA:
1. When you see "SYNC CHECK" in your inbox, immediately respond:
```bash
python3 -c "import urllib.request, json; data=json.dumps({'author': 'BETA', 'content': 'SYNC OK'}).encode(); req=urllib.request.Request('http://localhost:9997/api/submit', data=data, headers={'Content-Type': 'application/json'}); urllib.request.urlopen(req)"
```
2. Then say: "Synced with ALPHA. Standing by."

### Verifying the infrastructure:
If sync fails, check that the Flask servers are running:
```bash
curl -s http://localhost:9997/api/latest && echo "ALPHA inbox: UP" || echo "ALPHA inbox: DOWN"
curl -s http://localhost:9998/api/latest && echo "BETA inbox: UP" || echo "BETA inbox: DOWN"
```

## Quick Reference
| Role | Inbox Port | Sends To Port |
|------|-----------|---------------|
| ALPHA | 9997 | 9998 |
| BETA | 9998 | 9997 |
