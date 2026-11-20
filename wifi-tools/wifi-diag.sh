#!/bin/bash
# wifi-diag.sh — READ-ONLY Wi-Fi diagnostics for macOS.
# Changes nothing. Writes a report to ~/Desktop/wifi-report-<time>.txt
# Usage:  bash wifi-diag.sh
# (Some sections show more detail with sudo, but sudo is NOT required.)

REPORT="$HOME/Desktop/wifi-report-$(date +%Y%m%d-%H%M%S).txt"
exec > >(tee "$REPORT") 2>&1

FINDINGS=""
flag() { FINDINGS="${FINDINGS}  - $1\n"; }
hdr()  { printf '\n==================== %s ====================\n' "$1"; }
run()  { printf '\n$ %s\n' "$*"; "$@" 2>&1; }

# ---------- 1. System ----------
hdr "1. macOS version"
run sw_vers
run uname -m

# ---------- 2. Interfaces ----------
hdr "2. Hardware ports & service order"
run networksetup -listallhardwareports
run networksetup -listnetworkserviceorder

WIFI_IF=$(networksetup -listallhardwareports | awk '/Hardware Port: (Wi-Fi|AirPort)/{getline; print $2; exit}')
WIFI_SVC=$(networksetup -listnetworkserviceorder | awk -v ifc="$WIFI_IF" '
  /^\([0-9*]+\)/ {name=$0; sub(/^\([0-9*]+\) /,"",name)}
  $0 ~ "Device: "ifc"\\)" {print name; exit}')
[ -z "$WIFI_SVC" ] && WIFI_SVC="Wi-Fi"
echo
echo "Wi-Fi interface: ${WIFI_IF:-NOT FOUND}   Service name: $WIFI_SVC"
if [ -z "$WIFI_IF" ]; then
  flag "NO Wi-Fi hardware port detected — adapter not recognised by macOS (hardware/driver issue)."
fi

# ---------- 3. Wi-Fi power & radio ----------
hdr "3. Wi-Fi power, radio and adapter"
run networksetup -getairportpower "$WIFI_IF"
networksetup -getairportpower "$WIFI_IF" 2>/dev/null | grep -q ": Off" && flag "Wi-Fi radio is OFF."
run ifconfig "$WIFI_IF"
ifconfig "$WIFI_IF" 2>/dev/null | grep -q "status: inactive" && flag "Wi-Fi interface is INACTIVE (not associated with any network)."
echo
echo "--- Adapter / current connection (system_profiler) ---"
system_profiler SPAirPortDataType 2>/dev/null | sed -n '1,/Other Local Wi-Fi Networks/p'
SIGNAL=$(system_profiler SPAirPortDataType 2>/dev/null | awk -F'[:/ ]+' '/Signal \/ Noise/{print $4; exit}')
NOISE=$(system_profiler SPAirPortDataType 2>/dev/null | awk -F'[:/ ]+' '/Signal \/ Noise/{print $7; exit}')
if [ -n "$SIGNAL" ]; then
  echo "Parsed RSSI: $SIGNAL dBm  Noise: $NOISE dBm"
  [ "$SIGNAL" -lt -75 ] 2>/dev/null && flag "Weak signal (RSSI $SIGNAL dBm). Below -75 dBm causes drops/slowness."
fi

# ---------- 4. IP / DHCP ----------
hdr "4. IP address and DHCP"
IP=$(ipconfig getifaddr "$WIFI_IF" 2>/dev/null)
echo "IPv4 on $WIFI_IF: ${IP:-NONE}"
run networksetup -getinfo "$WIFI_SVC"
run ipconfig getpacket "$WIFI_IF"
if [ -z "$IP" ]; then
  flag "No IPv4 address on $WIFI_IF (DHCP failed or not connected)."
elif echo "$IP" | grep -q '^169\.254\.'; then
  flag "Self-assigned IP $IP — DHCP server did not answer (router/DHCP problem or IP conflict)."
fi
networksetup -getinfo "$WIFI_SVC" 2>/dev/null | grep -q "^Manual Configuration" && \
  flag "Wi-Fi uses a MANUAL IP configuration (not DHCP) — a wrong static IP/gateway is a common cause."

# ---------- 5. Routing ----------
hdr "5. Routing table"
run netstat -rn -f inet
run route -n get default
GW=$(route -n get default 2>/dev/null | awk '/gateway:/{print $2}')
DEF_IF=$(route -n get default 2>/dev/null | awk '/interface:/{print $2}')
echo "Default gateway: ${GW:-NONE} via ${DEF_IF:-?}"
[ -z "$GW" ] && flag "No default route/gateway."
if [ -n "$DEF_IF" ] && [ "$DEF_IF" != "$WIFI_IF" ]; then
  flag "Default route goes via $DEF_IF, not Wi-Fi ($WIFI_IF) — VPN or another interface is taking traffic."
fi

# ---------- 6. DNS ----------
hdr "6. DNS configuration"
run networksetup -getdnsservers "$WIFI_SVC"
run networksetup -getsearchdomains "$WIFI_SVC"
scutil --dns 2>/dev/null | sed -n '1,40p'
if [ -d /etc/resolver ]; then echo; echo "Custom /etc/resolver entries:"; ls -l /etc/resolver; fi

# ---------- 7. Proxy ----------
hdr "7. Proxy settings"
run scutil --proxy
run networksetup -getwebproxy "$WIFI_SVC"
run networksetup -getsecurewebproxy "$WIFI_SVC"
run networksetup -getsocksfirewallproxy "$WIFI_SVC"
run networksetup -getautoproxyurl "$WIFI_SVC"
run networksetup -getproxyautodiscovery "$WIFI_SVC"
scutil --proxy 2>/dev/null | grep -Eq '(HTTPEnable|HTTPSEnable|SOCKSEnable|ProxyAutoConfigEnable) : 1' && \
  flag "A proxy (HTTP/HTTPS/SOCKS/PAC) is ENABLED — verify it is intentional."

# ---------- 8. VPN / tunnels / filters ----------
hdr "8. VPN, tunnels and network extensions"
run scutil --nc list
echo
echo "utun/ipsec/ppp interfaces with an IPv4 address:"
ifconfig 2>/dev/null | awk '/^(utun|ipsec|ppp)[0-9]+:/{i=$1} /inet /{if(i!=""){print i, $2}} /^[a-z]/{if($1!~/^(utun|ipsec|ppp)/)i=""}'
scutil --nc list 2>/dev/null | grep -q "(Connected)" && flag "A VPN connection is CONNECTED."
echo
echo "Running VPN/firewall/filter apps (name match):"
ps -axo comm | grep -iE 'vpn|tunnelblick|wireguard|openvpn|globalprotect|anyconnect|forticlient|zscaler|nordvpn|expressvpn|littlesnitch|lulu|cloudflare|warp|tailscale|proton' | sort -u
echo
echo "Network extensions (content filters / VPN plug-ins):"
systemextensionsctl list 2>/dev/null | grep -iE 'network|filter|vpn|enabled' | head -20

# ---------- 9. IP conflict / DHCP logs ----------
hdr "9. Recent IP conflict / DHCP / Wi-Fi errors (last 60 min)"
log show --last 60m --style compact \
  --predicate 'subsystem == "com.apple.IPConfiguration" OR process == "configd"' 2>/dev/null \
  | grep -iE 'conflict|in use|duplicate|DHCP.*(fail|timeout|NAK)|lease' | tail -25
log show --last 60m --style compact --predicate 'subsystem == "com.apple.IPConfiguration"' 2>/dev/null \
  | grep -qiE 'conflict|already in use' && flag "macOS logged an IP ADDRESS CONFLICT."
echo
echo "--- Wi-Fi driver/association messages ---"
log show --last 60m --style compact --predicate 'subsystem == "com.apple.wifi" OR process == "airportd"' 2>/dev/null \
  | grep -iE 'error|fail|deauth|disassoc|timeout|reset|firmware' | tail -30

# ---------- 10. Connectivity tests ----------
hdr "10. Connectivity tests"
GW_OK=no; NET_OK=no; DNS_OK=no; HTTP_OK=no
if [ -n "$GW" ]; then
  run ping -c 4 -t 6 "$GW" && GW_OK=yes
fi
run ping -c 4 -t 6 1.1.1.1 && NET_OK=yes
[ "$NET_OK" = no ] && { run ping -c 4 -t 6 8.8.8.8 && NET_OK=yes; }
run dscacheutil -q host -a name apple.com
dscacheutil -q host -a name apple.com 2>/dev/null | grep -q 'ip_address' && DNS_OK=yes
echo
echo "Resolve via system DNS vs a public resolver directly:"
run nslookup -timeout=3 apple.com
run nslookup -timeout=3 apple.com 1.1.1.1
echo
CAPTIVE=$(curl -s --max-time 6 http://captive.apple.com/hotspot-detect.html)
echo "captive.apple.com returned: $(echo "$CAPTIVE" | tr -d '\n' | cut -c1-120)"
echo "$CAPTIVE" | grep -q "Success" && HTTP_OK=yes
run curl -sS -o /dev/null -w 'HTTPS apple.com -> %{http_code} in %{time_total}s\n' --max-time 8 https://www.apple.com

# ---------- Summary ----------
hdr "SUMMARY"
echo "Gateway reachable : $GW_OK"
echo "Internet by IP    : $NET_OK"
echo "DNS resolution    : $DNS_OK"
echo "HTTP (captive chk): $HTTP_OK"

[ -n "$GW" ] && [ "$GW_OK" = no ] && flag "Router ($GW) does not answer ping (Wi-Fi link/association problem — or router blocks ping)."
[ "$GW_OK" = yes ] && [ "$NET_OK" = no ] && flag "Router reachable but internet is NOT — problem is upstream (router/ISP), not the Mac."
[ "$NET_OK" = yes ] && [ "$DNS_OK" = no ] && flag "Internet works by IP but DNS FAILS — DNS problem (fixable on the Mac)."
[ "$NET_OK" = yes ] && [ "$DNS_OK" = yes ] && [ "$HTTP_OK" = no ] && \
  flag "IP + DNS fine but web check failed — captive portal (hotel/café login), proxy, or content filter."

echo
if [ -n "$FINDINGS" ]; then
  echo "FINDINGS:"; printf "$FINDINGS"
else
  echo "No problems detected at this moment. If the issue is intermittent, run again while it is failing."
fi
echo
echo "Report saved to: $REPORT"
