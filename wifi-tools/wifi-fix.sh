#!/bin/bash
# wifi-fix.sh — SAFE, REVERSIBLE Wi-Fi repairs for macOS.
# Every action explains itself and asks y/N before changing anything.
# Previous settings are saved in ~/.wifi-fix/ so they can be restored.
# Never deletes saved Wi-Fi networks/passwords, never touches security settings.
#
# Usage:  bash wifi-fix.sh            (interactive menu)
#         bash wifi-fix.sh restore-dns | restore-proxy   (undo)

WIFI_IF=$(networksetup -listallhardwareports | awk '/Hardware Port: (Wi-Fi|AirPort)/{getline; print $2; exit}')
WIFI_SVC=$(networksetup -listnetworkserviceorder | awk -v ifc="$WIFI_IF" '
  /^\([0-9*]+\)/ {name=$0; sub(/^\([0-9*]+\) /,"",name)}
  $0 ~ "Device: "ifc"\\)" {print name; exit}')
[ -z "$WIFI_SVC" ] && WIFI_SVC="Wi-Fi"
[ -z "$WIFI_IF" ] && { echo "No Wi-Fi interface found. Adapter not detected: likely a hardware/driver issue (try a restart, then Apple Diagnostics)."; exit 1; }

BACKUP_DIR="$HOME/.wifi-fix"
mkdir -p "$BACKUP_DIR"

confirm() { printf '\n%s\nProceed? [y/N] ' "$1"; read -r a; [ "$a" = "y" ] || [ "$a" = "Y" ]; }

retest() {
  echo; echo "---- Re-test ----"
  sleep 3
  IP=$(ipconfig getifaddr "$WIFI_IF"); GW=$(route -n get default 2>/dev/null | awk '/gateway:/{print $2}')
  echo "IP: ${IP:-none}   Gateway: ${GW:-none}"
  [ -n "$GW" ] && { ping -c 2 -t 4 "$GW" >/dev/null 2>&1 && echo "Router:   OK" || echo "Router:   FAIL"; }
  ping -c 2 -t 4 1.1.1.1 >/dev/null 2>&1 && echo "Internet: OK" || echo "Internet: FAIL"
  dscacheutil -q host -a name apple.com | grep -q ip_address && echo "DNS:      OK" || echo "DNS:      FAIL"
  curl -s --max-time 6 http://captive.apple.com/hotspot-detect.html | grep -q Success && echo "Web:      OK" || echo "Web:      FAIL"
}

flush_dns() {
  confirm "[Flush DNS] Clears the Mac's DNS cache (dscacheutil + restart mDNSResponder). Harmless; needs your admin password." || return
  sudo dscacheutil -flushcache && sudo killall -HUP mDNSResponder && echo "DNS cache flushed."
  retest
}

renew_dhcp() {
  confirm "[Renew DHCP] Asks the router for a fresh IP lease on $WIFI_IF. Keeps your configuration; connection blips for a few seconds." || return
  echo "add State:/Network/Interface/$WIFI_IF/RefreshConfiguration temporary" | sudo scutil && echo "DHCP renew requested."
  sleep 5; retest
}

toggle_wifi() {
  confirm "[Restart Wi-Fi] Turns the Wi-Fi radio off and back on. Saved networks and passwords are untouched." || return
  networksetup -setairportpower "$WIFI_IF" off; sleep 3
  networksetup -setairportpower "$WIFI_IF" on;  echo "Wi-Fi restarted, waiting to rejoin..."
  sleep 10; retest
}

set_public_dns() {
  CUR=$(networksetup -getdnsservers "$WIFI_SVC")
  echo "Current DNS for $WIFI_SVC: $CUR"
  confirm "[Use public DNS] Sets DNS for '$WIFI_SVC' to 1.1.1.1 and 8.8.8.8. Saved backup; undo with: bash wifi-fix.sh restore-dns
Note: skip this on a work network that needs internal DNS." || return
  echo "$CUR" > "$BACKUP_DIR/dns.bak"
  sudo networksetup -setdnsservers "$WIFI_SVC" 1.1.1.1 8.8.8.8 && echo "DNS set. Backup: $BACKUP_DIR/dns.bak"
  sudo dscacheutil -flushcache; sudo killall -HUP mDNSResponder
  retest
}

restore_dns() {
  [ -f "$BACKUP_DIR/dns.bak" ] || { echo "No DNS backup found."; return; }
  if grep -q "aren't any DNS Servers" "$BACKUP_DIR/dns.bak"; then
    sudo networksetup -setdnsservers "$WIFI_SVC" Empty
  else
    sudo networksetup -setdnsservers "$WIFI_SVC" $(cat "$BACKUP_DIR/dns.bak")
  fi
  echo "DNS restored to: $(networksetup -getdnsservers "$WIFI_SVC" | tr '\n' ' ')"
}

disable_proxies() {
  echo "Current proxy state:"; scutil --proxy | grep -E 'Enable|Proxy |Port|URL'
  confirm "[Disable proxies] Turns off HTTP/HTTPS/SOCKS/auto-config (PAC) proxies on '$WIFI_SVC'. Proxy addresses are kept, only switched off.
Undo with: bash wifi-fix.sh restore-proxy.  Skip this if your employer/school requires a proxy." || return
  {
    echo "web=$(networksetup -getwebproxy "$WIFI_SVC" | awk '/^Enabled/{print $2}')"
    echo "secure=$(networksetup -getsecurewebproxy "$WIFI_SVC" | awk '/^Enabled/{print $2}')"
    echo "socks=$(networksetup -getsocksfirewallproxy "$WIFI_SVC" | awk '/^Enabled/{print $2}')"
    echo "pac=$(networksetup -getautoproxyurl "$WIFI_SVC" | awk '/^Enabled/{print $2}')"
  } > "$BACKUP_DIR/proxy.bak"
  sudo networksetup -setwebproxystate "$WIFI_SVC" off
  sudo networksetup -setsecurewebproxystate "$WIFI_SVC" off
  sudo networksetup -setsocksfirewallproxystate "$WIFI_SVC" off
  sudo networksetup -setautoproxystate "$WIFI_SVC" off
  echo "Proxies disabled. Backup: $BACKUP_DIR/proxy.bak"
  retest
}

restore_proxy() {
  [ -f "$BACKUP_DIR/proxy.bak" ] || { echo "No proxy backup found."; return; }
  . "$BACKUP_DIR/proxy.bak"
  [ "$web" = "Yes" ]    && sudo networksetup -setwebproxystate "$WIFI_SVC" on
  [ "$secure" = "Yes" ] && sudo networksetup -setsecurewebproxystate "$WIFI_SVC" on
  [ "$socks" = "Yes" ]  && sudo networksetup -setsocksfirewallproxystate "$WIFI_SVC" on
  [ "$pac" = "Yes" ]    && sudo networksetup -setautoproxystate "$WIFI_SVC" on
  echo "Proxy states restored."
}

wifi_first() {
  echo "Current service order:"; networksetup -listnetworkserviceorder | grep '^('
  echo "If Wi-Fi is not first, open System Settings > Network > (…) menu > 'Set Service Order' and drag Wi-Fi to the top."
  echo "(Done manually on purpose: reordering via CLI requires retyping every service name and is easy to get wrong.)"
}

case "$1" in
  restore-dns)   restore_dns;   exit ;;
  restore-proxy) restore_proxy; exit ;;
esac

while true; do
  cat <<EOF

=== Wi-Fi repair ($WIFI_SVC on $WIFI_IF) — safest first ===
 1) Flush DNS cache
 2) Renew DHCP lease
 3) Restart Wi-Fi radio (off/on)
 4) Switch to public DNS (1.1.1.1 / 8.8.8.8)   [reversible]
 5) Disable proxies                            [reversible]
 6) Check network service order
 7) Re-test only
 u) Undo: restore DNS     p) Undo: restore proxies
 q) Quit
EOF
  printf 'Choice: '; read -r c
  case "$c" in
    1) flush_dns ;; 2) renew_dhcp ;; 3) toggle_wifi ;; 4) set_public_dns ;;
    5) disable_proxies ;; 6) wifi_first ;; 7) retest ;;
    u) restore_dns ;; p) restore_proxy ;; q) exit 0 ;;
  esac
done
