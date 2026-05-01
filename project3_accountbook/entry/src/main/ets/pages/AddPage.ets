import { router } from '@kit.ArkUI';
import { RecordType } from '../model/RecordType';
import RdbUtils from '../common/utils/RdbUtils';
import { promptAction } from '@kit.ArkUI';

@Entry
@Component
struct AddPage {
  @State type: RecordType = RecordType.EXPENSE;
  @State amount: number = 0;
  @State inputStr: string = '';
  @State selectedCategory: string = '餐饮';
  @State remark: string = '';

  private expenseCategories: string[] = ['餐饮', '交通', '购物', '娱乐', '医疗', '教育', '其他'];
  private incomeCategories: string[] = ['工资', '兼职', '理财', '礼金', '其他'];

  build() {
    Column() {
      // 1. 顶部导航栏
      Row() {
        SymbolGlyph($r('sys.symbol.chevron_left'))
          .fontSize(24)
          .fontColor(['#191919'])
          .onClick(() => {
            router.back();
          })

        Text('记一笔')
          .fontSize(20)
          .fontWeight(FontWeight.Bold)
          .layoutWeight(1)
          .textAlign(TextAlign.Center)
          .margin({ right: 24 })
      }
      .width('100%')
      .height(56)
      .padding({ left: 16, right: 16 })

      // 2. 类型切换
      Row() {
        this.TypeButton('支出', RecordType.EXPENSE)
        this.TypeButton('收入', RecordType.INCOME)
      }
      .width('90%')
      .height(40)
      .backgroundColor('#F1F3F5')
      .borderRadius(20)
      .margin({ top: 10, bottom: 20 })
      .padding(2)

      // 3. 金额输入
      Column() {
        Text('金额')
          .fontSize(14)
          .fontColor('#999999')
          .alignSelf(ItemAlign.Start)

        Row() {
          Text('¥')
            .fontSize(30)
            .fontWeight(FontWeight.Bold)
            .fontColor('#191919')
            .margin({ right: 10 })

          TextInput({ text: this.inputStr, placeholder: '0.00' })
            .fontSize(40) // 输入金额时可以大一点
            .fontWeight(FontWeight.Bold)
            .caretColor('#007DFF')
            .backgroundColor(Color.Transparent)
            .padding(0)
            .height(60)
            .layoutWeight(1)
            .type(InputType.Number)
            .onChange((value) => {
              this.inputStr = value;
              this.amount = parseFloat(value) || 0;
            })
        }
        .width('100%')
        .border({ width: { bottom: 1 }, color: '#F1F3F5' })
        .padding({ bottom: 10 })

        TextInput({ placeholder: '备注 (可选)' })
          .fontSize(16)
          .backgroundColor(Color.Transparent)
          .margin({ top: 10 })
          .onChange((value) => {
            this.remark = value;
          })
      }
      .width('90%')
      .padding(20)
      .backgroundColor(Color.White)
      .borderRadius(16)
      .shadow({ radius: 10, color: '#10000000', offsetY: 5 })

      // 4. 分类选择
      Text('选择分类')
        .fontSize(14)
        .fontColor('#999999')
        .width('90%')
        .margin({ top: 20, bottom: 10 })

      Grid() {
        ForEach(this.type === RecordType.EXPENSE ? this.expenseCategories : this.incomeCategories,
          (item: string) => {
            GridItem() {
              Text(item)
                .fontSize(14)
                .fontColor(this.selectedCategory === item ? Color.White : '#191919')
                .backgroundColor(this.selectedCategory === item ? '#007DFF' : '#F1F3F5')
                .padding({ top: 8, bottom: 8, left: 16, right: 16 })
                .borderRadius(16)
                .onClick(() => {
                  this.selectedCategory = item;
                })
            }
          }
        )
      }
      .columnsTemplate('1fr 1fr 1fr 1fr')
      .rowsGap(12)
      .columnsGap(8)
      .width('90%')
      .height(150)

      Blank()

      Button('保 存')
        .width('90%')
        .height(50)
        .fontSize(18)
        .backgroundColor('#007DFF')
        .margin({ bottom: 30 })
        .onClick(() => {
          this.saveRecord();
        })
    }
    .width('100%')
    .height('100%')
    .backgroundColor(Color.White)
  }

  @Builder
  TypeButton(title: string, targetType: RecordType) {
    Button(title)
      .layoutWeight(1)
      .height('100%')
      .backgroundColor(this.type === targetType ? Color.White : Color.Transparent)
      .fontColor(this.type === targetType ? '#007DFF' : '#999999')
      .type(ButtonType.Normal)
      .borderRadius(18)
      .onClick(() => {
        this.type = targetType;
        this.selectedCategory = targetType === RecordType.EXPENSE ? this.expenseCategories[0] : this.incomeCategories[0];
      })
  }

  async saveRecord() {
    if (this.amount <= 0) {
      return;
    }

    await RdbUtils.insert({
      id: 0,
      amount: this.amount,
      type: this.type,
      category: this.selectedCategory,
      remark: this.remark,
      date: Date.now()
    });

    // 【关键点】通知首页刷新
    AppStorage.setOrCreate('isRecordUpdated', true);

    promptAction.showToast({
      message: '🎉 保存成功',
      duration: 2000
    });

    router.back();
  }
}