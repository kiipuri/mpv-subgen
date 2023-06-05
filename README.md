# mpv-subgen

mpv-subgen lets you generate subtitles on the fly with mpv. It uses [whisper](https://github.com/openai/whisper) to transcribe speech to text.

## Requirements

- Python3
- Pip
- Lua 5.1

## Installation

### Manual installation

Clone this repository to the `scripts` directory:

```
git clone https://github.com/kiipuri/mpv-subgen.git ~/.config/mpv/scripts/subgen
```

Install pip dependencies:

```
pip3 install -r requirements.txt
```

mpv uses Lua 5.1, so you need to install `luasocket` for the same version.

1. Install [LuaRocks](https://luarocks.org/)
2. Install luasocket

```
sudo luarocks --lua-version 5.1 install luasocket
```

## Usage

After mpv is opened, mpv starts the socket server which loads the whisper model.
When user presses `gen_key` (see [configuration](#configuration)), the server starts a client that generates subtitles from the current time position to 1 minute onwards by default.
By using the server, the whisper model is always loaded and makes generating subtitles take less time.

## Configuration

You can configure the behaviour of mpv-subgen by creating a config file.
The config file needs to be in mpv's `script-opts` directory and be named `subgen.conf`.

You can set the following options:

- `port` - the port in which the socket server runs on
- `gen_key` - the keybind which starts generating subtitles
- `model` - the `whisper` model to use

Default configuration:

```
port=65432
gen_key=ctrl+x
model=medium
```
