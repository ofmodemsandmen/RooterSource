require("luci.ip")
require("luci.model.uci")

--luci.sys.call("/usr/lib/wireguard/keygen.sh " .. arg[1])

local m = Map("wireguard", translate("Wireguard Client"), translate("Set up a Wireguard Client"))

e = m:section(NamedSection, "settings", "")

m.on_init = function(self)
	--luci.sys.call("/usr/lib/wireguard/keygen.sh " .. arg[1])
end

btn = e:option(Button, "_btn", translate(" "))
btn.inputtitle = translate("Back to Main Page")
btn.inputstyle = "apply"
btn.redirect = luci.dispatcher.build_url(
	"admin", "vpn", "wireguard"
)
function btn.write(self, section, value)
	luci.http.redirect( self.redirect )
end


local s = m:section( NamedSection, arg[1], "wireguard", translate("Client") )

ip = s:option(Value, "addresses", translate("IP Addresses :"), translate("Comma separated list of IP Addresses that server will accept from this client")); 
ip.rmempty = true;
ip.optional=false;
ip.default="10.14.0.2/24";

port = s:option(Value, "port", translate("Listen Port :"), translate("Client Listen Port")); 
port.rmempty = true;
port.optional=false;
port.default="51820";

ul = s:option(ListValue, "udptunnel", "Enable UDP over TCP :");
ul:value("0", "No")
ul:value("1", "Yes")
ul.default=0

dns = s:option(Value, "dns", translate("DNS Servers :"), translate("Comma separated list of DNS Servers.")); 
dns.rmempty = true;
dns.optional=false;
dns.default="8.8.8.8";

mtu = s:option(Value, "mtu", translate("MTU :"), translate("Maximum MTU")); 
mtu.rmempty = true;
mtu.optional=false;
mtu.datatype = 'range(1280,1420)';
mtu.default="1280";

pkey = s:option(Value, "privatekey", translate("Private Key :"), translate("Private Key supplied by the Server")); 
pkey.rmempty = true;
pkey.optional=false;

bl = s:option(ListValue, "auto", "Start on Boot :");
bl:value("0", "No")
bl:value("1", "Yes")
bl.default=0

s = m:section( NamedSection, arg[1], "wireguard", translate("Server") )

name = s:option( Value, "name", translate("Server Name :"), translate("Optional Server name"))

pukey = s:option(Value, "publickey", translate("Public Key :"), translate("Public Key of the Server")); 
pukey.rmempty = true;
pukey.optional=false;

prkey = s:option(Value, "presharedkey", translate("Presharedkey :"), translate("PreShared Key from the Server")); 
prkey.rmempty = true;
prkey.optional=false;

host = s:option(Value, "endpoint_host", translate("Server Address :"), translate("URL or IP Address of Server")); 
host.rmempty = true;
host.optional=false;
host.default="";

sport = s:option(Value, "sport", translate("Listen Port :"), translate("Server Listen Port")); 
sport.rmempty = true;
sport.optional=false;
sport.default="51820";

sip = s:option(Value, "ips", translate("Allowed IP Addresses :"), translate("Comma separated list of IP Addresses that server will accept")); 
sip.rmempty = true;
sip.optional=false;
sip.default="10.14.0.0/24";

return m