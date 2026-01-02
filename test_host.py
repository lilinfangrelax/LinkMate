import sys
import struct
import json
import subprocess
import os
import time

# Configuration
# Path to the compiled executable or running via flutter command
# Running via 'flutter run' is tricky for stdin piping usually.
# Better to build the executable for testing or use 'dart run' if possible.
# For this verify script, we will try to run 'flutter run -d windows' which might launch a window.
# Actually, for a console app, 'dart run lib/main.dart' is much simpler for testing logic.

FLUTTER_APP_PATH = os.path.join("app", "lib", "main.dart")
WORKING_DIR = os.path.join(os.getcwd(), "app")

def send_message(proc, message):
    # Encode message
    json_str = json.dumps(message)
    json_bytes = json_str.encode('utf-8')
    
    # Header: 4 bytes length, little-endian
    header = struct.pack('<I', len(json_bytes))
    
    # Send
    proc.stdin.write(header)
    proc.stdin.write(json_bytes)
    proc.stdin.flush()

def main():
    print(f"Starting Dart Native Host from: {FLUTTER_APP_PATH}")
    
    # Use the compiled executable for reliable testing
    host_exe = os.path.join(WORKING_DIR, "host.exe")
    cmd = [host_exe]
    
    try:
        proc = subprocess.Popen(
            cmd, 
            cwd=WORKING_DIR,
            stdin=subprocess.PIPE, 
            stdout=sys.stdout, 
            stderr=sys.stderr
        )
    except FileNotFoundError:
        print("Error: 'dart' command not found. Make sure Dart SDK is in PATH.")
        return

    # Simulate a TABS_SYNC message
    msg = {
        "type": "TABS_SYNC",
        "browser": "test-script",
        "timestamp": int(time.time() * 1000),
        "data": {
            "tabs": [
                {"tabId": 1, "title": "Test Tab 1", "url": "http://example.com/1"},
                {"tabId": 2, "title": "Flutter Dev", "url": "https://flutter.dev"}
            ],
            "groups": []
        }
    }

    print("Sending TABS_SYNC message...")
    send_message(proc, msg)
    
    # Keep it open for a moment
    time.sleep(2)
    
    print("Closing...")
    proc.terminate()

if __name__ == "__main__":
    main()
