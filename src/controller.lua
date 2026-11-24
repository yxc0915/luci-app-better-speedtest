module("luci.controller.speedtest", package.seeall)

local http = require "luci.http"
local util = require "luci.util"
local runner = "/usr/libexec/luci-speedtest/runner"
local route = { "admin", "network", "speedtest" }
local sources = { auto = true, cnspeed = true, cdn = true, ookla = true }
local modes = { both = true, down = true, up = true }
local durations = { ["5"] = true, ["10"] = true, ["15"] = true, ["30"] = true }
local concurrency = { ["1"] = true, ["2"] = true, ["4"] = true, ["8"] = true }

function index()
	entry(route, template("speedtest/index"), _("网络测速"), 60)
	for _, name in ipairs({"status", "start", "stop", "log", "errlog", "nodes", "ip", "version"}) do
		local action = (name == "start" or name == "stop") and post or call
		local page = entry({ route[1], route[2], route[3], name }, action("action_" .. name))
		page.leaf = true
	end
end

local function respond(content_type, value)
	http.header("Cache-Control", "no-store")
	http.prepare_content(content_type .. "; charset=utf-8")
	http.write(value)
end

local function invoke(content_type, ...)
	local command = { runner }
	for _, arg in ipairs({...}) do
		command[#command + 1] = "'" .. arg:gsub("'", "'\\''") .. "'"
	end
	local result = util.exec(table.concat(command, " ")) or ""
	if result == "" and content_type == "application/json" then
		result = '{"ok":false,"error":"测速核心没有返回数据"}'
	end
	respond(content_type, result)
end

local function json(...)
	invoke("application/json", ...)
end

local function plain(...)
	invoke("text/plain", ...)
end

function action_start()
	local source = http.formvalue("src") or "auto"
	local mode = http.formvalue("mode") or "both"
	local duration = http.formvalue("dur") or "10"
	local multi = http.formvalue("multi") or "1"
	local node = (http.formvalue("node") or ""):match("^%s*(.-)%s*$")
	if not sources[source] or not modes[mode] or not durations[duration] or not concurrency[multi]
		or not node or #node > 480 or node:match("^%-") or node:find("[%z\1-\31\127]") then
		http.status(400, "Bad Request")
		respond("application/json", '{"ok":false,"error":"测速参数无效"}')
		return
	end
	json("start", source, mode, duration, multi, node)
end

function action_nodes()
	local source = http.formvalue("src") or "all"
	local full = source == "cnspeed" and http.formvalue("full") == "1"
	json("nodes", sources[source] and source ~= "auto" and source or "all", full and "full" or "nearby")
end

function action_status() json("status") end
function action_stop() json("stop") end
function action_ip() json("ip") end
function action_log() plain("log") end
function action_errlog() plain("errlog") end
function action_version() plain("version") end
