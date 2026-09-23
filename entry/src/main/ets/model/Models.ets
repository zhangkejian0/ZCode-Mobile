/**
 * Task / snapshot models and JSON parsing, ported from the Android app's
 * PageSnapshotReducer + TaskStatusMapper. The observer.js payload shape is
 * the contract; keep parsing defensive — the page is not ours.
 */

export enum TaskStatus {
  WAITING_APPROVAL = 0,
  RUNNING = 1,
  QUEUED = 2,
  COMPLETED = 3,
  FAILED = 4,
  CANCELLED = 5,
  UNKNOWN = 6
}

export enum ConnectionState {
  DISCONNECTED = 0,
  CONNECTING = 1,
  CONNECTED = 2,
  SESSION_EXPIRED = 3,
  ERROR = 4
}

export class TaskInfo {
  id: string = '';
  title: string = '';
  status: TaskStatus = TaskStatus.UNKNOWN;
  currentStep: string = '';
}

export class Snapshot {
  url: string = '';
  title: string = '';
  connectionHint: string = '';
  errorText: string = '';
  sessionId: string = '';
  sessionTitle: string = '';
  tasks: TaskInfo[] = [];
  observerActive: boolean = false;
}

const WAIT_RE = /(等待确认|需要确认|待确认|waiting for confirm|waiting approval|needs confirmation)/i;
const RUN_RE = /(运行中|正在执行|执行中|running|in progress|working)/i;
const QUEUED_RE = /(排队|queued)/i;
const DONE_RE = /(已完成|完成|completed|complete)/i;
const FAIL_RE = /(失败|错误|failed|error)/i;
const CANCEL_RE = /(已取消|取消|cancelled|canceled)/i;

export function mapStatus(raw: string): TaskStatus {
  if (!raw) {
    return TaskStatus.UNKNOWN;
  }
  if (WAIT_RE.test(raw)) {
    return TaskStatus.WAITING_APPROVAL;
  }
  if (RUN_RE.test(raw)) {
    return TaskStatus.RUNNING;
  }
  if (QUEUED_RE.test(raw)) {
    return TaskStatus.QUEUED;
  }
  if (FAIL_RE.test(raw)) {
    return TaskStatus.FAILED;
  }
  if (CANCEL_RE.test(raw)) {
    return TaskStatus.CANCELLED;
  }
  if (DONE_RE.test(raw)) {
    return TaskStatus.COMPLETED;
  }
  return TaskStatus.UNKNOWN;
}

export function statusLabel(status: TaskStatus): string {
  switch (status) {
    case TaskStatus.RUNNING:
      return '运行中';
    case TaskStatus.WAITING_APPROVAL:
      return '需要确认';
    case TaskStatus.COMPLETED:
      return '已完成';
    case TaskStatus.FAILED:
      return '失败';
    case TaskStatus.QUEUED:
      return '排队中';
    case TaskStatus.CANCELLED:
      return '已取消';
    default:
      return '';
  }
}

function asRecord(value: Object | undefined): Record<string, Object> | null {
  if (value !== undefined && value !== null && typeof value === 'object') {
    return value as Record<string, Object>;
  }
  return null;
}

function getStr(rec: Record<string, Object>, key: string): string {
  const v = rec[key];
  if (v === undefined || v === null) {
    return '';
  }
  if (typeof v === 'string') {
    return v as string;
  }
  return String(v);
}

function getBool(rec: Record<string, Object>, key: string): boolean {
  const v = rec[key];
  return v === true;
}

export function connectionStateFromHint(hint: string): ConnectionState {
  if (hint === 'ok' || hint === 'connected') {
    return ConnectionState.CONNECTED;
  }
  if (hint === 'expired' || hint === 'unauthorized') {
    return ConnectionState.SESSION_EXPIRED;
  }
  if (hint === 'error' || hint === 'lost') {
    return ConnectionState.ERROR;
  }
  return ConnectionState.CONNECTED;
}

export function parseSnapshot(json: string): Snapshot | null {
  try {
    const root = asRecord(JSON.parse(json) as Object);
    if (root === null) {
      return null;
    }
    const snap = new Snapshot();
    snap.url = getStr(root, 'url');
    snap.title = getStr(root, 'title');
    snap.connectionHint = getStr(root, 'connectionHint');
    snap.errorText = getStr(root, 'errorText');
    snap.sessionId = getStr(root, 'sessionId');
    snap.sessionTitle = getStr(root, 'sessionTitle');
    snap.observerActive = getBool(root, 'observerActive');

    const tasksRaw = root['tasks'];
    if (Array.isArray(tasksRaw)) {
      const tasksArr = tasksRaw as Object[];
      for (let i = 0; i < tasksArr.length; i++) {
        const t = asRecord(tasksArr[i]);
        if (t === null) {
          continue;
        }
        const task = new TaskInfo();
        task.id = getStr(t, 'id') || `idx-${i}`;
        task.title = getStr(t, 'title');
        task.currentStep = getStr(t, 'step');
        task.status = mapStatus(getStr(t, 'status'));
        if (task.title.length > 0) {
          snap.tasks.push(task);
        }
      }
    }
    return snap;
  } catch (_e) {
    return null;
  }
}
