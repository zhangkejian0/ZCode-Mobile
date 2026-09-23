/**
 * App-wide observed state. The ArkWeb javaScriptProxy callbacks arrive on a
 * web IPC thread, so the bridge never touches state directly — it emits via
 * the thread-safe emitter, and AppState (subscribed once per ability on the
 * UI thread) is the only writer. Pages subscribe to AppState.
 */

import { emitter } from '@kit.BasicServicesKit';
import { parseSnapshot, Snapshot } from '../model/Models';

export const SNAPSHOT_EVENT_ID = 9527;

export type SnapshotListener = (snapshot: Snapshot) => void;

export class AppState {
  private static instance: AppState | null = null;
  private listeners: SnapshotListener[] = [];
  private initialized: boolean = false;

  latest: Snapshot | null = null;
  /** Text typed on the Home composer, waiting to be filled into the Remote page. */
  pendingInject: string = '';
  /** Raw diagnostics for the developer view later. */
  lastEventJson: string = '';

  public static getInstance(): AppState {
    if (AppState.instance === null) {
      AppState.instance = new AppState();
    }
    return AppState.instance;
  }

  /** Called once from EntryAbility.onCreate; wires the thread-safe emitter in. */
  public init(): void {
    if (this.initialized) {
      return;
    }
    this.initialized = true;
    const event: emitter.InnerEvent = { eventId: SNAPSHOT_EVENT_ID };
    emitter.on(event, (data: emitter.EventData) => {
      const payload = data.data as Record<string, Object>;
      if (payload === undefined || payload === null) {
        return;
      }
      const jsonVal = payload['json'];
      const json = typeof jsonVal === 'string' ? jsonVal as string : '';
      if (json.length > 0) {
        const snap = parseSnapshot(json);
        if (snap !== null) {
          this.latest = snap;
          for (let i = 0; i < this.listeners.length; i++) {
            try {
              this.listeners[i](snap);
            } catch (_e) {
              // one bad listener must not break the rest
            }
          }
        }
      }
      const evtVal = payload['event'];
      const evt = typeof evtVal === 'string' ? evtVal as string : '';
      if (evt.length > 0) {
        this.lastEventJson = evt;
      }
    });
  }

  public subscribe(listener: SnapshotListener): void {
    if (this.listeners.indexOf(listener) < 0) {
      this.listeners.push(listener);
    }
  }

  public unsubscribe(listener: SnapshotListener): void {
    const idx = this.listeners.indexOf(listener);
    if (idx >= 0) {
      this.listeners.splice(idx, 1);
    }
  }

  public consumeInject(): string {
    const value = this.pendingInject;
    this.pendingInject = '';
    return value;
  }
}

/** Unused now; kept as the hint vocabulary shared with the Android app. */
export const ConnectionHints: string[] = ['ok', 'expired', 'lost', 'error', 'unauthorized'];
