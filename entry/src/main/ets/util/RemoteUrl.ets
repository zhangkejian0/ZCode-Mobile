/**
 * Remote URL validation + masking, ported from the Android app's util.RemoteUrl.
 * https:// is accepted from any host; http:// only from loopback / LAN / .local /
 * link-local / CGNAT (Tailscale) addresses, because the link path carries a
 * session key that plain HTTP would expose.
 */

const PRIVATE_V4_RE = /^(10\.|127\.|169\.254\.|192\.168\.|172\.(1[6-9]|2[0-9]|3[01])\.)/;

export class ParsedUrl {
  raw: string = '';
  scheme: string = '';
  host: string = '';
  isHttps: boolean = false;
}

export function parseUrl(input: string): ParsedUrl | null {
  const trimmed = input.trim();
  const m = trimmed.match(/^(https?):\/\/([^\/?#]+)/i);
  if (m === null || m.length < 3) {
    return null;
  }
  const parsed = new ParsedUrl();
  parsed.raw = trimmed;
  parsed.scheme = m[1].toLowerCase();
  parsed.host = m[2];
  parsed.isHttps = parsed.scheme === 'https';
  return parsed;
}

function isPrivateHost(hostPort: string): boolean {
  const host = hostPort.split(':')[0].toLowerCase();
  if (host === 'localhost' || host.endsWith('.local') || host.endsWith('.internal')) {
    return true;
  }
  if (host.includes(':')) {
    // IPv6 literal: allow loopback and link-local scopes
    return host === '::1' || host.toLowerCase().startsWith('fe80:') || host.startsWith('[');
  }
  if (PRIVATE_V4_RE.test(host)) {
    return true;
  }
  if (/^100\.(6[4-9]|[7-9]\d|1[01]\d|12[0-7])\./.test(host)) {
    // CGNAT 100.64.0.0/10 (Tailscale)
    return true;
  }
  return false;
}

export function isValidRemoteUrl(input: string): boolean {
  const parsed = parseUrl(input);
  if (parsed === null) {
    return false;
  }
  if (parsed.isHttps) {
    return true;
  }
  return isPrivateHost(parsed.host);
}

export function displayHost(url: string): string {
  const parsed = parseUrl(url);
  return parsed !== null ? parsed.host : url;
}

/** Mask the session token in the path so logs and UI never show it whole. */
export function redactUrl(url: string): string {
  const parsed = parseUrl(url);
  if (parsed === null) {
    return '';
  }
  const pathIndex = url.indexOf('://');
  const rest = url.substring(pathIndex + 3);
  const slash = rest.indexOf('/');
  const path = slash >= 0 ? rest.substring(slash) : '';
  const segments = path.split('/').filter((s: string) => s.length > 0);
  if (segments.length === 0) {
    return `${parsed.scheme}://${parsed.host}`;
  }
  const kept = segments.slice(0, 2).join('/');
  return `${parsed.scheme}://${parsed.host}/${kept}/…`;
}
