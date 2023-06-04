import argparse
import datetime
import json
import socket

import whisper_timestamped

import generate


def server(port):
    HOST = "127.0.0.1"
    PORT = port or 65432

    print("Loading model: ", datetime.datetime.now())
    whisper_model = whisper_timestamped.load_model("medium")
    print("Model loaded")
    print("Starting server")

    server_socket = socket.socket()
    server_socket.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
    server_socket.bind((HOST, PORT))

    server_socket.listen()
    while True:
        conn, _ = server_socket.accept()
        data = conn.recv(1024).decode()
        jsondata = json.loads(data)
        client(whisper_model, jsondata)
        conn.send("done".encode())
        conn.close()


def client(model, args):
    print("running client")
    generate.main(model, args)


def main():
    parser = argparse.ArgumentParser(prog="Subtitle Retimer")
    parser.add_argument("-p", "--port")
    cmd_args = parser.parse_args()
    port = int(cmd_args.port) if cmd_args.port else None
    server(port)


if __name__ == "__main__":
    main()
