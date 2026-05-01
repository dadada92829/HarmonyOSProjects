import { router, promptAction } from '@kit.ArkUI';
import { RecordItem, RecordType } from '../model/RecordType';
import RdbUtils from '../common/utils/RdbUtils';
import { MockDataGenerator } from '../common/utils/MockDataGenerator';

interface DayGroup {
  dateStr: string;
  dayIncome: number;
  dayExpense: number;
  records: RecordItem[];
}

@Component
export struct HomeView {
  @State currentYear: number = new Date().getFullYear();
  @State currentMonth: number = new Date().getMonth() + 1;

  @State totalIncome: number = 0;
  @State totalExpense: number = 0;
  @State todayExpense: number = 0;
  @State monthBalance: number = 0;

  private rawRecordList: RecordItem[] = [];
  @State groupedList: DayGroup[] = [];

  @StorageLink('isRecordUpdated') @Watch('onRecordUpdated') isRecordUpdated: boolean = false;

  onRecordUpdated() {
    if (this.isRecordUpdated) {
      this.loadData();
      this.isRecordUpdated = false;
    }
  }

  async aboutToAppear() {
    this.loadData();
  }

  async loadData() {
    // 自动生成数据检查 (保留你的逻辑)
    const allData = await RdbUtils.advancedQuery(0, 0, -1, '', 0, 0, '');
    if (allData.length < 10) {
      console.info('检测到数据过少，开始自动生成测试数据...');
      await MockDataGenerator.generateData(300);
    }

    const startDate = new Date(this.currentYear, this.currentMonth - 1, 1).getTime();
    const endDate = new Date(this.currentYear, this.currentMonth, 0, 23, 59, 59).getTime();

    this.rawRecordList = await RdbUtils.advancedQuery(startDate, endDate, -1, '', 0, 0, '');
    this.calculateStats();
    this.groupRecords();
  }

  groupRecords() {
    const groups: DayGroup[] = [];
    const map = new Map<string, DayGroup>();

    const getDayTitle = (ts: number): string => {
      const date = new Date(ts);
      const now = new Date();
      const today = new Date(now.getFullYear(), now.getMonth(), now.getDate()).getTime();
      const target = new Date(date.getFullYear(), date.getMonth(), date.getDate()).getTime();
      const diff = today - target;
      const month = date.getMonth() + 1;
      const day = date.getDate();
      const weekDays = ['周日', '周一', '周二', '周三', '周四', '周五', '周六'];
      const week = weekDays[date.getDay()];
      let suffix = week;
      if (diff === 0) suffix = '今天';
      else if (diff === 86400000) suffix = '昨天';
      return `${month}月${day}日 ${suffix}`;
    };

    this.rawRecordList.forEach(item => {
      const dateKey = new Date(item.date).toDateString();
      if (!map.has(dateKey)) {
        const newGroup: DayGroup = {
          dateStr: getDayTitle(item.date),
          dayIncome: 0,
          dayExpense: 0,
          records: []
        };
        groups.push(newGroup);
        map.set(dateKey, newGroup);
      }
      const group = map.get(dateKey)!;
      group.records.push(item);
      if (item.type === RecordType.INCOME) group.dayIncome += item.amount;
      else group.dayExpense += item.amount;
    });

    this.groupedList = groups;
  }

  calculateStats() {
    this.totalIncome = 0;
    this.totalExpense = 0;
    this.todayExpense = 0;
    const todayStr = new Date().toDateString();

    this.rawRecordList.forEach(item => {
      if (item.type === RecordType.INCOME) {
        this.totalIncome += item.amount;
      } else {
        this.totalExpense += item.amount;
        if (new Date(item.date).toDateString() === todayStr) {
          this.todayExpense += item.amount;
        }
      }
    });
    this.monthBalance = this.totalIncome - this.totalExpense;
  }

  getCategoryIcon(category: string): string {
    const iconMap: Record<string, string> = {
      '餐饮': '🍔', '交通': '🚇', '购物': '🛍️', '娱乐': '🎮', '医疗': '💊',
      '教育': '🎓', '工资': '💰', '兼职': '💎', '理财': '📈', '礼金': '🧧',
      '居住': '🏠', '其他': '📄'
    };
    return iconMap[category] || '📝';
  }

  showDatePicker() {
    const years: string[] = [];
    for(let i = 2020; i <= 2030; i++) years.push(i + '年');
    const months: string[] = [];
    for(let i = 1; i <= 12; i++) months.push(i + '月');

    const defaultYearIndex = years.indexOf(this.currentYear + '年');
    const defaultMonthIndex = months.indexOf(this.currentMonth + '月');

    TextPickerDialog.show({
      range: [years, months],
      selected: [defaultYearIndex >= 0 ? defaultYearIndex : 5, defaultMonthIndex >= 0 ? defaultMonthIndex : 0],
      onAccept: (value) => {
        this.currentYear = parseInt(years[value.index[0]]);
        this.currentMonth = parseInt(months[value.index[1]]);
        this.loadData();
      }
    })
  }

  build() {
    Stack({ alignContent: Alignment.BottomEnd }) {
      Column() {
        // --- 1. 蓝色头部区域 ---
        Column() {
          Row() {
            Text(`${this.currentYear}年${this.currentMonth}月`)
              .fontSize(20)
              .fontColor(Color.White)
              .fontWeight(FontWeight.Bold)
            SymbolGlyph($r('sys.symbol.chevron_down'))
              .fontSize(18)
              .fontColor([Color.White])
              .margin({ left: 5 })
          }
          .width('100%')
          .justifyContent(FlexAlign.Start)
          .padding({ top: 40, bottom: 20 })
          .onClick(() => this.showDatePicker())

          Row() {
            Column() {
              Text('本月支出 (元)')
                .fontSize(14)
                .fontColor(Color.White)
                .opacity(0.8)
              Text(this.totalExpense.toFixed(2))
                .fontSize(28)
                .fontWeight(FontWeight.Bold)
                .fontColor(Color.White)
                .margin({ top: 5 })
            }
            .alignItems(HorizontalAlign.Start)
            .layoutWeight(1)

            Column() {
              Text('本月收入')
                .fontSize(14)
                .fontColor(Color.White)
                .opacity(0.8)
              Text(this.totalIncome.toFixed(2))
                .fontSize(28)
                .fontWeight(FontWeight.Bold)
                .fontColor(Color.White)
                .margin({ top: 5 })
            }
            .alignItems(HorizontalAlign.End)
            .layoutWeight(1)
          }

          // 【新增】预算进度条
          Column() {
            Row() {
              Text('本月预算剩余')
                .fontSize(12)
                .fontColor(Color.White)
                .opacity(0.8)
              Blank()
              // 假设预算是 5000
              Text(`${Math.max(0, (5000 - this.totalExpense) / 5000 * 100).toFixed(0)}%`)
                .fontSize(12)
                .fontColor(Color.White)
                .fontWeight(FontWeight.Bold)
            }
            .width('100%')
            .margin({ top: 15, bottom: 5 })

            Progress({ value: this.totalExpense, total: 5000, type: ProgressType.Linear })
              .color(this.totalExpense > 5000 ? '#FF5252' : Color.White)
              .backgroundColor('#33FFFFFF')
              .style({ strokeWidth: 6 })
          }
          .width('100%')
          .padding({ bottom: 60 }) // 留足底部空间

        }
        .width('100%')
        .padding({ left: 20, right: 20 })
        .backgroundColor('#007DFF')
        .borderRadius({ bottomLeft: 20, bottomRight: 20 })
        .zIndex(1)

        // --- 2. 悬浮统计白卡 ---
        Row() {
          Column() {
            Text('今日支出')
              .fontSize(12)
              .fontColor('#999999')
            Text(`¥ ${this.todayExpense.toFixed(2)}`)
              .fontSize(18)
              .fontWeight(FontWeight.Bold)
              .fontColor('#191919')
              .margin({ top: 5 })
          }
          .layoutWeight(1)
          .alignItems(HorizontalAlign.Center)

          Divider().vertical(true).height(30).color('#F1F3F5')

          Column() {
            Text('结余')
              .fontSize(12)
              .fontColor('#999999')
            Text((this.monthBalance >= 0 ? '+' : '') + this.monthBalance.toFixed(2))
              .fontSize(18)
              .fontWeight(FontWeight.Bold)
              .fontColor(this.monthBalance >= 0 ? '#4CAF50' : '#E64566')
              .margin({ top: 5 })
          }
          .layoutWeight(1)
          .alignItems(HorizontalAlign.Center)
        }
        .width('90%')
        .height(80)
        .backgroundColor(Color.White)
        .borderRadius(16)
        .shadow({ radius: 20, color: '#15000000', offsetY: 10 })
        .margin({ top: -40, bottom: 10 })
        .zIndex(2)

        // --- 3. 搜索入口 ---
        Row() {
          Blank()
          Row() {
            SymbolGlyph($r('sys.symbol.magnifyingglass'))
              .fontSize(18)
              .fontColor(['#007DFF'])
            Text(' 搜索')
              .fontSize(14)
              .fontColor('#007DFF')
          }
          .padding({ top: 10, bottom: 10, left: 20 })
          .onClick(() => {
            router.pushUrl({ url: 'pages/SearchPage' })
          })
        }
        .width('100%')
        .padding({ right: 20 })

        // --- 4. 分组列表 ---
        List() {
          ForEach(this.groupedList, (group: DayGroup) => {
            ListItemGroup({ header: this.GroupHeader(group) }) {
              ForEach(group.records, (item: RecordItem) => {
                ListItem() {
                  this.RecordItemView(item)
                }
                .swipeAction({ end: this.DeleteButton(item.id) })
                // 【新增】列表入场动画
                .transition(TransitionEffect.OPACITY.animation({ duration: 300 }))
              }, (item: RecordItem) => item.id.toString())
            }
            .margin({ bottom: 10 })
          })
        }
        .layoutWeight(1)
        .padding({ left: 15, right: 15, bottom: 80 })
        .scrollBar(BarState.Off)
        .sticky(StickyStyle.Header)
      }
      .width('100%')
      .height('100%')
      .backgroundColor('#F7F8FA')

      // 悬浮记账按钮
      Button({ type: ButtonType.Circle, stateEffect: true }) {
        Text('+')
          .fontSize(30)
          .fontColor(Color.White)
          .baselineOffset(2)
      }
      .width(60)
      .height(60)
      .backgroundColor('#007DFF')
      .margin({ right: 20, bottom: 30 })
      .shadow({ radius: 10, color: '#40007DFF', offsetY: 5 })
      .onClick(() => {
        router.pushUrl({ url: 'pages/AddPage' })
      })
    }
  }

  @Builder
  GroupHeader(group: DayGroup) {
    Row() {
      Text(group.dateStr)
        .fontSize(14)
        .fontColor('#999999')
      Blank()
      if (group.dayIncome > 0) {
        Text(`收: ${group.dayIncome.toFixed(2)}  `)
          .fontSize(12)
          .fontColor('#999999')
      }
      if (group.dayExpense > 0) {
        Text(`支: ${group.dayExpense.toFixed(2)}`)
          .fontSize(12)
          .fontColor('#999999')
      }
    }
    .width('100%')
    .padding({ top: 15, bottom: 8, left: 5, right: 5 })
    .backgroundColor('#F7F8FA')
  }

  @Builder
  RecordItemView(item: RecordItem) {
    Row() {
      Column() {
        Text(this.getCategoryIcon(item.category))
          .fontSize(24)
      }
      .width(44)
      .height(44)
      .borderRadius(22)
      .backgroundColor(item.type === RecordType.EXPENSE ? '#FFF3E0' : '#E8F5E9')
      .justifyContent(FlexAlign.Center)

      Column() {
        Text(item.category)
          .fontSize(16)
          .fontWeight(FontWeight.Bold)
          .fontColor('#191919')

        if (item.remark) {
          Text(item.remark)
            .fontSize(12)
            .fontColor('#999999')
            .margin({ top: 4 })
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
        }
      }
      .alignItems(HorizontalAlign.Start)
      .layoutWeight(1)
      .padding({ left: 12 })

      Text((item.type === RecordType.INCOME ? '+' : '-') + item.amount.toFixed(2))
        .fontSize(18)
        .fontWeight(FontWeight.Bold)
        .fontColor('#191919')
    }
    .width('100%')
    .padding({ top: 14, bottom: 14, left: 16, right: 16 })
    .backgroundColor(Color.White)
    .borderRadius(16)
  }

  @Builder
  DeleteButton(id: number) {
    Button() {
      SymbolGlyph($r('sys.symbol.trash'))
        .fontSize(20)
        .fontColor([Color.White])
    }
    .width(60)
    .height('100%')
    .backgroundColor('#FF5252')
    .borderRadius({ topRight: 16, bottomRight: 16 })
    .type(ButtonType.Normal)
    .onClick(async () => {
      await RdbUtils.delete(id);
      // 【新增】删除成功提示
      promptAction.showToast({ message: '🗑️ 已删除' });
      this.loadData();
    })
  }
}