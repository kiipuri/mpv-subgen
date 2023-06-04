local mp = require("mp")
local msg = require("mp.msg")

local function main()
	-- Make sure only one server runs
	local pgrep_cmd =
		string.format('pgrep -f "python %s/server.py"', mp.get_script_directory(), mp.get_script_directory())
	local is_running = io.popen(pgrep_cmd):read()
	if is_running ~= nil then
		return
	end

	local opt = require("mp.options")
	local options = {
		port = 65432,
		gen_key = "ctrl+x",
	}
	opt.read_options(options, "subgen")

	local server =
		string.format("setsid python '%s/server.py' --port %s >> /dev/null &", mp.get_script_directory(), options.port)
	io.popen(server)

	local function kill_server()
		print("Killing server")
		local cmd =
			string.format('pkill -f "python %s/server.py"', mp.get_script_directory(), mp.get_script_directory())
		io.popen(cmd)
	end

	mp.register_event("end-file", kill_server)

	local socket = require("socket")
	local function send_req()
		local cwd = mp.get_property("working-directory") .. "/"
		local tcp = assert(socket.tcp())

		tcp:connect("127.0.0.1", options.port)

		local data = string.format(
			'{"video": "%s", "subtitles": "%s", "start": "%s"}',
			cwd .. mp.get_property("filename"),
			cwd .. mp.get_property("current-tracks/sub/title"),
			mp.get_property_number("time-pos")
		)

		local ok, err = tcp:send(data)

		if ok then
			msg.info("Start retiming")
			mp.osd_message("Start retiming")
		end

		if err then
			msg.info("Server not running")
			mp.osd_message("Server not running")
		end

		while true do
			local s, status, partial = tcp:receive()
			if s or partial == "done" then
				mp.commandv("sub-reload")
				msg.info("Subtitles retimed")
				mp.osd_message("Subtitles retimed")
			end
			if status == "closed" then
				break
			end
		end
	end

	mp.add_key_binding(options.gen_key, send_req)
end

mp.register_event("file-loaded", main)
