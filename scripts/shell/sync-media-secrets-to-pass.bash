#!/usr/bin/env bash
# Upsert mini's media secrets from SOPS into the Proton Pass CLI default vault.
# Service endpoints use Login items so the browser extension can autofill URLs.
# Secret values stay out of source files, shell history, and command output.
set -euo pipefail

# shellcheck source=scripts/shell/common.sh
source "${FLAKE:-${HOME}/.dotfiles/flake}/scripts/shell/common.sh"

export PROTON_PASS_LINUX_KEYRING="${PROTON_PASS_LINUX_KEYRING:-dbus}"

NOTE="Managed from secrets/secrets.yaml by sync-media-secrets-to-pass.bash"

apply=false
case "${1:---dry-run}" in
--apply) apply=true ;;
--dry-run) ;;
-h | --help)
 printf 'Usage: %s [--dry-run|--apply]\n' "$0"
 exit 0
 ;;
*)
 print_error "Unknown argument: $1"
 exit 2
 ;;
esac

for command in jq sops; do
 if ! command_exists "$command"; then
  print_error "Missing command: $command"
  exit 1
 fi
done

secrets_file="${FLAKE:-${HOME}/.dotfiles/flake}/secrets/secrets.yaml"
if [[ ! -r "$secrets_file" ]]; then
 print_error "Cannot read $secrets_file"
 exit 1
fi

print_header "PROTON PASS MEDIA SECRETS"
print_info "Decrypting media secrets in memory"
secrets_json="$(sops --decrypt --output-type json "$secrets_file")"

secret_count="$({ jq -e '
  [
    .mini.media.sonarr["api-key"],
    .mini.media.sonarr.password,
    .mini.media.radarr["api-key"],
    .mini.media.radarr.password,
    .mini.media.lidarr["api-key"],
    .mini.media.lidarr.password,
    .mini.media.prowlarr["api-key"],
    .mini.media.prowlarr.password,
    .mini.media.prowlarr.indexers["nzbgeek-api-key"],
    .mini.media.prowlarr.indexers["scenenzbs-api-key"],
    .mini.media.sabnzbd["api-key"],
    .mini.media.sabnzbd["nzb-key"],
    .mini.media.sabnzbd.username,
    .mini.media.sabnzbd.password,
    .mini.media.sabnzbd["premiumize-username"],
    .mini.media.sabnzbd["premiumize-password"],
    .mini.media.qbittorrent.password,
    .mini.media.jellyfin["api-key"],
    .mini.media.jellyfin.users["jadee-password"],
    .mini.media.jellyfin.users["angeli265-password"],
    .mini.media.vpn["wireguard-conf"]
  ]
  | if all(. != null) then length else error("missing media secret") end
' <<<"$secrets_json"; } 2>/dev/null)" || {
 unset secrets_json
 print_error "SOPS data is missing one or more expected mini/media secrets"
 exit 1
}

if [[ "$secret_count" != 21 ]]; then
 unset secrets_json
 print_error "Expected 21 media secrets, found $secret_count"
 exit 1
fi

specs_json="$(jq -c '
  def extra($name; $value):
    if ($value | length) > 0 then { name: $name, value: $value } else empty end;
  def login($title; $url; $username; $password; $extras):
    {
      kind: "login",
      title: $title,
      url: $url,
      username: $username,
      password: $password,
      extras: $extras
    };
  def custom($title; $section; $fields):
    {
      kind: "custom",
      title: $title,
      sections: [{ section_name: $section, fields: $fields }]
    };
  def field($name; $type; $value):
    { field_name: $name, field_type: $type, value: $value };
  [
    login("Nixflix — Sonarr"; "https://sonarr.jadee.fyi"; "sonarr"; .mini.media.sonarr.password; [
      extra("API key"; .mini.media.sonarr["api-key"])
    ]),
    login("Nixflix — Radarr"; "https://radarr.jadee.fyi"; "radarr"; .mini.media.radarr.password; [
      extra("API key"; .mini.media.radarr["api-key"])
    ]),
    login("Nixflix — Lidarr"; "https://lidarr.jadee.fyi"; "lidarr"; .mini.media.lidarr.password; [
      extra("API key"; .mini.media.lidarr["api-key"])
    ]),
    login("Nixflix — Prowlarr"; "https://prowlarr.jadee.fyi"; "prowlarr"; .mini.media.prowlarr.password; [
      extra("API key"; .mini.media.prowlarr["api-key"])
    ]),
    login("Nixflix — NZBgeek"; "https://nzbgeek.info"; ""; ""; [
      extra("API key"; .mini.media.prowlarr.indexers["nzbgeek-api-key"])
    ]),
    login("Nixflix — SceneNZBs"; "https://scenenzbs.com"; ""; ""; [
      extra("API key"; .mini.media.prowlarr.indexers["scenenzbs-api-key"])
    ]),
    login("Nixflix — SABnzbd"; "https://sabnzbd.jadee.fyi"; .mini.media.sabnzbd.username; .mini.media.sabnzbd.password; [
      extra("API key"; .mini.media.sabnzbd["api-key"]),
      extra("NZB key"; .mini.media.sabnzbd["nzb-key"])
    ]),
    login("Nixflix — Premiumize Usenet"; "https://www.premiumize.me"; .mini.media.sabnzbd["premiumize-username"]; .mini.media.sabnzbd["premiumize-password"]; []),
    login("Nixflix — qBittorrent"; "https://qbittorrent.jadee.fyi"; "admin"; .mini.media.qbittorrent.password; []),
    login("Nixflix — Jellyfin (jadee)"; "https://jellyfin.jadee.fyi"; "jadee"; .mini.media.jellyfin.users["jadee-password"]; [
      extra("API key"; .mini.media.jellyfin["api-key"])
    ]),
    login("Nixflix — Jellyfin (angeli265)"; "https://jellyfin.jadee.fyi"; "angeli265"; .mini.media.jellyfin.users["angeli265-password"]; []),
    custom("Nixflix — Proton VPN WireGuard"; "VPN"; [
      field("Provider"; "text"; "Proton VPN"),
      field("WireGuard config"; "hidden"; .mini.media.vpn["wireguard-conf"])
    ])
  ]
' <<<"$secrets_json")"

pass_login_template() {
 jq -c --arg note "$NOTE" '
  {
    title: .title,
    username: .username,
    password: .password,
    urls: [.url],
    note: $note
  }
' <<<"$1"
}

pass_custom_template() {
 jq -c --arg note "$NOTE" '
  {
    title: .title,
    note: $note,
    sections: .sections
  }
' <<<"$1"
}

describe_item() {
 local spec="$1"
 case "$(jq -r '.kind' <<<"$spec")" in
 login)
  jq -r '"login \(.title): url, username, password\(
      if (.extras | length) > 0 then ", " + ([.extras[].name] | join(", ")) else "" end
    )"' <<<"$spec"
  ;;
 custom)
  jq -r '"custom \(.title): " + ([.sections[].fields[].field_name] | join(", "))' <<<"$spec"
  ;;
 *)
  print_error "unknown item kind in template"
  return 1
  ;;
 esac
}

update_login_item() {
 local item_id="$1"
 local spec="$2"
 local action="$3"
 local update_args=(item update --item-id "$item_id")
 local field_name field_value

 update_args+=(--field "username=$(jq -r '.username' <<<"$spec")")
 update_args+=(--field "password=$(jq -r '.password' <<<"$spec")")
 update_args+=(--field "url=$(jq -r '.url' <<<"$spec")")
 update_args+=(--field "note=$NOTE")

 while IFS= read -r extra; do
  field_name="$(jq -r '.name' <<<"$extra")"
  field_value="$(jq -r '.value' <<<"$extra")"
  update_args+=(--field "${field_name}=${field_value}")
 done < <(jq -c '.extras[]?' <<<"$spec")

 if pass-cli "${update_args[@]}" >/dev/null 2>&1; then
  print_success "$action $(jq -r '.title' <<<"$spec")"
  return 0
 fi

 return 1
}

create_login_item() {
 local spec="$1"
 local template item_id

 template="$(pass_login_template "$spec")"
 if ! item_id="$(pass-cli item create login --from-template - <<<"$template" 2>/dev/null)"; then
  return 1
 fi

 update_login_item "$item_id" "$spec" created
}

update_custom_item() {
 local item_id="$1"
 local spec="$2"
 local action="$3"
 local update_args=(item update --item-id "$item_id")
 local decoded_field field_name field_value

 while IFS= read -r encoded_field; do
  decoded_field="$(base64 --decode <<<"$encoded_field")"
  field_name="$(jq -r '.[0]' <<<"$decoded_field")"
  field_value="$(jq -r '.[1]' <<<"$decoded_field")"
  update_args+=(--field "${field_name}=${field_value}")
 done < <(
  jq -r '
    .sections[] as $section
    | $section.fields[]
    | [($section.section_name + "." + .field_name), .value]
    | @base64
  ' <<<"$spec"
 )
 update_args+=(--field "note=$NOTE")

 if pass-cli "${update_args[@]}" >/dev/null 2>&1; then
  print_success "$action $(jq -r '.title' <<<"$spec")"
  return 0
 fi

 return 1
}

create_custom_item() {
 local spec="$1"
 local template item_id

 template="$(pass_custom_template "$spec")"
 if ! item_id="$(pass-cli item create custom --from-template - <<<"$template" 2>/dev/null)"; then
  return 1
 fi

 update_custom_item "$item_id" "$spec" created
}

sync_item() {
 local spec="$1"
 local title kind matches wrong_matches right_matches count item_id

 title="$(jq -r '.title' <<<"$spec")"
 kind="$(jq -r '.kind' <<<"$spec")"
 matches="$(jq -c --arg title "$title" '[.items[] | select(.title == $title)]' <<<"$items_json")"
 wrong_matches="$(jq -c --arg kind "$kind" '[.[] | select((.item_type | ascii_downcase) != $kind)]' <<<"$matches")"
 right_matches="$(jq -c --arg kind "$kind" '[.[] | select((.item_type | ascii_downcase) == $kind)]' <<<"$matches")"

 while IFS= read -r legacy_id; do
  [[ -z "$legacy_id" ]] && continue
  if ! pass-cli item trash --item-id "$legacy_id" >/dev/null 2>&1; then
   print_error "could not trash legacy item $title ($legacy_id)"
   return 1
  fi
 done < <(jq -r '.[].id' <<<"$wrong_matches")

 count="$(jq 'length' <<<"$right_matches")"
 if [[ "$count" -gt 1 ]]; then
  print_error "multiple active $kind items named $title; refusing to choose one"
  return 1
 fi

 if [[ "$count" -eq 0 ]]; then
  case "$kind" in
  login)
   create_login_item "$spec" || {
    print_error "create failed for $title"
    return 1
   }
   ;;
  custom)
   create_custom_item "$spec" || {
    print_error "create failed for $title"
    return 1
   }
   ;;
  *)
   print_error "unknown item kind for $title"
   return 1
   ;;
  esac
  return 0
 fi

 item_id="$(jq -r '.[0].id' <<<"$right_matches")"
 case "$kind" in
 login)
  update_login_item "$item_id" "$spec" updated || {
   print_error "update failed for $title"
   return 1
  }
  ;;
 custom)
  update_custom_item "$item_id" "$spec" updated || {
   print_error "update failed for $title"
   return 1
  }
  ;;
 esac
}

if [[ "$apply" == false ]]; then
 while IFS= read -r spec; do
  describe_item "$spec" | sed 's/^/would sync /'
 done < <(jq -c '.[]' <<<"$specs_json")
 unset secrets_json specs_json
 print_info "Dry run only; rerun with --apply from an authenticated Proton Pass CLI shell"
 exit 0
fi

if ! command_exists pass-cli; then
 unset secrets_json specs_json
 print_error "Missing command: pass-cli"
 exit 1
fi

if ! pass-cli test >/dev/null 2>&1; then
 unset secrets_json specs_json
 print_error "Proton Pass CLI is not authenticated in this shell"
 exit 1
fi

if ! items_json="$(pass-cli item list --output json --filter-state active 2>/dev/null)"; then
 unset secrets_json specs_json
 print_error "Cannot list the Proton Pass CLI default vault"
 exit 1
fi

rc=0
while IFS= read -r spec; do
 sync_item "$spec" || rc=1
done < <(jq -c '.[]' <<<"$specs_json")

unset secrets_json specs_json items_json spec
print_header "END"
exit "$rc"
