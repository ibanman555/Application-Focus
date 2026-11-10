'use strict';

// Stream Deck Application Focus — Windows only, with zero target-app launching.
// Uses the official Stream Deck local WebSocket protocol and a persistent, hidden
// Windows PowerShell helper for top-level window enumeration and Win32 activation.
// Requires no npm packages, Bome, MIDI routing, or user-defined scripts.
const fs = require('node:fs');
const path = require('node:path');
const { spawn } = require('node:child_process');
const { StringDecoder } = require('node:string_decoder');

const ACTION = 'com.koop.appfocus.focus';
const params = Object.create(null);
for (let i = 2; i < process.argv.length - 1; i++) {
  if (process.argv[i].startsWith('-')) params[process.argv[i]] = process.argv[++i];
}
const port = Number(params['-port']);
const uuid = params['-pluginUUID'];
const registerEvent = params['-registerEvent'] || 'registerPlugin';
if (!Number.isInteger(port) || !uuid) process.exit(1);

let helper = null;
let helperBuffer = '';
let helperId = 0;
const pending = new Map();
let helperRestartTimer = null;
const cachedSettings = new Map();
let socket = null;

function log(message) {
  if (socket && socket.readyState === WebSocket.OPEN) {
    socket.send(JSON.stringify({ event: 'logMessage', payload: { message: '[Application Focus] ' + String(message).slice(0, 600) } }));
  }
}

function closePending(reason) {
  for (const [id, entry] of pending) {
    clearTimeout(entry.timer);
    entry.reject(new Error(reason));
    pending.delete(id);
  }
}

function startHelper() {
  if (helper) return;
  try {
    const source = fs.readFileSync(path.join(__dirname, 'focus-helper.ps1'), 'utf8');
    const encoded = Buffer.from(source, 'utf16le').toString('base64');
    helper = spawn('powershell.exe', ['-NoLogo', '-NoProfile', '-NonInteractive', '-WindowStyle', 'Hidden', '-EncodedCommand', encoded], {
      windowsHide: true,
      stdio: ['pipe', 'pipe', 'pipe'],
    });
    helper.stdout.setEncoding('utf8');
    helper.stdout.on('data', chunk => {
      helperBuffer += chunk;
      let end;
      while ((end = helperBuffer.indexOf('\n')) !== -1) {
        const row = helperBuffer.slice(0, end).trim();
        helperBuffer = helperBuffer.slice(end + 1);
        if (!row) continue;
        try {
          const reply = JSON.parse(row);
          const callback = pending.get(String(reply.id));
          if (callback) {
            clearTimeout(callback.timer);
            pending.delete(String(reply.id));
            callback.resolve(reply);
          }
        } catch { log('Invalid helper response.'); }
      }
    });
    helper.stderr.setEncoding('utf8');
    helper.stderr.on('data', chunk => log('Windows helper: ' + chunk.trim()));
    helper.on('error', error => log('Could not start Windows helper: ' + error.message));
    helper.on('exit', (code) => {
      helper = null;
      helperBuffer = '';
      closePending('Windows focus helper stopped, exit ' + code);
      if (!helperRestartTimer) {
        helperRestartTimer = setTimeout(() => {
          helperRestartTimer = null;
          startHelper();
        }, 1500);
      }
    });
  } catch (error) { log(error.message); }
}

function requestHelper(command, timeout = 7000) {
  return new Promise((resolve, reject) => {
    startHelper();
    if (!helper || !helper.stdin.writable) return reject(new Error('Windows helper unavailable'));
    const id = String(++helperId);
    const timer = setTimeout(() => {
      pending.delete(id);
      reject(new Error('Windows helper timed out'));
    }, timeout);
    pending.set(id, { resolve, reject, timer });
    helper.stdin.write(JSON.stringify({ ...command, id }) + '\n', error => {
      if (error && pending.has(id)) {
        pending.delete(id);
        clearTimeout(timer);
        reject(error);
      }
    });
  });
}

function send(message) {
  if (socket && socket.readyState === WebSocket.OPEN) socket.send(JSON.stringify(message));
}
function feedback(context, success) {
  send({ event: success ? 'showOk' : 'showAlert', context });
}

async function handleKeyDown(event) {
  const context = event.context;
  const settings = event.payload?.settings || cachedSettings.get(context) || {};
  const exe = String(settings.exe || '').trim();
  const title = String(settings.title || '').trim();
  if (!exe) { feedback(context, false); return; }
  try {
    const reply = await requestHelper({ op: 'focus', exe, title });
    feedback(context, reply.ok === true);
    if (!reply.ok) log('Could not focus ' + exe + ': ' + (reply.reason || 'unknown'));
  } catch (error) {
    feedback(context, false);
    log(error.message);
  }
}

async function handleInspectorMessage(event) {
  if (event.payload?.command !== 'listWindows') return;
  try {
    const reply = await requestHelper({ op: 'list' });
    send({ event: 'sendToPropertyInspector', context: event.context,
      payload: { event: 'windowList', windows: Array.isArray(reply.windows) ? reply.windows : [], error: reply.ok ? '' : (reply.message || reply.reason || 'Failed to list windows') } });
  } catch (error) {
    send({ event: 'sendToPropertyInspector', context: event.context,
      payload: { event: 'windowList', windows: [], error: error.message } });
  }
}

startHelper();
socket = new WebSocket(`ws://127.0.0.1:${port}`);
socket.addEventListener('open', () => {
  send({ event: registerEvent, uuid });
});
socket.addEventListener('message', event => {
  let data;
  try { data = JSON.parse(String(event.data)); } catch { return; }
  if (data.action && data.action !== ACTION) return;
  switch (data.event) {
    case 'keyDown': void handleKeyDown(data); break;
    case 'sendToPlugin': void handleInspectorMessage(data); break;
    case 'willAppear':
    case 'didReceiveSettings':
      if (data.context && data.payload?.settings) cachedSettings.set(data.context, data.payload.settings);
      break;
    case 'willDisappear':
      if (data.context) cachedSettings.delete(data.context);
      break;
  }
});
socket.addEventListener('error', error => { log('Stream Deck socket error: ' + (error.message || 'error')); });
socket.addEventListener('close', () => { if (helper) helper.kill(); process.exit(0); });
process.on('SIGTERM', () => { if (helper) helper.kill(); process.exit(0); });
