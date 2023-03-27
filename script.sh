#!/bin/bash
# eww, it seems vpm-cli do NOT find out where UnityHub (and the Editor managed by it)...
# Huh, that heck.
#
# References.
# * https://zenn.dev/ytjvdcm/articles/a5b6318b8a3995
# * https://vcc.docs.vrchat.com/vpm/cli/
# End Of References.

die() {
  echo "$*" >&2
  exit 1
}

install_pinned_version() {
  # alternative for buggy `vpm install unity` (vpm-cli relies on (maybe undocumented) feature on
  # unityhub to install pinned version.) However, UnityHub 3.4.1 does not recognize (maybe
  # removed?) those switch, and launches as usual. This is CLEARLY NOT desired behavior, so this
  # bootstrap script uses official stable launcher and passing necessary switch to install
  # required component to generate new project correctly.
  install_dir="$1"
  f="$(mktemp XXXXXXXXXX-unity-installer.exe -p .)"
  curl https://download.unity3d.com/download_unity/bd5abf232a62/UnitySetup-2019.4.31f1 > "$f"
  chmod +x "$f"
  # auto agree. You've agreed its terms of conditions, don't you? :-)
  # NB. You may want to add Android support for Oculus.
  (echo "y" | "$f" -u -c Unity,Windows-Mono -l "$install_dir") || die "Unity Editor setup may fail."
  rm "$f"
}

assert_jq() {
  which jq || false
}

assert_unityhub() {
  which unityhub || false
}

assert_jq || die 'This script requires jq. '
assert_unityhub || die 'This script requires unityhub. Please see install instructions at https://docs.unity3d.com/hub/manual/InstallHub.html#install-hub-linux'

# shellcheck disable=SC2016
uh_path="$(which unityhub || die '`unityhub` could not found in your $PATH')"
editor_install_dir="$(jq -r < ~/.config/unityhub/secondaryInstallPath.json)"
# No, that's not wrong. See https://docs.vrchat.com/docs/current-unity-version
pinned_unity_version="2019.4.31f1"
unity_editor_dir="$editor_install_dir/$pinned_unity_version"

if [ ! -d "$unity_editor_dir" ]; then
  echo "Warning: suitable Unity Editor cannot be found, executing automated installation."
  install_pinned_version "$unity_editor_dir"
else
  echo "OK, Unity is already installed"
fi

echo "Updating VCC:settings.json"
settings="$HOME/.local/share/VRChatCreatorCompanion/settings.json"

if [ ! -f "$settings" ]; then
  # TODO: local command
  # generates initial values and save them
  # If the settings.json does not exist, VPM will crush with those NULL dereference.
  ~/RiderProjects/VPMSettingInitializer2/VPMSettingInitializer/bin/Debug/net6.0/VPMSettingInitializer ~/.local/share/VRChatCreatorCompanion/settings.json
fi

unityhub_path="$(readlink -n "$uh_path")"
echo "pathToUnityHub = $unityhub_path"

t="$(mktemp)"
jq --arg unityhub_path "$unityhub_path" '.pathToUnityHub |= $unityhub_path' < "$settings" > "$t"
mv "$t" "$settings"

unity_editor_exe="$unity_editor_dir/Editor/Unity"
t="$(mktemp)"
jq --arg unity_editor_exe "$unity_editor_exe" '.pathToUnityExe |= $unity_editor_exe' < "$settings" > "$t"
mv "$t" "$settings"

t="$(mktemp)"
jq --arg unity_editor_exe "$unity_editor_dir" '.unityEditors += [$unity_editor_exe]' < "$settings" > "$t"
mv "$t" "$settings"
