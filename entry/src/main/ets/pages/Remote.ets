/**
 * The Remote page: an ArkWeb Web component hosting the official ZCode Remote
 * page, with window.ZCodeAndroidBridge injected via javaScriptProxy (the exact
 * name observer.js expects) and the observer + selectors injected from rawfile
 * on every onPageEnd — the same contract as the Android app.
 */

import { webview } from '@kit.ArkWeb';
import { router } from '@kit.ArkUI';
import { AppState } from '../store/AppState';
import { ZCodeBridge } from '../bridge/ZCodeBridge';

const COLOR_FG = '#FF171717';
const COLOR_FG_TERTIARY = '#FF999999';
const COLOR_DANGER = '#FFD64541';

class RemoteParams {
  url: string = '';
}

async function readRawfile(context: Context, name: string): Promise<string> {
  const data: Uint8Array = await context.resourceManager.getRawFileContent(name);
  let text = '';
  for (let i = 0; i < data.length; i++) {
    text += String.fromCharCode(data[i]);
  }
  return text;
}

@Entry
@Component
struct Remote {
  @State pageReady: boolean = false
  @State pageError: string = ''
  controller: webview.WebviewController = new webview.WebviewController()
  bridge: ZCodeBridge = new ZCodeBridge()
  appState: AppState = AppState.getInstance()
  remoteUrl: string = ''

  aboutToAppear(): void {
    const params = router.getParams() as RemoteParams;
    if (params !== undefined && params !== null && params.url.length > 0) {
      this.remoteUrl = params.url;
    }
    if (this.remoteUrl.length === 0) {
      router.back();
    }
  }

  private async injectObserver(): Promise<void> {
    try {
      const context = this.getUIContext().getHostContext();
      if (context === undefined) {
        return;
      }
      const observer = await readRawfile(context, 'zcode-observer.js');
      const selectors = await readRawfile(context, 'zcode-selectors.json');
      const script = '(' + observer + ')(' + selectors + ');';
      await this.controller.runJavaScript(script);
    } catch (_e) {
      // page navigating away; the next onPageEnd retries
    }
  }

  /** Fill the Remote page composer with text typed on Home, then click send. */
  private async maybeInjectComposer(): Promise<void> {
    const text = this.appState.consumeInject();
    if (text.length === 0) {
      return;
    }
    try {
      const context = this.getUIContext().getHostContext();
      if (context === undefined) {
        return;
      }
      const selectors = await readRawfile(context, 'zcode-selectors.json');
      const script =
        '(function(){try{' +
        'var cfg=' + selectors + ';' +
        'var input=document.querySelector(cfg.composerInput.join(","));' +
        'if(!input)return "no-input";' +
        'input.focus();' +
        'var value=' + JSON.stringify(text) + ';' +
        'if("value" in input){input.value=value;input.dispatchEvent(new Event("input",{bubbles:true}));' +
        '}else{input.textContent=value;input.dispatchEvent(new InputEvent("input",{bubbles:true}));}' +
        'setTimeout(function(){var send=document.querySelector(cfg.composerSend.join(","));' +
        'if(send)send.click();},250);' +
        'return "ok";' +
        '}catch(e){return "err";}})();';
      await this.controller.runJavaScript(script);
    } catch (_e) {
      // ignore; user can type directly in the page
    }
  }

  build() {
    Column() {
      // Top bar
      Row() {
        Button('⟨')
          .fontSize(18)
          .fontColor(COLOR_FG)
          .backgroundColor(Color.Transparent)
          .onClick(() => router.back())
        Text('Remote')
          .fontSize(15)
          .fontWeight(FontWeight.Medium)
          .fontColor(COLOR_FG)
          .margin({ left: 4 })
        Blank()
        if (!this.pageReady && this.pageError.length === 0) {
          LoadingProgress().width(18).height(18).color(COLOR_FG_TERTIARY)
        }
      }
      .width('100%')
      .height(48)
      .padding({ left: 8, right: 12 })

      if (this.pageError.length > 0) {
        Column() {
          Text(this.pageError)
            .fontSize(14)
            .fontColor(COLOR_DANGER)
            .textAlign(TextAlign.Center)
            .padding(24)
          Button('重试')
            .fontSize(14)
            .fontColor(Color.White)
            .backgroundColor(COLOR_FG)
            .height(38)
            .borderRadius(19)
            .padding({ left: 24, right: 24 })
            .onClick(() => {
              this.pageError = ''
              try {
                this.controller.refresh()
              } catch (_e) {
              }
            })
        }
        .layoutWeight(1)
        .width('100%')
        .justifyContent(FlexAlign.Center)
      } else {
        Web({ src: this.remoteUrl, controller: this.controller })
          .javaScriptAccess(true)
          .domStorageAccess(true)
          .fileAccess(false)
          .mixedMode(MixedMode.None)
          .onlineImageAccess(true)
          .javaScriptProxy({
            object: this.bridge,
            name: 'ZCodeAndroidBridge',
            methodList: ['onPageState', 'onEvent'],
            controller: this.controller
          })
          .onPageEnd(() => {
            this.pageReady = true
            this.injectObserver()
            this.maybeInjectComposer()
          })
          .onPageBegin(() => {
            this.pageReady = false
          })
          .onErrorReceive((event) => {
            if (event.request.isMainFrame()) {
              this.pageError = '加载失败 (' + event.error.getErrorCode() + '): ' + event.error.getErrorInfo()
            }
          })
          .onHttpErrorReceive((event) => {
            if (event.request.isMainFrame()) {
              const code = event.response.getResponseCode()
              if (code === 401 || code === 403) {
                this.pageError = '会话已过期，请在电脑上重新生成链接'
              }
            }
          })
          .layoutWeight(1)
          .width('100%')
      }
    }
    .width('100%')
    .height('100%')
    .backgroundColor('#FFFFFFFF')
  }
}
