// AIDifficulty.ets
import { font, router } from '@kit.ArkUI';

@Entry
@Component
struct AIDifficulty {
  aboutToAppear() {
    font.registerFont({
      familyName: $r('app.string.index_title_font_name'),
      familySrc: $r('app.string.index_title_font_src'),
    })
  }

  build() {
    // 使用Stack包裹，使返回按钮独立悬浮
    Stack({ alignContent: Alignment.TopStart }) {
      Column() {
        Text('选择难度')
          .fontSize(30)
          .fontWeight(FontWeight.Bold)
          .fontFamily('SThuawenxingkai')
          .margin({ top: 80, bottom: 60 })

        Column() {
          // 简单难度按钮（移除错误的“返回”文字）
          Button() {
            Text('简单难度')
              .fontSize(20)
              .fontWeight(FontWeight.Bold)
              .fontColor('#000')
              .fontFamily('SThuawenxingkai')
          }
          .onClick(() => {
            router.pushUrl({ url: "pages/Classic", params: { gameMode: 1 } })
          })
          .type(ButtonType.Capsule)
          .difficultyButtonStyle()

          Button() {
            Text('中等难度')
              .fontSize(20)
              .fontWeight(FontWeight.Bold)
              .fontColor('#000')
              .fontFamily('SThuawenxingkai')
          }
          .onClick(() => {
            router.pushUrl({ url: "pages/Classic", params: { gameMode: 2 } })
          })
          .type(ButtonType.Capsule)
          .difficultyButtonStyle()

          Button() {
            Text('困难难度')
              .fontSize(20)
              .fontWeight(FontWeight.Bold)
              .fontColor('#000')
              .fontFamily('SThuawenxingkai')
          }
          .onClick(() => {
            router.pushUrl({ url: "pages/Classic", params: { gameMode: 3 } })
          })
          .type(ButtonType.Capsule)
          .difficultyButtonStyle()
        }
      }
      .height('100%')
      .width('100%')
      .justifyContent(FlexAlign.Center)
      .backgroundImage($r("app.media.background_new"))
      .backgroundImageSize(ImageSize.Cover)

      // 独立的返回按钮，定位到左上角
      Button({ type: ButtonType.Circle }) {
        Text('返回')
          .fontSize(14)
          .fontColor('#000')
      }
      .width(40)
      .height(40)
      .margin({ top: 20, left: 20 }) // 明确左上角定位
      .backgroundColor('rgba(255,255,255,0.3)')
      .onClick(() => {
        router.back();
      })
    }
    .width('100%')
    .height('100%')
  }

  @Styles
  difficultyButtonStyle() {
    .margin({ top: 25 })
    .backgroundColor($r('sys.color.button_background_color_transparent'))
    .width('45%')
    .height('6%')
    .borderRadius(20)
    .shadow({
      radius: 8,
      color: '#000',
      offsetX: 0,
      offsetY: 4
    })
  }
}