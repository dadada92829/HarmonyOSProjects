// D:\HarmonyOSProjects\app_24point\entry\src\main\ets\pages\Index.ets

import router from '@ohos.router'
import prompt from '@ohos.promptAction'
import { SettingsDialog } from './SettingsDialog' // <-- 添加这一行

// --- 新增代码段 开始 ---
// 使用AppStorage来全局和持久化存储用户的选择
// @StorageLink会双向绑定UI组件和持久化数据
// 我们为背景图和字体颜色都创建一个持久化状态
// --- 新增代码段 结束 ---

interface Card {
  id: number
  value: number
  imgSrc: Resource
  isFlipped: boolean
}

const CARD_BACK_IMG = $r('app.media.img_14')

function getCardImage(value: number): Resource {
  // ... (此函数保持不变)
  switch (value) {
    case 1:
      return $r('app.media.img') // A
    case 2:
      return $r('app.media.img_1') // 2
    case 3:
      return $r('app.media.img_2') // 3
    case 4:
      return $r('app.media.img_3') // 4
    case 5:
      return $r('app.media.img_4') // 5
    case 6:
      return $r('app.media.img_5') // 6
    case 7:
      return $r('app.media.img_6') // 7
    case 8:
      return $r('app.media.img_7') // 8
    case 9:
      return $r('app.media.img_8') // 9
    case 10:
      return $r('app.media.img_9') // 10
    case 11:
      return $r('app.media.img_10') // J
    case 12:
      return $r('app.media.img_11') // Q
    case 13:
      return $r('app.media.img_12') // K
    default:
      return $r('app.media.img_14') // 背面
  }
}

@Entry
@Component
struct Index {
  @State displayDeck: Card[] = []
  @State selectedCards: Card[] = []

  // --- 新增代码段 开始 ---
  // 使用@StorageLink将变量与AppStorage中的'selectedBackground'项关联
  // 如果AppStorage中没有此项，则使用默认值 bg_dark
  @StorageLink('selectedBackground') selectedBg: Resource = $r('app.media.bg_dark');
  // 同样，为字体颜色创建一个关联状态
  @StorageLink('fontColor') fontColor: Color = Color.White;
  // --- 新增代码段 结束 ---
  // 1. 定义一个空的、被@Builder修饰的方法作为占位符

  private dialogController: CustomDialogController = new CustomDialogController({
    builder: SettingsDialog({}), // 这里传一个空对象即可！
    autoCancel: true,
    alignment: DialogAlignment.Center
  });

  // aboutToAppear 恢复原样，只负责游戏初始化
  aboutToAppear() {
    this.initializeGame();
  }

  // ... (initializeGame, onCardClick, undoLastSelection, startGame 函数保持不变) ...
  initializeGame() {
    const fullDeck: Card[] = []
    let idCounter = 0
    for (let i = 0; i < 4; i++) {
      for (let value = 1; value <= 13; value++) {
        fullDeck.push({
          id: idCounter++,
          value: value,
          imgSrc: getCardImage(value),
          isFlipped: false
        })
      }
    }
    fullDeck.sort(() => Math.random() - 0.5)
    this.displayDeck = fullDeck.slice(0, 25)
    this.selectedCards = []
  }

  onCardClick(clickedCard: Card) {
    if (clickedCard.isFlipped || this.selectedCards.length >= 4) {
      if (this.selectedCards.length >= 4 && !clickedCard.isFlipped) {
        prompt.showToast({ message: '已经翻开4张牌了！' })
      }
      return
    }
    const newDeck = [...this.displayDeck]
    const cardIndex = newDeck.findIndex(c => c.id === clickedCard.id)
    if (cardIndex > -1) {
      newDeck[cardIndex].isFlipped = true
      this.displayDeck = newDeck
      this.selectedCards = [...this.selectedCards, newDeck[cardIndex]]
    }
  }

  undoLastSelection() {
    if (this.selectedCards.length === 0) {
      return
    }
    const lastCard = this.selectedCards[this.selectedCards.length - 1]
    const newDeck = [...this.displayDeck]
    const cardIndex = newDeck.findIndex(c => c.id === lastCard.id)
    if (cardIndex > -1) {
      newDeck[cardIndex].isFlipped = false
      this.displayDeck = newDeck
    }
    this.selectedCards = this.selectedCards.slice(0, -1)
  }

  clearAllSelections() {
    if (this.selectedCards.length === 0) {
      return;
    }

    const newDeck = [...this.displayDeck];
    // 遍历所有已选择的牌
    this.selectedCards.forEach(selectedCard => {
      const cardIndex = newDeck.findIndex(c => c.id === selectedCard.id);
      if (cardIndex > -1) {
        // 将它们的状态改回“未翻开”
        newDeck[cardIndex].isFlipped = false;
      }
    });

    this.displayDeck = newDeck; // 一次性更新UI
    this.selectedCards = [];     // 清空已选列表
  }

  startGame() {
    if (this.selectedCards.length === 4) {
      const cardValues = this.selectedCards.map(card => card.value)
      router.pushUrl({
        url: 'pages/GamePage',
        params: {
          cards: JSON.stringify(cardValues)
        }
      })
    }
  }


  build() {
    // --- 修改代码段 开始 ---
    // 将原有的 .backgroundColor 修改为 .backgroundImage
    Column() {
      Row({ space: 10 }) { // 使用Row来水平排列标题和按钮
        Text('24点游戏')
          .fontSize(24)
          .fontWeight(FontWeight.Bold)
          .fontColor(this.fontColor)
          .layoutWeight(1) // 让标题占据所有剩余空间
          .padding({ top: 0,left: 60 })

        // 这就是我们新的设置按钮
        Button('⚙ 背景设置')
          .fontSize(16)
          .fontColor('#ffffff')
          .backgroundColor('#555555')
          .borderRadius(20)
          .padding({ left: 15, right: 15, top: 8, bottom: 8 })
          .onClick(() => {
            // 点击按钮时，命令控制器打开弹窗
            this.dialogController.open();
          })
      }
      .width('100%')
      .padding(20)
      .alignItems(VerticalAlign.Center) // 确保标题和按钮垂直居中对齐
      // --- ↑↑↑ 修改结束 ↑↑↑ ---

      // --- 新增代码段 开始 ---
      // 添加背景选择按钮

      Grid() {
        // ... (Grid内部代码保持不变) ...
        ForEach(this.displayDeck, (card: Card) => {
          GridItem() {
            Image(card.isFlipped ? card.imgSrc : CARD_BACK_IMG)
              .objectFit(ImageFit.Contain)
              .borderRadius(5)
              .onClick(() => this.onCardClick(card))
          }
        })
      }
      .columnsTemplate('1fr 1fr 1fr 1fr 1fr')
      .rowsTemplate('1fr 1fr 1fr 1fr 1fr')
      .rowsGap(8)
      .columnsGap(8)
      .padding(15)
      .layoutWeight(1)

      Row() {
        Text(`已翻开: ${this.selectedCards.length} / 4`)
          .fontSize(18)
          .fontColor(this.fontColor) // 使用动态字体颜色
          .layoutWeight(1)
          .padding({ left: 20 })

        if (this.selectedCards.length > 1) { // 超过1张牌时显示“清除”
          Button('一键清除')
            .fontSize(16)
            .margin({ right: 10 })
            .backgroundColor(Color.Gray) // 给个不同的颜色以区分
            .onClick(() => this.clearAllSelections())
        }

        if (this.selectedCards.length > 0) {
          Button('撤销')
            .fontSize(16)
            .margin({ right: 10 })
            .onClick(() => this.undoLastSelection())
        }

        Button('开始计算')
          .fontSize(18)
          .enabled(this.selectedCards.length === 4)
          .onClick(() => this.startGame())
      }
      .width('100%')
      .height(60)
      .padding({ right: 20 })
      .backgroundColor(this.fontColor === Color.White ? '#555555' : '#DDDDDD') // 底部栏也根据主题变色
      .justifyContent(FlexAlign.End)
    }
    .width('100%')
    .height('100%')
    .backgroundImage(this.selectedBg)
    .backgroundImageSize(ImageSize.Cover)
    .backgroundImagePosition(Alignment.Center) // 使用这个独立的修饰符来设置居中对齐
    // --- 修改代码段 结束 ---
  }
}
