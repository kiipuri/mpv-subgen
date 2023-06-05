import argparse
import json
import socket

import whisper_timestamped

import generate


def server(port, model):
    HOST = "127.0.0.1"
    PORT = port or 65432

    print("Loading model")
    whisper_model = whisper_timestamped.load_model(model)
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
    parser = argparse.ArgumentParser(prog="Subtitle Generator")
    parser.add_argument("-p", "--port")
    parser.add_argument("-m", "--model")
    cmd_args = parser.parse_args()
    port = int(cmd_args.port) if cmd_args.port else None
    server(port, cmd_args.model)


if __name__ == "__main__":
    main()
