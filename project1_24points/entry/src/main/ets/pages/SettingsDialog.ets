// 文件: entry/src/main/ets/pages/SettingsDialog.ets

@CustomDialog
export struct SettingsDialog {
  // --- 核心关键点 ---
  // 必须声明这个名为 controller 的属性。
  // 系统会自动监测到它，并自动为你注入控制器实例，不需要你手动传！
  controller: CustomDialogController;

  @StorageLink('selectedBackground') selectedBg: Resource = $r('app.media.bg_dark');
  @StorageLink('fontColor') fontColor: Color = Color.White;

  build() {
    Column() {
      Text('选择背景主题')
        .fontSize(20)
        .fontWeight(FontWeight.Bold)
        .padding(20)

      Flex({ wrap: FlexWrap.Wrap, justifyContent: FlexAlign.Center, alignItems: ItemAlign.Center }) {
        Button('暗色主题')
          .fontSize(16)
          .fontColor(Color.White)
          .backgroundColor('#555555')
          .borderRadius(20)
          .padding({ left: 20, right: 20, top: 10, bottom: 10 })
          .margin(8)
          .onClick(() => {
            this.selectedBg = $r('app.media.bg_dark');
            this.fontColor = Color.White;
            // 直接使用系统自动注入的 controller 来关闭弹窗
            this.controller.close();
          })

        Button('亮色主题')
          .fontSize(16)
          .fontColor('#333333')
          .backgroundColor('#FEF7E0')
          .borderRadius(20)
          .padding({ left: 20, right: 20, top: 10, bottom: 10 })
          .margin(8)
          .onClick(() => {
            this.selectedBg = $r('app.media.bg_light');
            this.fontColor = Color.Black;
            this.controller.close();
          })

        Button('赛博朋克')
          .fontSize(16)
          .fontColor('#9400D3')
          .backgroundColor('#FFFF00')
          .borderRadius(20)
          .padding({ left: 20, right: 20, top: 10, bottom: 10 })
          .margin(8)
          .onClick(() => {
            this.selectedBg = $r('app.media.bg_cyber');
            this.fontColor = Color.White;
            this.controller.close();
          })
      }
      .width('90%')
      .padding({ bottom: 20 })
    }
    .borderRadius(25)
    .backgroundColor('#F1F3F5')
  }
}