import os
from flask import Flask, jsonify
import psycopg2

app = Flask(__name__)

def db_ok():
    try:
        conn = psycopg2.connect(os.environ["DATABASE_URL"], connect_timeout=3)
        conn.close()
        return True
    except Exception:
        return False

@app.route("/")
def index():
    return jsonify(message="DevOps trainee app running", db_connected=db_ok())

@app.route("/health")
def health():
    return jsonify(status="ok"), 200

if __name__ == "__main__":
    app.run(host="0.0.0.0", port=5000)
