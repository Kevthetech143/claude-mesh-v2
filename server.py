#!/usr/bin/env python3
"""Claude Mesh — Message server for a single agent inbox.

Usage:
    python3 server.py --port 9997 --name alpha
    python3 server.py --port 9998 --name beta
"""
import argparse
import json
import os
from datetime import datetime
from flask import Flask, request, jsonify

parser = argparse.ArgumentParser(description="Claude Mesh inbox server")
parser.add_argument("--port", type=int, required=True, help="Port to listen on")
parser.add_argument("--name", required=True, help="Agent name (alpha/beta)")
parser.add_argument("--runtime-dir", default=None, help="Directory for inbox JSON files")
args = parser.parse_args()

MESH_DIR = os.path.dirname(os.path.abspath(__file__))
RUNTIME_DIR = args.runtime_dir or os.path.join(MESH_DIR, "runtime")
INBOX_FILE = os.path.join(RUNTIME_DIR, f"inbox-{args.name}.json")

app = Flask(__name__)
messages = []
next_id = 1

@app.route('/api/submit', methods=['POST'])
def submit():
    global next_id
    data = request.json
    data['received_at'] = datetime.utcnow().isoformat()
    data['id'] = next_id
    next_id += 1
    messages.append(data)
    with open(INBOX_FILE, 'w') as f:
        json.dump(messages, f, indent=2)
    return jsonify({"id": data['id'], "status": "queued"})

@app.route('/api/latest', methods=['GET'])
def get_latest():
    return jsonify(messages[-1] if messages else {})

@app.route('/api/all', methods=['GET'])
def get_all():
    since = request.args.get('since', type=int)
    if since is not None:
        return jsonify([m for m in messages if m['id'] > since])
    return jsonify(messages)

if __name__ == '__main__':
    app.run(host='127.0.0.1', port=args.port)
