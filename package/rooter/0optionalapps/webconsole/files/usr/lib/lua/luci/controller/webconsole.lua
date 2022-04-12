-- A simple web console in case you don't have access to the shell
-- 
-- Hua Shao <nossiac@163.com>

module("luci.controller.webconsole", package.seeall)
local http = require("luci.http")
local I18N = require "luci.i18n"
local translate = I18N.translate
function index()
    entry({"admin", "system", "console"}, template("web/web_console"), _(translate("Web Console")), 66)
    entry({"admin", "system", "webcmd"}, call("action_webcmd"))
end

function action_webcmd()
    local cmd = http.formvalue("cmd")
    if cmd then
	    local fp = io.popen(tostring(cmd).." 2>&1")
	    local result =  fp:read("*a")
	    fp:close()
        result = result:gsub("<", "&lt;")
        http.write(tostring(result))
    else
        http.write_json(http.formvalue())
    end
end
