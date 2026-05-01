import { router } from '@kit.ArkUI';
import { RecordItem, RecordType } from '../model/RecordType';
import RdbUtils from '../common/utils/RdbUtils';

@Entry
@Component
struct SearchPage {
  @State keyword: string = '';
  @State startDate: Date = new Date(new Date().getFullYear(), new Date().getMonth(), 1);
  @State endDate: Date = new Date();
  @State selectedType: number = -1;
  @State minAmount: string = '';
  @State maxAmount: string = '';
  @State selectedCategory: string = '';

  @State searchResults: RecordItem[] = [];
  @State hasSearched: boolean = false;

  private categories: string[] = ['餐饮', '交通', '购物', '娱乐', '医疗', '教育', '工资', '兼职', '理财', '其他'];

  build() {
    Column() {
      // 1. 标题栏
      Row() {
        // 【修复】颜色加 []
        SymbolGlyph($r('sys.symbol.chevron_left'))
          .fontSize(24)
          .fontColor(['#191919'])
          .onClick(() => router.back())

        Text('账单查询')
          .fontSize(18)
          .fontWeight(FontWeight.Bold)
          .layoutWeight(1)
          .textAlign(TextAlign.Center)

        Text('重置')
          .fontColor('#666666')
          .fontSize(14)
          .onClick(() => this.resetFilter())
      }
      .height(56)
      .width('100%')
      .padding({ left: 16, right: 16 })
      .backgroundColor(Color.White)

      // 2. 滚动区域
      Scroll() {
        Column() {
          // --- 搜索框 ---
          Row() {
            // 【修复】颜色加 []
            SymbolGlyph($r('sys.symbol.magnifyingglass'))
              .fontSize(18)
              .fontColor(['#999999'])
              .margin({ right: 8 })
            TextInput({ text: this.keyword, placeholder: '搜索备注、金额...' })
              .layoutWeight(1)
              .backgroundColor(Color.Transparent)
              .onChange((val) => this.keyword = val)
          }
          .padding(12)
          .backgroundColor('#F5F6F8')
          .borderRadius(24)
          .margin({ top: 10, bottom: 20 })

          // --- 日期范围 ---
          Text('日期范围').SectionTitle()
          Row() {
            this.DateButton(this.startDate, true)
            Text('-').margin({ left: 5, right: 5 }).fontColor('#999999')
            this.DateButton(this.endDate, false)
          }
          .width('100%')
          .justifyContent(FlexAlign.SpaceBetween)

          // --- 类型 ---
          Text('类型').SectionTitle()
          // 【修复】gap 改为 Row({ space: 10 })
          Row({ space: 10 }) {
            this.FilterChip('全部', -1, this.selectedType)
            this.FilterChip('支出', 0, this.selectedType)
            this.FilterChip('收入', 1, this.selectedType)
          }
          .width('100%')
          .justifyContent(FlexAlign.Start)

          // --- 金额区间 ---
          Text('金额区间').SectionTitle()
          Row() {
            TextInput({ text: this.minAmount, placeholder: '0' })
              .type(InputType.Number)
              .backgroundColor('#F5F6F8')
              .height(40)
              .borderRadius(8)
              .layoutWeight(1)
              .textAlign(TextAlign.Center)
              .onChange(val => this.minAmount = val)

            Line().width(20).height(1).backgroundColor('#999999').margin({ left: 10, right: 10 })

            TextInput({ text: this.maxAmount, placeholder: '不限' })
              .type(InputType.Number)
              .backgroundColor('#F5F6F8')
              .height(40)
              .borderRadius(8)
              .layoutWeight(1)
              .textAlign(TextAlign.Center)
              .onChange(val => this.maxAmount = val)
          }

          // --- 分类 ---
          Text('分类').SectionTitle()
          Flex({ wrap: FlexWrap.Wrap }) {
            this.CategoryChip('全部', '')
            ForEach(this.categories, (item: string) => {
              this.CategoryChip(item, item)
            })
          }

          // --- 结果展示 ---
          if (this.hasSearched) {
            Text(`共找到 ${this.searchResults.length} 条记录`)
              .fontSize(12)
              .fontColor('#999999')
              .margin({ top: 30, bottom: 10 })

            List({ space: 10 }) {
              ForEach(this.searchResults, (item: RecordItem) => {
                ListItem() {
                  this.ResultItem(item)
                }
              })
            }
            .height(this.searchResults.length * 80)
          }
        }
        .padding(20)
        .width('100%')
      }
      .layoutWeight(1)

      // 3. 底部按钮
      Button('开始查询')
        .width('90%')
        .height(50)
        .backgroundColor('#007DFF')
        .margin({ bottom: 20 })
        .onClick(() => this.doSearch())
    }
    .backgroundColor(Color.White)
    .height('100%')
  }

  async doSearch() {
    const start = this.startDate.getTime();
    const end = this.endDate.getTime() + 86400000 - 1;
    const min = parseFloat(this.minAmount) || 0;
    const max = parseFloat(this.maxAmount) || 99999999;

    this.searchResults = await RdbUtils.advancedQuery(
      start, end, this.selectedType, this.selectedCategory, min, max, this.keyword
    );
    this.hasSearched = true;
  }

  resetFilter() {
    this.keyword = '';
    this.startDate = new Date(new Date().getFullYear(), new Date().getMonth(), 1);
    this.endDate = new Date();
    this.selectedType = -1;
    this.minAmount = '';
    this.maxAmount = '';
    this.selectedCategory = '';
    this.searchResults = [];
    this.hasSearched = false;
  }

  showDatePick(isStart: boolean) {
    DatePickerDialog.show({
      start: new Date("2020-1-1"),
      end: new Date("2030-12-31"),
      selected: isStart ? this.startDate : this.endDate,
      onAccept: (val) => {
        const d = new Date(val.year!, val.month!, val.day!);
        if (isStart) this.startDate = d;
        else this.endDate = d;
      }
    })
  }

  @Builder
  DateButton(date: Date, isStart: boolean) {
    Row() {
      Text(`${date.getFullYear()}-${date.getMonth() + 1}-${date.getDate()}`)
        .fontSize(14)
      // 【修复】颜色加 []
      SymbolGlyph($r('sys.symbol.calendar'))
        .fontSize(16)
        .fontColor(['#999999'])
        .margin({ left: 5 })
    }
    .layoutWeight(1)
    .height(40)
    .backgroundColor('#F5F6F8')
    .borderRadius(8)
    .justifyContent(FlexAlign.Center)
    .onClick(() => this.showDatePick(isStart))
  }

  @Builder
  FilterChip(label: string, val: number, current: number) {
    Text(label)
      .fontSize(14)
      .fontColor(current === val ? Color.White : '#666666')
      .backgroundColor(current === val ? '#007DFF' : '#F5F6F8')
      .padding({ left: 20, right: 20, top: 8, bottom: 8 })
      .borderRadius(16)
      .onClick(() => this.selectedType = val)
  }

  @Builder
  CategoryChip(label: string, val: string) {
    Text(label)
      .fontSize(12)
      .fontColor(this.selectedCategory === val ? '#007DFF' : '#666666')
      .backgroundColor(this.selectedCategory === val ? '#E6F2FF' : '#F5F6F8')
      .padding({ left: 12, right: 12, top: 6, bottom: 6 })
      .borderRadius(4)
      .margin({ right: 10, bottom: 10 })
      .onClick(() => this.selectedCategory = val)
  }

  @Builder
  ResultItem(item: RecordItem) {
    Row() {
      Column() {
        Text(item.category)
          .fontSize(16)
          .fontWeight(FontWeight.Medium)
        Text(new Date(item.date).toLocaleDateString())
          .fontSize(12)
          .fontColor('#999999')
      }
      .alignItems(HorizontalAlign.Start)

      Blank()

      Text((item.type === 0 ? '-' : '+') + item.amount.toFixed(2))
        .fontSize(16)
        .fontWeight(FontWeight.Bold)
        .fontColor(item.type === 0 ? '#191919' : '#E64566')
    }
    .width('100%')
    .padding(15)
    .backgroundColor('#F9F9F9')
    .borderRadius(10)
  }
}

@Extend(Text) function SectionTitle() {
  .fontSize(14)
  .fontWeight(FontWeight.Bold)
  .fontColor('#333333')
  .margin({ top: 20, bottom: 10 })
  .width('100%')
}