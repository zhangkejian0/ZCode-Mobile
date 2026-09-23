/**
 * Home: connect flow when no link is saved; greeting + composer + task list
 * once connected. Visual language follows the desktop/app: white ground,
 * plain rows, hairlines, orange only for approvals.
 */

import { router } from '@kit.ArkUI';
import { AppState } from '../store/AppState';
import { ConnectionStore } from '../store/ConnectionStore';
import { ConnectionState, Snapshot, TaskInfo, TaskStatus } from '../model/Models';
import { displayHost, isValidRemoteUrl, redactUrl } from '../util/RemoteUrl';

const COLOR_FG = '#FF171717';
const COLOR_FG_SECONDARY = '#FF666666';
const COLOR_FG_TERTIARY = '#FF999999';
const COLOR_LINE = '#FFECECEC';
const COLOR_SUCCESS = '#FF0DA05D';
const COLOR_ATTENTION = '#FFF08700';
const COLOR_DANGER = '#FFD64541';

class RemoteRoute {
  url: string = 'pages/Remote';
  params: RemoteParams = new RemoteParams();
}

class RemoteParams {
  url: string = '';
}

function remoteRoute(target: string): RemoteRoute {
  const route = new RemoteRoute();
  route.params.url = target;
  return route;
}

@Entry
@Component
struct Index {
  @State snapshot: Snapshot | null = null
  @State savedUrl: string = ''
  @State draft: string = ''
  @State urlInput: string = ''
  @State connectError: string = ''
  @State loaded: boolean = false
  private store: ConnectionStore = new ConnectionStore()
  private appState: AppState = AppState.getInstance()
  private listener = (snap: Snapshot): void => {
    this.snapshot = snap
  }

  aboutToAppear(): void {
    this.store.load().then((url: string | null) => {
      this.savedUrl = url !== null && url.length > 0 ? url : ''
      this.loaded = true
    })
    this.appState.subscribe(this.listener)
    const existing = this.appState.latest
    if (existing !== null) {
      this.snapshot = existing
    }
  }

  aboutToDisappear(): void {
    this.appState.unsubscribe(this.listener)
  }

  private connect(): void {
    const url = this.urlInput.trim()
    if (!isValidRemoteUrl(url)) {
      this.connectError = '请输入以 http:// 或 https:// 开头的有效地址；公网地址必须使用 https://'
      return
    }
    this.connectError = ''
    this.store.save(url).then(() => {
      this.savedUrl = url
      this.urlInput = ''
      router.pushUrl(remoteRoute(url))
    })
  }

  private send(): void {
    const text = this.draft.trim()
    if (text.length === 0 || this.savedUrl.length === 0) {
      return
    }
    this.draft = ''
    this.appState.pendingInject = text
    router.pushUrl(remoteRoute(this.savedUrl))
  }

  private disconnect(): void {
    this.store.clear().then(() => {
      this.savedUrl = ''
      this.snapshot = null
      this.appState.latest = null
    })
  }

  private connectionLabel(): string {
    const snap = this.snapshot
    if (this.savedUrl.length === 0) {
      return '未连接'
    }
    if (snap === null) {
      return '连接中'
    }
    if (snap.connectionHint === 'expired' || snap.connectionHint === 'unauthorized') {
      return '已过期'
    }
    if (snap.connectionHint === 'error' || snap.connectionHint === 'lost') {
      return '连接异常'
    }
    return '已连接'
  }

  private connectionColor(): string {
    const label = this.connectionLabel()
    if (label === '已连接') {
      return COLOR_SUCCESS
    }
    if (label === '未连接' || label === '连接中') {
      return COLOR_FG_TERTIARY
    }
    return COLOR_DANGER
  }

  build() {
    Column() {
      if (this.loaded && this.savedUrl.length === 0) {
        this.ConnectBody()
      } else {
        this.HomeBody()
      }
    }
    .width('100%')
    .height('100%')
    .backgroundColor('#FFFFFFFF')
  }

  @Builder
  ConnectBody() {
    Scroll() {
      Column() {
        Text('ZCode')
          .fontSize(34)
          .fontWeight(FontWeight.Bold)
          .fontColor(COLOR_FG)
          .margin({ top: 120 })
        Text('连接你的 ZCode Desktop')
          .fontSize(20)
          .fontWeight(FontWeight.Medium)
          .fontColor(COLOR_FG)
          .margin({ top: 24 })
        Text('在电脑上打开 ZCode，点左下角的「移动端远程控制」，复制链接粘贴到下面。代码、终端和 Agent 仍然在电脑上运行。')
          .fontSize(14)
          .fontColor(COLOR_FG_SECONDARY)
          .lineHeight(22)
          .margin({ top: 8, left: 20, right: 20 })
          .alignSelf(ItemAlign.Center)

        TextArea({ placeholder: 'https://…', text: this.urlInput })
          .onChange((value: string) => {
            this.urlInput = value
            this.connectError = ''
          })
          .fontSize(13)
          .fontFamily('monospace')
          .constraintSize({ minHeight: 72 })
          .borderRadius(14)
          .backgroundColor('#FFF7F7F7')
          .margin({ top: 28, left: 20, right: 20 })
          .alignSelf(ItemAlign.Center)

        if (this.connectError.length > 0) {
          Text(this.connectError)
            .fontSize(13)
            .fontColor(COLOR_DANGER)
            .margin({ top: 10 })
        }

        Button('连接')
          .width('90%')
          .height(44)
          .fontSize(15)
          .fontColor(Color.White)
          .backgroundColor(COLOR_FG)
          .margin({ top: 18 })
          .enabled(this.urlInput.trim().length > 0)
          .onClick(() => this.connect())

        Text('ZCode Mobile 是非官方客户端。')
          .fontSize(11)
          .fontColor(COLOR_FG_TERTIARY)
          .margin({ top: 48 })
      }
      .width('100%')
      .alignItems(HorizontalAlign.Center)
    }
    .scrollBar(BarState.Off)
    .width('100%')
    .height('100%')
  }

  @Builder
  HomeBody() {
    Column() {
      // Top bar
      Row() {
        Text('ZCode')
          .fontSize(15)
          .fontWeight(FontWeight.Medium)
          .fontColor(COLOR_FG)
        Blank()
        Row() {
          Circle({ width: 7, height: 7 }).fill(this.connectionColor())
          Text(this.connectionLabel())
            .fontSize(12)
            .fontColor(COLOR_FG_SECONDARY)
            .margin({ left: 6 })
        }
      }
      .width('100%')
      .height(52)
      .padding({ left: 20, right: 20 })

      Scroll() {
        Column() {
          Text(this.greeting() + '，有什么想让我帮忙的吗')
            .fontSize(20)
            .fontWeight(FontWeight.Medium)
            .fontColor(COLOR_FG)
            .margin({ top: this.snapshot === null || this.snapshot.tasks.length === 0 ? 44 : 20 })
            .alignSelf(ItemAlign.Center)

          // Composer
          Column() {
            TextArea({ placeholder: '向 ZCode 提问，任务会发送到电脑上的 ZCode Desktop', text: this.draft })
              .onChange((value: string) => {
                this.draft = value
              })
              .fontSize(15)
              .fontColor(COLOR_FG)
              .constraintSize({ minHeight: 64, maxHeight: 160 })
              .backgroundColor(Color.Transparent)
              .padding(0)
            Row() {
              Text(displayHost(this.savedUrl))
                .fontSize(12)
                .fontColor(COLOR_FG_TERTIARY)
              Blank()
              Button() {
                Text('↑')
                  .fontSize(16)
                  .fontColor(Color.White)
              }
              .width(36)
              .height(36)
              .borderRadius(18)
              .backgroundColor(this.draft.trim().length > 0 && this.savedUrl.length > 0 ? COLOR_FG : '#FFCCCCCC')
              .onClick(() => this.send())
            }
            .width('100%')
            .margin({ top: 6 })
          }
          .constraintSize({ minHeight: 120 })
          .borderRadius(14)
          .backgroundColor('#FFF7F7F7')
          .padding(14)
          .margin({ top: 20 })

          // Quick actions
          Row({ space: 8 }) {
            Button('打开 Remote 页面')
              .fontSize(13)
              .fontColor(COLOR_FG)
              .backgroundColor('#FFF0F0F0')
              .height(36)
              .borderRadius(18)
              .onClick(() => router.pushUrl(remoteRoute(this.savedUrl)))
            Button('断开连接')
              .fontSize(13)
              .fontColor(COLOR_DANGER)
              .backgroundColor('#FFF0F0F0')
              .height(36)
              .borderRadius(18)
              .onClick(() => this.disconnect())
          }
          .margin({ top: 14 })

          // Task groups
          if (this.snapshot !== null && this.snapshot.tasks.length > 0) {
            this.TaskGroup('等待确认', this.filterBy(TaskStatus.WAITING_APPROVAL))
            this.TaskGroup('进行中', this.filterBy(TaskStatus.RUNNING).concat(this.filterBy(TaskStatus.QUEUED)))
            this.TaskGroup('最近',
              this.filterBy(TaskStatus.COMPLETED).concat(this.filterBy(TaskStatus.FAILED))
                .concat(this.filterBy(TaskStatus.CANCELLED)).slice(0, 10))
          } else {
            Text('已连接 ' + displayHost(this.savedUrl) + ' · 打开 Remote 页面后任务会显示在这里')
              .fontSize(12)
              .fontColor(COLOR_FG_TERTIARY)
              .margin({ top: 36 })
              .textAlign(TextAlign.Center)
          }
        }
        .width('100%')
        .padding({ left: 20, right: 20 })
      }
      .scrollBar(BarState.Off)
      .layoutWeight(1)
      .align(Alignment.Top)
    }
    .width('100%')
    .height('100%')
  }

  @Builder
  TaskRow(task: TaskInfo) {
    Row() {
      Column() {
        Text(task.title)
          .fontSize(15)
          .fontColor(COLOR_FG)
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
        if (task.currentStep.length > 0) {
          Text(task.currentStep)
            .fontSize(13)
            .fontColor(COLOR_FG_SECONDARY)
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
            .margin({ top: 2 })
        }
      }
      .layoutWeight(1)
      Text(this.label(task.status))
        .fontSize(12)
        .fontColor(this.statusColor(task.status))
        .margin({ left: 12 })
    }
    .width('100%')
    .padding({ top: 13, bottom: 13 })
  }

  @Builder
  TaskGroup(label: string, tasks: TaskInfo[]) {
    if (tasks.length > 0) {
      Column() {
        Row() {
          Text(label)
            .fontSize(12)
            .fontColor(COLOR_FG_TERTIARY)
          Blank()
          Text(tasks.length.toString())
            .fontSize(12)
            .fontColor(COLOR_FG_TERTIARY)
        }
        .width('100%')
        .margin({ top: 20, bottom: 4 })
        ForEach(tasks, (task: TaskInfo) => {
          Column() {
            this.TaskRow(task)
            Divider().color(COLOR_LINE).strokeWidth(1)
          }
        }, (task: TaskInfo) => task.id)
      }
      .width('100%')
    }
  }

  private filterBy(status: TaskStatus): TaskInfo[] {
    const snap = this.snapshot
    if (snap === null) {
      return []
    }
    return snap.tasks.filter((t: TaskInfo) => t.status === status)
  }

  private label(status: TaskStatus): string {
    switch (status) {
      case TaskStatus.RUNNING:
        return '运行中'
      case TaskStatus.WAITING_APPROVAL:
        return '需要确认'
      case TaskStatus.COMPLETED:
        return '已完成'
      case TaskStatus.FAILED:
        return '失败'
      case TaskStatus.QUEUED:
        return '排队中'
      case TaskStatus.CANCELLED:
        return '已取消'
      default:
        return ''
    }
  }

  private statusColor(status: TaskStatus): string {
    if (status === TaskStatus.WAITING_APPROVAL) {
      return COLOR_ATTENTION
    }
    if (status === TaskStatus.RUNNING) {
      return COLOR_SUCCESS
    }
    if (status === TaskStatus.FAILED) {
      return COLOR_DANGER
    }
    return COLOR_FG_TERTIARY
  }

  private greeting(): string {
    const hour = new Date().getHours()
    if (hour >= 5 && hour <= 10) {
      return '上午好呀'
    }
    if (hour >= 11 && hour <= 13) {
      return '中午好'
    }
    if (hour >= 14 && hour <= 17) {
      return '下午好'
    }
    return '晚上好'
  }
}
