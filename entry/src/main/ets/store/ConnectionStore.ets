/**
 * Encrypted connection storage on Asset Store Kit (AES256-GCM inside the
 * device's secure environment, keys never leave it) — the HarmonyOS
 * counterpart of the Android app's Keystore-backed SecureStorage.
 * P0 keeps a single saved connection; the multi-device store comes later.
 */

import { asset } from '@kit.AssetStoreKit';

const ALIAS = 'zcode.remoteUrl';

function strToBytes(value: string): Uint8Array {
  const out = new Uint8Array(value.length);
  for (let i = 0; i < value.length; i++) {
    out[i] = value.charCodeAt(i) & 0xFF;
  }
  return out;
}

function bytesToStr(bytes: Uint8Array): string {
  let out = '';
  for (let i = 0; i < bytes.length; i++) {
    out += String.fromCharCode(bytes[i]);
  }
  return out;
}

function aliasBytes(): Uint8Array {
  return strToBytes(ALIAS);
}

export class ConnectionStore {
  public async save(url: string): Promise<void> {
    const query: asset.AssetMap = new Map();
    query.set(asset.Tag.SECRET, strToBytes(url));
    query.set(asset.Tag.ALIAS, aliasBytes());
    query.set(asset.Tag.ACCESSIBILITY, asset.Accessibility.DEVICE_FIRST_UNLOCKED);
    try {
      await asset.remove(query);
    } catch (_e) {
      // not present yet — fine
    }
    await asset.add(query);
  }

  public async load(): Promise<string | null> {
    const query: asset.AssetMap = new Map();
    query.set(asset.Tag.ALIAS, aliasBytes());
    query.set(asset.Tag.RETURN_TYPE, asset.ReturnType.ALL);
    try {
      const result: asset.AssetMap[] = await asset.query(query);
      if (result.length === 0) {
        return null;
      }
      const secret = result[0].get(asset.Tag.SECRET);
      if (secret === undefined) {
        return null;
      }
      return bytesToStr(secret as Uint8Array);
    } catch (_e) {
      return null;
    }
  }

  public async clear(): Promise<void> {
    const query: asset.AssetMap = new Map();
    query.set(asset.Tag.ALIAS, aliasBytes());
    try {
      await asset.remove(query);
    } catch (_e) {
      // already gone
    }
  }
}
