# Browser Utils

Browser Utils is a VS Code extension for the built-in Integrated Browser.

## Features

- Opens terminal URL clicks in VS Code's Integrated Browser.
- Adds `New Browser` to the Explorer context menu.
- Adds `New Text File` to the Explorer context menu near file and terminal actions.
- Provides a hosts-file based adblock helper for the Integrated Browser.

## Commands

- `Browser Utils: New Browser`
- `Browser Utils: Open Clipboard URL in Integrated Browser`
- `Browser Utils: New Text File`
- `Browser Utils Adblock: Install/Update Hosts Blocklist`
- `Browser Utils Adblock: Remove Hosts Blocklist`
- `Browser Utils Adblock: Show Status`
- `Browser Utils Adblock: Repair YouTube Playback`
- `Browser Utils Adblock: Copy Admin Install Command`
- `Browser Utils Adblock: Open Blocklist`
- `Browser Utils Adblock: Open Log`

## Adblock Notes

The adblock feature writes a marked section to:

```text
C:\Windows\System32\drivers\etc\hosts
```

Windows requires administrator rights to edit that file. The install/remove commands open an elevated PowerShell helper and keep it visible so errors are easy to inspect.

This is DNS/hosts blocking. It cannot provide the same behavior as a Chromium extension using `webRequest`, and it cannot bypass site DRM, anti-debugging, or anti-embed checks.

### YouTube

YouTube video playback uses domains such as `youtube.com`, `googlevideo.com`, `ytimg.com`, and `youtubei.googleapis.com`. Blocking these at the hosts-file level can stop videos from loading. Browser Utils protects those domains during install and includes `Browser Utils Adblock: Repair YouTube Playback` to remove accidental hosts entries for them.

YouTube in-stream ads are often delivered through the same playback infrastructure as normal videos. A hosts-file blocker is intentionally conservative here: it prioritizes playback over breaking video loading.

## Settings

- `browserUtils.handleTerminalLinks`: route terminal URLs to the Integrated Browser.
- `browserUtils.adblock.extraDomains`: extra domains to add to the managed hosts block.

## Link Handling Limits

Browser Utils handles terminal links directly. Some VS Code surfaces, including chat output, Markdown previews, and extension release notes, use VS Code's external browser opener instead. For those links, copy the URL and run `Browser Utils: Open Clipboard URL in Integrated Browser`.

## Development

```powershell
npm install
npm run check
npm run package
```

The packaged VSIX is written to `browser-utils-0.0.1.vsix`.
