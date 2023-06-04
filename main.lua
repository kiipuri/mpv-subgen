local mp = require("mp")
local msg = require("mp.msg")

local function main()
	local opt = require("mp.options")
	local options = {
		port = 65432,
		gen_key = "ctrl+x",
	}
	opt.read_options(options, "subgen")

	-- Make sure only one server runs
	local pgrep_cmd =
		string.format('pgrep -f "python %s/server.py"', mp.get_script_directory(), mp.get_script_directory())
	local is_running = io.popen(pgrep_cmd):read()
	if not is_running then
		local server = string.format(
			"setsid python '%s/server.py' --port %s > /dev/null &",
			mp.get_script_directory(),
			options.port
		)
		io.popen(server)
	end

	local function kill_server()
		print("Killing server")
		local cmd =
			string.format('pkill -f "python %s/server.py"', mp.get_script_directory(), mp.get_script_directory())
		io.popen(cmd)
	end

	mp.register_event("end-file", kill_server)

	local socket = require("socket")
	local function send_req()
		-- Return if current subtitles are embedded
		local is_subs_external = mp.get_property("current-tracks/sub/external")
		local is_subtitle = mp.get_property("current-tracks/sub")
		if is_subs_external == "no" and is_subtitle then
			msg.info("Selected subtitles are embedded")
			mp.osd_message("Selected subtitles are embedded")
			return
		end

		local cwd = mp.get_property("working-directory") .. "/"
		local tcp = assert(socket.tcp())

		local sub_filename
		if not is_subtitle then
			sub_filename = mp.get_property("filename")
			sub_filename = sub_filename:match(".*%.") .. "srt"
			io.open(cwd .. sub_filename, "w"):close()
		else
			sub_filename = mp.get_property("current-tracks/sub/title")
		end

		tcp:connect("127.0.0.1", options.port)

		local data = string.format(
			'{"video": "%s", "subtitles": "%s", "start": "%s", "audio": "%s"}',
			cwd .. mp.get_property("filename"),
			cwd .. sub_filename,
			mp.get_property_number("time-pos"),
			tonumber(mp.get_property_number("current-tracks/audio/src-id")) - 1
		)

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
				mp.commandv("sub-add", sub_filename)
				mp.commandv("sub-reload")
				msg.info("Subtitles generated")
				mp.osd_message("Subtitles generated")
			end
			if status == "closed" then
				break
			end
		end
	end

	mp.add_key_binding(options.gen_key, send_req)
end

mp.register_event("file-loaded", main)
