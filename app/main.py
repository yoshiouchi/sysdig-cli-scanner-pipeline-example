from flask import Flask, jsonify

app = Flask(__name__)

@app.get("/")
def root():
    return jsonify(message="Hello, Sysdig CLI Scanner 👋")

if __name__ == "__main__":
    # For local testing only; CI will run this in a container
    app.run(host="0.0.0.0", port=8000)
