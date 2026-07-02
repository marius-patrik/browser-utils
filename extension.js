const cp = require("child_process");
const fs = require("fs");
const path = require("path");
const vscode = require("vscode");

const urlPattern = /https?:\/\/[^\s<>"'`)\]}]+/g;
const blocklistPath = path.join(__dirname, "blocklist.txt");
const helperPath = path.join(__dirname, "scripts", "update-hosts.ps1");
const logPath = path.join(__dirname, "adblock.log");

class BrowserTerminalLink extends vscode.TerminalLink {
  constructor(startIndex, length, url) {
    super(startIndex, length);
    this.url = url;
    this.tooltip = "Open in Integrated Browser";
  }
}

function quotePowerShell(value) {
  return `'${String(value).replace(/'/g, "''")}'`;
}

function encodePowerShell(command) {
  return Buffer.from(command, "utf16le").toString("base64");
}

function getExtraDomains() {
  const config = vscode.workspace.getConfiguration("browserUtils");
  const extraDomains = config.get("adblock.extraDomains", []);
  return Array.isArray(extraDomains) ? extraDomains.join(",") : "";
}

function getHelperArguments(action, noPause) {
  return [
    "-NoExit",
    "-NoProfile",
    "-ExecutionPolicy",
    "Bypass",
    "-File",
    quotePowerShell(helperPath),
    "-Action",
    quotePowerShell(action),
    "-BlocklistPath",
    quotePowerShell(blocklistPath),
    "-ExtraDomains",
    quotePowerShell(getExtraDomains()),
    "-LogPath",
    quotePowerShell(logPath),
    ...(noPause ? ["-NoPause"] : []),
  ].join(" ");
}

function runElevated(action) {
  const command = [
    "$ErrorActionPreference = 'Stop'",
    "Start-Process -FilePath 'powershell.exe' -Verb RunAs -ArgumentList " +
      quotePowerShell(getHelperArguments(action, false)),
  ].join("; ");

  cp.spawn(
    "powershell.exe",
    ["-NoProfile", "-ExecutionPolicy", "Bypass", "-EncodedCommand", encodePowerShell(command)],
    { detached: true, stdio: "ignore", windowsHide: true }
  ).unref();
}

function runStatus() {
  return new Promise((resolve, reject) => {
    cp.execFile(
      "powershell.exe",
      [
        "-NoProfile",
        "-ExecutionPolicy",
        "Bypass",
        "-File",
        helperPath,
        "-Action",
        "Status",
        "-BlocklistPath",
        blocklistPath,
        "-ExtraDomains",
        getExtraDomains(),
        "-LogPath",
        logPath,
        "-NoPause",
      ],
      { windowsHide: true, maxBuffer: 1024 * 1024 },
      (error, stdout, stderr) => {
        if (error) {
          reject(new Error(stderr || stdout || error.message));
          return;
        }
        resolve(stdout.trim());
      }
    );
  });
}

function provideTerminalLinks(context) {
  if (!vscode.workspace.getConfiguration("browserUtils").get("handleTerminalLinks", true)) {
    return [];
  }

  const links = [];
  for (const match of context.line.matchAll(urlPattern)) {
    links.push(new BrowserTerminalLink(match.index, match[0].length, match[0]));
  }
  return links;
}

async function openIntegratedBrowser(url) {
  try {
    await vscode.commands.executeCommand(
      "workbench.action.browser.open",
      url ? { url } : undefined
    );
  } catch {
    if (url) {
      await vscode.commands.executeCommand("simpleBrowser.show", url);
    } else {
      await vscode.commands.executeCommand("workbench.action.browser.open");
    }
  }
}

async function openClipboardUrl() {
  const clipboard = (await vscode.env.clipboard.readText()).trim();
  const value =
    /^https?:\/\//i.test(clipboard)
      ? clipboard
      : await vscode.window.showInputBox({
          prompt: "URL to open in the Integrated Browser",
          value: clipboard,
          validateInput(input) {
            return /^https?:\/\//i.test(input.trim()) ? undefined : "Enter an http or https URL.";
          },
        });

  if (!value) return;
  await openIntegratedBrowser(value.trim());
}

async function getTargetFolder(resource) {
  if (resource?.scheme === "file") {
    try {
      const stat = await vscode.workspace.fs.stat(resource);
      if (stat.type & vscode.FileType.Directory) {
        return resource;
      }
    } catch {}
    return vscode.Uri.file(path.dirname(resource.fsPath));
  }

  const firstFolder = vscode.workspace.workspaceFolders?.[0];
  return firstFolder?.uri;
}

async function newTextFile(resource) {
  const folder = await getTargetFolder(resource);
  if (!folder) {
    await vscode.commands.executeCommand("workbench.action.files.newUntitledFile");
    return;
  }

  const name = await vscode.window.showInputBox({
    prompt: "New text file name",
    value: "New Text File.txt",
    validateInput(value) {
      if (!value.trim()) return "Enter a file name.";
      if (/[<>:"/\\|?*]/.test(value)) return "File name contains invalid characters.";
      return undefined;
    },
  });
  if (!name) return;

  const target = vscode.Uri.joinPath(folder, name.trim());
  try {
    try {
      await vscode.workspace.fs.stat(target);
      vscode.window.showErrorMessage(`File already exists: ${target.fsPath}`);
      return;
    } catch {}

    await vscode.workspace.fs.writeFile(target, new Uint8Array());
    const doc = await vscode.workspace.openTextDocument(target);
    await vscode.window.showTextDocument(doc);
  } catch (error) {
    vscode.window.showErrorMessage(`Could not create file: ${error.message}`);
  }
}

async function openFileIfExists(filePath, missingMessage) {
  if (!fs.existsSync(filePath)) {
    vscode.window.showErrorMessage(missingMessage);
    return;
  }
  const doc = await vscode.workspace.openTextDocument(filePath);
  await vscode.window.showTextDocument(doc);
}

function activate(context) {
  context.subscriptions.push(
    vscode.window.registerTerminalLinkProvider({
      provideTerminalLinks,
      handleTerminalLink: link => openIntegratedBrowser(link.url),
    }),
    vscode.commands.registerCommand("browserUtils.openNewBrowser", () => openIntegratedBrowser()),
    vscode.commands.registerCommand("browserUtils.openClipboardUrl", openClipboardUrl),
    vscode.commands.registerCommand("browserUtils.newTextFile", newTextFile),
    vscode.commands.registerCommand("browserUtils.adblock.install", () => {
      runElevated("Install");
      vscode.window.showInformationMessage(
        "Browser Utils adblock installer opened. Approve the admin prompt, then restart VS Code."
      );
    }),
    vscode.commands.registerCommand("browserUtils.adblock.remove", () => {
      runElevated("Remove");
      vscode.window.showInformationMessage(
        "Browser Utils adblock remover opened. Approve the admin prompt, then restart VS Code."
      );
    }),
    vscode.commands.registerCommand("browserUtils.adblock.status", async () => {
      try {
        const output = await runStatus();
        vscode.window.showInformationMessage(output || "Browser Utils adblock status check finished.");
      } catch (error) {
        vscode.window.showErrorMessage(`Browser Utils adblock status failed: ${error.message}`);
      }
    }),
    vscode.commands.registerCommand("browserUtils.adblock.repairYouTube", () => {
      runElevated("RepairYouTube");
      vscode.window.showInformationMessage(
        "Browser Utils YouTube repair opened. Approve the admin prompt, then restart VS Code."
      );
    }),
    vscode.commands.registerCommand("browserUtils.adblock.copyInstallCommand", async () => {
      const command = `powershell.exe ${getHelperArguments("Install", false)}`;
      await vscode.env.clipboard.writeText(command);
      vscode.window.showInformationMessage(
        "Copied the Browser Utils adblock install command. Paste it into an Administrator PowerShell."
      );
    }),
    vscode.commands.registerCommand("browserUtils.adblock.openBlocklist", () =>
      openFileIfExists(blocklistPath, `Blocklist not found: ${blocklistPath}`)
    ),
    vscode.commands.registerCommand("browserUtils.adblock.openLog", () =>
      openFileIfExists(logPath, `Log not found yet: ${logPath}`)
    )
  );
}

function deactivate() {}

module.exports = {
  activate,
  deactivate,
};
