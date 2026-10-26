# Port forwarding for qBittorrent through the Proton VPN.
#
# The VPN namespace drops all inbound traffic on wg0, and Proton opens no
# port unless asked. qBittorrent then reaches only peers that accept
# connections. A torrent whose seeders also accept none stays at 0 %
# (2026-10-26: 7 seeders, no connection for hours).
#
# This unit runs in the VPN namespace. Every 45 seconds it asks Proton's
# gateway for a port over NAT-PMP (the lease is 60 seconds). When the port
# changes, it opens the port on wg0 and makes it qBittorrent's listen port.
# Proton picks the port, so nixflix.vpn.openVPNPorts cannot hold it.
#
# Proton gives a port only to a WireGuard configuration for a P2P server
# with "NAT-PMP (Port Forwarding)" on. With another configuration the
# gateway does not answer. The unit then logs that once and keeps asking.
{
  config,
  lib,
  pkgs,
  ...
}:
let
  qbittorrent = config.nixflix.torrentClients.qbittorrent;
  # Proton's gateway in the tunnel. Every Proton WireGuard configuration
  # also uses it as the DNS server.
  gateway = "10.2.0.1";
  # VPN-Confinement names the WireGuard interface after the namespace.
  iface = "${config.nixflix.vpn.namespace}0";
  # Our own chain, jumped to from INPUT and emptied at each port change.
  chain = "qbt-port-forward";
  natpmpc = lib.getExe' pkgs.libnatpmp "natpmpc";
in
{
  systemd.services.qbittorrent-port-forward = {
    description = "Forward a Proton VPN port to qBittorrent";
    after = [ "qbittorrent.service" ];
    wantedBy = [ "qbittorrent.service" ];
    # Stops and restarts with qBittorrent, and so with wg.service. A new
    # namespace has none of our rules, and a restarted qBittorrent can come
    # back on its old port, so the loop starts again from nothing.
    partOf = [ "qbittorrent.service" ];
    vpnConfinement = {
      enable = true;
      vpnNamespace = config.nixflix.vpn.namespace;
    };
    path = [
      pkgs.curl
      pkgs.iptables
    ];
    serviceConfig = {
      Restart = "always";
      RestartSec = 30;
      LoadCredential = [
        "webui-password:${config.sops.secrets."mini/media/qbittorrent/password".path}"
      ];
      # Runs as root for iptables in the namespace, with no other privilege.
      CapabilityBoundingSet = [
        "CAP_NET_ADMIN"
        "CAP_NET_RAW"
      ];
      NoNewPrivileges = true;
      PrivateTmp = true;
      ProtectHome = true;
    };
    script = ''
      set -uo pipefail
      api=http://${qbittorrent.connectionAddress}:${toString qbittorrent.webuiPort}/api/v2

      iptables -N ${chain} 2>/dev/null || iptables -F ${chain}
      iptables -C INPUT -j ${chain} 2>/dev/null || iptables -I INPUT -j ${chain}

      # Makes $1 qBittorrent's listen port. Returns non-zero when that fails.
      listen_on() {
        local cookie rc
        cookie=$(curl -sS --max-time 10 -D - -o /dev/null \
          --data-urlencode "username=${qbittorrent.serverConfig.Preferences.WebUI.Username}" \
          --data-urlencode "password@$CREDENTIALS_DIRECTORY/webui-password" \
          "$api/auth/login" | sed -n 's/^[Ss]et-[Cc]ookie: \([^;]*\).*/\1/p' || true)
        [ -n "$cookie" ] || return 1
        curl -fsS --max-time 10 -b "$cookie" \
          --data-urlencode "json={\"listen_port\":$1}" "$api/app/setPreferences" >/dev/null
        rc=$?
        curl -sS --max-time 10 -o /dev/null -b "$cookie" -X POST "$api/auth/logout" || true
        return $rc
      }

      current=
      quiet=
      while true; do
        # Proton wants one request per protocol and gives both the same port.
        out=$(${natpmpc} -g ${gateway} -a 1 0 udp 60 && ${natpmpc} -g ${gateway} -a 1 0 tcp 60) || true
        port=$(sed -n 's/^Mapped public port \([0-9]*\) protocol TCP.*/\1/p' <<<"$out")
        if [ -z "$port" ]; then
          if [ -z "$quiet" ]; then
            echo "no port from ${gateway}: the WireGuard configuration has no NAT-PMP, or the gateway did not answer"
            quiet=1
          fi
        else
          quiet=
          if [ "$port" != "$current" ]; then
            iptables -F ${chain}
            iptables -A ${chain} -i ${iface} -p tcp --dport "$port" -j ACCEPT
            iptables -A ${chain} -i ${iface} -p udp --dport "$port" -j ACCEPT
            if listen_on "$port"; then
              echo "port $port: open on ${iface}, qBittorrent listens on it"
              current=$port
            else
              echo "port $port: open on ${iface}, but qBittorrent did not take it; next try in 45 s"
            fi
          fi
        fi
        sleep 45
      done
    '';
  };
}
