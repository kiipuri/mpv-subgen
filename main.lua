local mp = require("mp")
local msg = require("mp.msg")
local socket = require("socket")

local function start_server(options)
    -- Make sure only one server runs
    local pgrep_cmd =
        string.format('pgrep -f "python %s/server.py"', mp.get_script_directory(), mp.get_script_directory())
    local is_running = io.popen(pgrep_cmd):read()
    if not is_running then
        local server = string.format(
            "setsid python '%s/server.py' --port %s --model %s > /dev/null &",
            mp.get_script_directory(),
            options.port,
            options.model
        )
        io.popen(server)
    end
end

local function kill_server()
    print("Killing server")
    local cmd = string.format('pkill -f "python %s/server.py"', mp.get_script_directory(), mp.get_script_directory())
    io.popen(cmd)
end

local function prepare_req(process_full)
    -- Return if current subtitles are embedded
    local is_subs_external = mp.get_property("current-tracks/sub/external")
    local is_subtitle = mp.get_property("current-tracks/sub")
    if is_subs_external == "no" and is_subtitle then
        msg.info("Selected subtitles are embedded")
        mp.osd_message("Selected subtitles are embedded")
        return
    end

    local cwd = mp.get_property("working-directory") .. "/"

    local sub_filename
    if not is_subtitle then
        sub_filename = mp.get_property("filename")
        sub_filename = sub_filename:match(".*%.") .. "srt"
        io.open(cwd .. sub_filename, "w"):close()
    else
        sub_filename = mp.get_property("current-tracks/sub/title")
    end

    local start_pos, end_pos
    if process_full then
        start_pos = 0
        end_pos = mp.get_property_number("duration")
    else
        start_pos = mp.get_property_number("time-pos")
        end_pos = start_pos + 60
    end

    local data = string.format(
        '{"video": "%s", "subtitles": "%s", "start": "%s", "end": "%s", "audio": "%s"}',
        cwd .. mp.get_property("filename"),
        cwd .. sub_filename,
        start_pos,
        end_pos,
        tonumber(mp.get_property_number("current-tracks/audio/id")) - 1
    )

    return data, sub_filename
end

local function send_req(options, process_full)
    local data, sub_filename = prepare_req(process_full)
    if not data then
        return
    end

    local tcp = assert(socket.tcp())
    tcp:connect("127.0.0.1", options.port)

    local ok, err = tcp:send(data)

    if ok then
        msg.info("Start generating")
        mp.osd_message("Start generating")
    end

    if err then
        msg.info("Server not running")
        mp.osd_message("Server not running")
    end

    while true do
        local s, status, partial = tcp:receive()
        if s or partial == "done" then
            mp.commandv("sub-add", sub_filename, "cached")
            mp.commandv("sub-reload")
            msg.info("Subtitles generated")
            mp.osd_message("Subtitles generated")
        end
        if status == "closed" then
            break
        end
    end
end

local function main()
    local opt = require("mp.options")
    local options = {
        port = 65432,
        gen_key = "ctrl+x",
        gen_key_full = "ctrl+X",
        model = "medium",
    }
    opt.read_options(options, "subgen")

    start_server(options)

    mp.register_event("end-file", kill_server)

    mp.add_key_binding(options.gen_key, function()
        send_req(options, false)
    end)

    mp.add_key_binding(options.gen_key_full, function()
        send_req(options, true)
    end)
end

mp.register_event("file-loaded", main)
