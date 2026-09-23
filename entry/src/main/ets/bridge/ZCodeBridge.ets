/**
 * The object injected into the Remote page as window.ZCodeAndroidBridge —
 * the name observer.js already looks for, so the JS side stays unchanged.
 * Sync methods only: observer.js fire-and-forgets both calls.
 *
 * IMPORTANT: these run on a web IPC thread. Only emitter (thread-safe) here;
 * no AppStorage / UI state access.
 */

import { emitter } from '@kit.BasicServicesKit';
import { SNAPSHOT_EVENT_ID } from '../store/AppState';

export class ZCodeBridge {
  public onPageState(json: string): string {
    const event: emitter.InnerEvent = {
      eventId: SNAPSHOT_EVENT_ID,
      priority: emitter.EventPriority.LOW
    };
    const map: Record<string, Object> = { 'json': json };
    const payload: emitter.EventData = { data: map };
    emitter.emit(event, payload);
    return 'ok';
  }

  public onEvent(json: string): string {
    const event: emitter.InnerEvent = {
      eventId: SNAPSHOT_EVENT_ID,
      priority: emitter.EventPriority.LOW
    };
    const map: Record<string, Object> = { 'event': json };
    const payload: emitter.EventData = { data: map };
    emitter.emit(event, payload);
    return 'ok';
  }
}
