# VSC Utils

VSC Utils is a VS Code extension for the built-in Integrated Browser.

## Features

- Opens terminal URL clicks in VS Code's Integrated Browser.
- Adds `New Browser` to the Explorer context menu.
- Adds `New Text File` to the Explorer context menu near file and terminal actions.
- Provides a hosts-file based adblock helper for the Integrated Browser.

## Commands

- `VSC Utils: New Browser`
- `VSC Utils: Open Clipboard URL in Integrated Browser`
- `VSC Utils: New Text File`
- `VSC Utils Adblock: Install/Update Hosts Blocklist`
- `VSC Utils Adblock: Remove Hosts Blocklist`
- `VSC Utils Adblock: Show Status`
- `VSC Utils Adblock: Repair YouTube Playback`
- `VSC Utils Adblock: Copy Admin Install Command`
- `VSC Utils Adblock: Open Blocklist`
- `VSC Utils Adblock: Open Log`

## Adblock Notes

The adblock feature writes a marked section to:

```text
C:\Windows\System32\drivers\etc\hosts
```

Windows requires administrator rights to edit that file. The install/remove commands open an elevated PowerShell helper and keep it visible so errors are easy to inspect.

This is DNS/hosts blocking. It cannot provide the same behavior as a Chromium extension using `webRequest`, and it cannot bypass site DRM, anti-debugging, or anti-embed checks.

### YouTube

YouTube video playback uses domains such as `youtube.com`, `googlevideo.com`, `ytimg.com`, and `youtubei.googleapis.com`. Blocking these at the hosts-file level can stop videos from loading. VSC Utils protects those domains during install and includes `VSC Utils Adblock: Repair YouTube Playback` to remove accidental hosts entries for them.

YouTube in-stream ads are often delivered through the same playback infrastructure as normal videos. A hosts-file blocker is intentionally conservative here: it prioritizes playback over breaking video loading.

## Settings

- `vscUtils.handleTerminalLinks`: route terminal URLs to the Integrated Browser.
- `vscUtils.adblock.extraDomains`: extra domains to add to the managed hosts block.

The old `browserUtils.*` setting names still work as compatibility aliases.

## Link Handling Limits

VSC Utils handles terminal links directly. Some VS Code surfaces, including chat output, Markdown previews, and extension release notes, use VS Code's external browser opener instead. For those links, copy the URL and run `VSC Utils: Open Clipboard URL in Integrated Browser`.

## Development

```powershell
npm install
npm run check
npm run package
```

The packaged VSIX is written to `vsc-utils-0.0.4.vsix`.
