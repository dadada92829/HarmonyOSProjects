// Index.ets
import { font, router } from '@kit.ArkUI';

@Entry
@Component
struct Index {
  @State isMusicOn: boolean = true

  aboutToAppear() {
    font.registerFont({
      familyName: $r('app.string.index_title_font_name'),
      familySrc: $r('app.string.index_title_font_src'),
    })
  }

  build() {
    Stack({ alignContent: Alignment.TopEnd }) {
      Column() {
        // 标题
        Row() {
          Text($r("app.string.index_title"))
            .fontSize($r('app.float.title_text_font_size'))
            .fontWeight(FontWeight.Bold)
            .fontFamily('SThuawenxingkai')
        }
        .margin({ top: 50 })

        // 按钮容器
        Column() {
          // 人人对战按钮
          Button() {
            Text('人人对战')
              .fontSize(22)
              .fontWeight(FontWeight.Bold)
              .fontColor('#000')
              .fontFamily('SThuawenxingkai')
          }
          .onClick(() => {
            // 传递模式0（人人对战）
            router.pushUrl({
              url: "pages/Classic",
              params: { gameMode: 0 }
            })
          })
          .type(ButtonType.Capsule)
          .mainButtonStyle()

          // 人机对战按钮
          Button() {
            Text('人机对战')
              .fontSize(22)
              .fontWeight(FontWeight.Bold)
              .fontColor('#000')
              .fontFamily('SThuawenxingkai')
          }
          .onClick(() => {
            // 跳转到难度选择页
            router.pushUrl({ url: "pages/AIDifficulty" })
          })
          .type(ButtonType.Capsule)
          .mainButtonStyle()
        }
      }
      .height('100%')
      .width('100%')
      .justifyContent(FlexAlign.Center)
      .backgroundImage($r("app.media.background_new")) // 更换为新背景图
      .backgroundImageSize(ImageSize.Cover)
    }
    .width('100%')
    .height('100%')
  }

  // 主按钮样式（统一两个按钮的外观）
  @Styles
  mainButtonStyle() {
    .margin({ top: 30 }) // 两个按钮间距
    .backgroundColor($r('sys.color.button_background_color_transparent'))
    .width('50%') // 稍宽一些更协调
    .height('7%')
    .borderRadius(20)
    .shadow({
      radius: 10,
      color: '#000',
      offsetX: 0,
      offsetY: 5
    })
  }
}
