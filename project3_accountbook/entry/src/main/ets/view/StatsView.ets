import { RecordItem, RecordType } from '../model/RecordType';
import RdbUtils from '../common/utils/RdbUtils';
import { AIAdvisor, AIStyle } from '../common/utils/AIAdvisor'; // 1. 引入新枚举
import { router } from '@kit.ArkUI';

interface CategoryStat {
  category: string;
  amount: number;
  percentage: number;
  color: string;
}

interface TrendItem {
  label: string;
  dateValue: Date;
  amount: number;
  isCurrent: boolean;
}

@Component
export struct StatsView {
  @State isYearView: boolean = false;
  @State currentDate: Date = new Date();
  @State recordType: number = 0;

  @State totalCount: number = 0;
  @State totalAmount: number = 0;

  @State statList: CategoryStat[] = [];
  @State trendList: TrendItem[] = [];
  @State maxTrendAmount: number = 1;

  @State animOffset: number = 0;
  @State animOpacity: number = 1;

  @State aiAnalysisResult: string = '';
  @State currentAIStyle: AIStyle = AIStyle.PROFESSIONAL; // 2. 新增当前风格状态

  @StorageLink('isRecordUpdated') @Watch('onDataUpdate') isRecordUpdated: boolean = false;

  private colors: string[] = [
    '#0045AA', '#005ECC', '#007DFF', '#409EFF', '#66B5FF',
    '#8CCBFF', '#B3E0FF', '#D6F0FF', '#E6F5FF', '#F0F9FF'
  ];

  private settings: RenderingContextSettings = new RenderingContextSettings(true);
  private context: CanvasRenderingContext2D = new CanvasRenderingContext2D(this.settings);

  // 3. 修改弹窗控制器，传入 style 和回调
  dialogController: CustomDialogController | null = new CustomDialogController({
    builder: AIAnalysisDialog({
      result: $aiAnalysisResult,
      currentStyle: $currentAIStyle, // 双向绑定风格
      onStyleChange: (newStyle: AIStyle) => {
        // 当在弹窗里点击切换风格时，调用此方法
        this.showAIAnalysis(newStyle);
      }
    }),
    autoCancel: true,
    alignment: DialogAlignment.Bottom,
    customStyle: true
  })

  async aboutToAppear() {
    this.loadData();
  }

  onDataUpdate() {
    if (this.isRecordUpdated) {
      this.loadData();
    }
  }

  // 4. 修改触发逻辑：支持传入风格
  async showAIAnalysis(style: AIStyle = this.currentAIStyle) {
    // 1. UI状态重置
    if (this.aiAnalysisResult === '' || style !== this.currentAIStyle) {
      this.aiAnalysisResult = ''; // 清空结果，触发Loading动画
    }
    this.currentAIStyle = style;

    // 2. 专门为按钮点击提供的入口（防止重复open）
    // 逻辑：如果通过按钮调用，外部通常会调用 openAnalysisDialog，这里主要负责数据处理

    try {
      // 3. 准备时间范围
      let start: number, end: number;
      const y = this.currentDate.getFullYear();
      const m = this.currentDate.getMonth();

      if (this.isYearView) {
        start = new Date(y, 0, 1).getTime();
        end = new Date(y, 11, 31, 23, 59, 59).getTime();
      } else {
        start = new Date(y, m, 1).getTime();
        end = new Date(y, m + 1, 0, 23, 59, 59).getTime();
      }

      // 4. 【修复参数问题】不再传 -1，而是分别查支出和收入，然后合并
      // 这样可以避免 RdbUtils 里的 advancedQuery 对 -1 处理不当导致的崩溃
      const expenseRecords = await RdbUtils.advancedQuery(start, end, 0, '', 0, 0, ''); // 查支出
      const incomeRecords = await RdbUtils.advancedQuery(start, end, 1, '', 0, 0, '');  // 查收入

      // 合并数组
      const allRecords = [...expenseRecords, ...incomeRecords];

      if (allRecords.length === 0) {
        this.aiAnalysisResult = "当前月份/年份没有账单数据，AI 无法进行分析。快去记一笔吧！📝";
        return;
      }

      // 5. 调用 AI (耗时操作)
      const result = await AIAdvisor.analyze(allRecords, style);
      this.aiAnalysisResult = result;

    } catch (error) {
      // 6. 【关键】错误捕获
      // 无论发生什么错误（数据库挂了、网络断了、API Key过期了），
      // 这里都会捕获到，并把错误显示在弹窗里，而不是一直转圈。
      console.error('[StatsView] AI Analysis Error:', JSON.stringify(error));
      this.aiAnalysisResult = `分析失败 😵\n\n原因: ${JSON.stringify(error.message || error)}`;
    }
  }

  // 专门给 ✨ 按钮用的入口
  async openAnalysisDialog() {
    this.aiAnalysisResult = ''; // 先清空
    if (this.dialogController != null) {
      this.dialogController.open();
    }
    // 开始请求默认风格
    await this.showAIAnalysis(this.currentAIStyle);
  }

  changeDate(newDate: Date) {
    const isNext = newDate.getTime() > this.currentDate.getTime();
    animateTo({ duration: 200, curve: Curve.EaseOut }, () => {
      this.animOffset = isNext ? -50 : 50;
      this.animOpacity = 0;
    });

    setTimeout(async () => {
      this.currentDate = newDate;
      await this.loadData();
      this.animOffset = isNext ? 50 : -50;
      animateTo({ duration: 300, curve: Curve.EaseOut }, () => {
        this.animOffset = 0;
        this.animOpacity = 1;
      });
    }, 200);
  }

  async loadData() {
    await Promise.all([
      this.loadPieAndRankData(),
      this.loadTrendData()
    ]);
  }

  async loadPieAndRankData() {
    let start: number, end: number;
    const y = this.currentDate.getFullYear();
    const m = this.currentDate.getMonth();

    if (this.isYearView) {
      start = new Date(y, 0, 1).getTime();
      end = new Date(y, 11, 31, 23, 59, 59).getTime();
    } else {
      start = new Date(y, m, 1).getTime();
      end = new Date(y, m + 1, 0, 23, 59, 59).getTime();
    }

    const records = await RdbUtils.advancedQuery(start, end, this.recordType, '', 0, 0, '');
    this.totalCount = records.length;

    const map = new Map<string, number>();
    let total = 0;
    records.forEach(item => {
      const val = map.get(item.category) || 0;
      map.set(item.category, val + item.amount);
      total += item.amount;
    });

    this.totalAmount = total;

    const stats: CategoryStat[] = [];
    let colorIndex = 0;
    map.forEach((amount, category) => {
      stats.push({
        category,
        amount,
        percentage: total === 0 ? 0 : amount / total,
        color: this.colors[colorIndex % this.colors.length]
      });
      colorIndex++;
    });

    stats.sort((a, b) => b.amount - a.amount);
    stats.forEach((stat, index) => {
      stat.color = this.colors[index % this.colors.length];
    });

    this.statList = stats;
    this.drawPieChart();
  }

  async loadTrendData() {
    const trends: TrendItem[] = [];
    let maxVal = 0;

    if (this.isYearView) {
      const currentYear = this.currentDate.getFullYear();
      for (let i = -2; i <= 2; i++) {
        const y = currentYear + i;
        const dateVal = new Date(y, 0, 1);
        const start = new Date(y, 0, 1).getTime();
        const end = new Date(y, 11, 31, 23, 59, 59).getTime();

        const records = await RdbUtils.advancedQuery(start, end, this.recordType, '', 0, 0, '');
        const sum = records.reduce((acc, cur) => acc + cur.amount, 0);
        if (sum > maxVal) maxVal = sum;

        trends.push({
          label: `${y}年`,
          dateValue: dateVal,
          amount: sum,
          isCurrent: i === 0
        });
      }
    } else {
      const currentY = this.currentDate.getFullYear();
      const currentM = this.currentDate.getMonth();

      for (let i = -2; i <= 3; i++) {
        const targetDate = new Date(currentY, currentM + i, 1);
        const start = new Date(targetDate.getFullYear(), targetDate.getMonth(), 1).getTime();
        const end = new Date(targetDate.getFullYear(), targetDate.getMonth() + 1, 0, 23, 59, 59).getTime();

        const records = await RdbUtils.advancedQuery(start, end, this.recordType, '', 0, 0, '');
        const sum = records.reduce((acc, cur) => acc + cur.amount, 0);
        if (sum > maxVal) maxVal = sum;

        trends.push({
          label: `${targetDate.getMonth() + 1}月`,
          dateValue: targetDate,
          amount: sum,
          isCurrent: i === 0
        });
      }
    }

    this.maxTrendAmount = maxVal === 0 ? 1 : maxVal;
    this.trendList = trends;
  }

  drawPieChart() {
    const ctx = this.context;
    const width = 300;
    const height = 220;
    const cx = width / 2;
    const cy = height / 2;
    const radius = 60;

    ctx.clearRect(0, 0, width, height);

    if (this.statList.length === 0) {
      ctx.beginPath();
      ctx.arc(cx, cy, radius, 0, 2 * Math.PI);
      ctx.lineWidth = 30;
      ctx.strokeStyle = '#F1F3F5';
      ctx.stroke();
      return;
    }

    let startAngle = -Math.PI / 2;

    this.statList.forEach(stat => {
      const sliceAngle = stat.percentage * 2 * Math.PI;
      const endAngle = startAngle + sliceAngle;

      ctx.beginPath();
      ctx.arc(cx, cy, radius, startAngle, endAngle);
      ctx.lineWidth = 30;
      ctx.strokeStyle = stat.color;
      ctx.stroke();

      if (stat.percentage > 0.03) {
        const middleAngle = startAngle + sliceAngle / 2;
        const outerR = radius + 15;
        const pX = cx + Math.cos(middleAngle) * outerR;
        const pY = cy + Math.sin(middleAngle) * outerR;
        const elbowR = outerR + 15;
        const elbowX = cx + Math.cos(middleAngle) * elbowR;
        const elbowY = cy + Math.sin(middleAngle) * elbowR;
        const isRight = Math.cos(middleAngle) >= 0;
        const endX = isRight ? elbowX + 20 : elbowX - 20;
        const endY = elbowY;

        ctx.beginPath();
        ctx.moveTo(pX, pY);
        ctx.lineTo(elbowX, elbowY);
        ctx.lineTo(endX, endY);
        ctx.lineWidth = 1;
        ctx.strokeStyle = stat.color;
        ctx.stroke();

        ctx.font = '12vp sans-serif';
        ctx.fillStyle = '#666';
        ctx.textAlign = isRight ? 'left' : 'right';
        ctx.textBaseline = 'middle';
        ctx.fillText(stat.category, isRight ? endX + 5 : endX - 5, endY - 8);
        ctx.fillStyle = '#333';
        ctx.font = 'bold 12vp sans-serif';
        ctx.fillText(`${(stat.percentage * 100).toFixed(1)}%`, isRight ? endX + 5 : endX - 5, endY + 8);
      }
      startAngle = endAngle;
    });
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
    if (this.isYearView) {
      const years: string[] = [];
      for(let i = 2020; i <= 2030; i++) years.push(i + '年');
      const defaultIdx = years.indexOf(this.currentDate.getFullYear() + '年');
      TextPickerDialog.show({
        range: years,
        selected: defaultIdx >=0 ? defaultIdx : 5,
        onAccept: (val) => {
          const y = parseInt(years[val.index as number]);
          this.currentDate = new Date(y, 0, 1);
          this.loadData();
        }
      });
    } else {
      const years: string[] = [];
      for(let i = 2020; i <= 2030; i++) years.push(i + '年');
      const months: string[] = [];
      for(let i = 1; i <= 12; i++) months.push(i + '月');

      const yIdx = years.indexOf(this.currentDate.getFullYear() + '年');
      const mIdx = months.indexOf((this.currentDate.getMonth() + 1) + '月');
      TextPickerDialog.show({
        range: [years, months],
        selected: [yIdx >=0 ? yIdx : 5, mIdx >=0 ? mIdx : 0],
        onAccept: (val) => {
          const idxs = val.index as number[];
          const y = parseInt(years[idxs[0]]);
          const m = parseInt(months[idxs[1]]);
          this.currentDate = new Date(y, m - 1, 1);
          this.loadData();
        }
      });
    }
  }

  build() {
    Column() {
      // --- 1. 顶部蓝色区域 ---
      Stack({ alignContent: Alignment.TopEnd }) {
        Column() {
          // Tab
          Row() {
            Column() {
              Text('月账单')
                .fontColor(Color.White)
                .fontSize(16)
                .fontWeight(this.isYearView ? FontWeight.Normal : FontWeight.Bold)
                .opacity(this.isYearView ? 0.7 : 1.0)
              if (!this.isYearView) {
                Divider().color(Color.White).strokeWidth(3).width(30).margin({ top: 5 })
              }
            }
            .onClick(() => { this.isYearView = false; this.loadData(); })
            .margin({ right: 30 })

            Column() {
              Text('年账单')
                .fontColor(Color.White)
                .fontSize(16)
                .fontWeight(this.isYearView ? FontWeight.Bold : FontWeight.Normal)
                .opacity(this.isYearView ? 1.0 : 0.7)
              if (this.isYearView) {
                Divider().color(Color.White).strokeWidth(3).width(30).margin({ top: 5 })
              }
            }
            .onClick(() => { this.isYearView = true; this.loadData(); })
          }
          .width('100%')
          .justifyContent(FlexAlign.Center)
          .padding({ top: 15, bottom: 20 })

          // 筛选与切换
          Row() {
            Row() {
              Text(this.isYearView
                ? `${this.currentDate.getFullYear()}年`
                : `${this.currentDate.getFullYear()}年${this.currentDate.getMonth() + 1}月`)
                .fontColor(Color.White)
                .fontSize(18)
                .fontWeight(FontWeight.Bold)
              SymbolGlyph($r('sys.symbol.chevron_down'))
                .fontColor([Color.White])
                .fontSize(14)
                .margin({ left: 5 })
            }
            .onClick(() => this.showDatePicker())

            Blank()

            Row() {
              Text('支出')
                .fontSize(14)
                .fontColor(this.recordType === 0 ? '#007DFF' : '#E6F2FF')
                .backgroundColor(this.recordType === 0 ? Color.White : Color.Transparent)
                .fontWeight(this.recordType === 0 ? FontWeight.Bold : FontWeight.Normal)
                .padding({ left: 16, right: 16, top: 6, bottom: 6 })
                .borderRadius(16)
                .onClick(() => { this.recordType = 0; this.loadData(); })

              Text('收入')
                .fontSize(14)
                .fontColor(this.recordType === 1 ? '#007DFF' : '#E6F2FF')
                .backgroundColor(this.recordType === 1 ? Color.White : Color.Transparent)
                .fontWeight(this.recordType === 1 ? FontWeight.Bold : FontWeight.Normal)
                .padding({ left: 16, right: 16, top: 6, bottom: 6 })
                .borderRadius(16)
                .onClick(() => { this.recordType = 1; this.loadData(); })
            }
            .backgroundColor('#3399FF')
            .borderRadius(20)
            .padding(3)
          }
          .width('100%')
          .padding({ left: 20, right: 20, bottom: 20 })

          Text(`共${this.recordType === 0 ? '支出' : '收入'}${this.totalCount}笔，合计`)
            .fontSize(12)
            .fontColor(Color.White)
            .opacity(0.8)
            .alignSelf(ItemAlign.Start)
            .padding({ left: 20 })

          Text(`¥ ${this.totalAmount.toFixed(2)}`)
            .fontSize(32)
            .fontWeight(FontWeight.Bold)
            .fontColor(Color.White)
            .alignSelf(ItemAlign.Start)
            .padding({ left: 20, bottom: 30 })
        }
        .width('100%')
        .backgroundColor('#007DFF')

        Button({ type: ButtonType.Circle }) {
          Text('✨').fontSize(20)
        }
        .backgroundColor('#33FFFFFF')
        .width(40)
        .height(40)
        .margin({ top: 15, right: 15 })
        .onClick(() => {
          this.openAnalysisDialog(); // 5. 调用新的入口方法
        })
      }

      // --- 2. 滚动内容区域 ---
      Scroll() {
        Column() {
          Text(`${this.recordType === 0 ? '支出' : '收入'}构成`)
            .fontSize(16)
            .fontWeight(FontWeight.Bold)
            .width('100%')
            .padding({ left: 20, top: 20 })

          Stack({ alignContent: Alignment.Center }) {
            Canvas(this.context)
              .width(300)
              .height(220)
              .onReady(() => this.drawPieChart())
          }
          .width('100%')
          .margin({ top: 10 })

          List() {
            ForEach(this.statList, (item: CategoryStat) => {
              ListItem() {
                Row() {
                  Text(this.getCategoryIcon(item.category))
                    .fontSize(20)
                    .width(36)
                    .height(36)
                    .textAlign(TextAlign.Center)
                    .backgroundColor('#F5F5F5')
                    .borderRadius(18)
                    .margin({ right: 10 })

                  Column() {
                    Row() {
                      Text(item.category)
                        .fontSize(14)
                        .fontWeight(FontWeight.Bold)
                      Blank()
                      Text(`¥${item.amount.toFixed(2)}`)
                        .fontSize(14)
                        .fontWeight(FontWeight.Bold)
                      SymbolGlyph($r('sys.symbol.chevron_right'))
                        .fontSize(12)
                        .fontColor(['#CCC'])
                    }
                    .width('100%')
                    .margin({ bottom: 5 })

                    Progress({ value: item.amount, total: this.statList[0].amount, type: ProgressType.Linear })
                      .color(item.color)
                      .backgroundColor('#F1F3F5')
                      .height(6)
                  }
                  .layoutWeight(1)
                }
                .width('100%')
                .padding({ left: 20, right: 20, top: 10, bottom: 10 })
                .onClick(() => {
                  let start: number, end: number;
                  const y = this.currentDate.getFullYear();
                  const m = this.currentDate.getMonth();
                  if (this.isYearView) {
                    start = new Date(y, 0, 1).getTime();
                    end = new Date(y, 11, 31, 23, 59, 59).getTime();
                  } else {
                    start = new Date(y, m, 1).getTime();
                    end = new Date(y, m + 1, 0, 23, 59, 59).getTime();
                  }
                  router.pushUrl({
                    url: 'pages/CategoryDetailPage',
                    params: {
                      category: item.category,
                      amount: item.amount,
                      type: this.recordType,
                      startTime: start,
                      endTime: end
                    }
                  })
                })
              }
            })
          }
          .width('100%')
          .margin({ top: 10 })

          Text(`${this.recordType === 0 ? '支出' : '收入'}趋势`)
            .fontSize(16)
            .fontWeight(FontWeight.Bold)
            .width('100%')
            .padding({ left: 20, top: 30, bottom: 20 })

          Row({ space: 15 }) {
            ForEach(this.trendList, (item: TrendItem) => {
              Column() {
                Text(item.amount > 0 ? `¥${Math.floor(item.amount)}` : '')
                  .fontSize(10)
                  .fontColor('#999')
                  .margin({ bottom: 4 })

                Stack({ alignContent: Alignment.Bottom }) {
                  Column()
                    .width(10)
                    .height(`${(item.amount / this.maxTrendAmount * 100)}%`)
                    .backgroundColor(item.isCurrent ? '#007DFF' : '#BFDFFF')
                    .borderRadius({ topLeft: 5, topRight: 5 })
                    .constraintSize({ minHeight: 4 })
                }
                .height(110)
                .width(10)

                Text(item.label)
                  .fontSize(12)
                  .fontColor(item.isCurrent ? '#007DFF' : '#999')
                  .fontWeight(item.isCurrent ? FontWeight.Bold : FontWeight.Normal)
                  .margin({ top: 6 })
                  .height(20)
                  .lineHeight(20)
                  .textAlign(TextAlign.Center)
              }
              .layoutWeight(1)
              .height(160)
              .justifyContent(FlexAlign.End)
              .alignItems(HorizontalAlign.Center)
              .onClick(() => {
                this.changeDate(item.dateValue);
              })
            })
          }
          .alignItems(VerticalAlign.Bottom)
          .width('100%')
          .padding({ left: 20, right: 20, bottom: 50 })
          .translate({ x: this.animOffset })
          .opacity(this.animOpacity)
        }
      }
      .layoutWeight(1)
      .backgroundColor(Color.White)
    }
    .width('100%')
    .height('100%')
    .backgroundColor('#007DFF')
  }
}

// --- 6. 更新后的 AI 弹窗 (含 Tab 切换) ---
@CustomDialog
struct AIAnalysisDialog {
  @Link result: string;
  @Link currentStyle: AIStyle;
  // 回调：当用户点击 Tab 时，不关闭弹窗，直接通知父组件刷新数据
  onStyleChange: (style: AIStyle) => void = () => {};
  controller: CustomDialogController;

  private styles: AIStyle[] = [AIStyle.PROFESSIONAL, AIStyle.ELDER, AIStyle.DETECTIVE, AIStyle.FRIEND];

  build() {
    Column() {
      // 标题栏
      Row() {
        Text('✨ AI 财务顾问')
          .fontSize(18)
          .fontWeight(FontWeight.Bold)
        Blank()
        Text('✖️')
          .fontSize(18)
          .fontColor('#999')
          .onClick(() => this.controller.close())
      }
      .width('100%')
      .padding({ left: 20, right: 20, top: 15, bottom: 10 })

      // 风格切换 Tab
      Scroll() {
        Row({ space: 10 }) {
          ForEach(this.styles, (style: AIStyle) => {
            Text(style)
              .fontSize(12)
              .fontColor(this.currentStyle === style ? Color.White : '#007DFF')
              .backgroundColor(this.currentStyle === style ? '#007DFF' : '#E6F2FF')
              .padding({ left: 12, right: 12, top: 6, bottom: 6 })
              .borderRadius(14)
              .onClick(() => {
                if (this.currentStyle !== style) {
                  this.currentStyle = style; // 更新选中状态 UI
                  this.result = ''; // 清空结果触发 Loading
                  this.onStyleChange(style); // 触发父组件逻辑
                }
              })
          })
        }
        .padding({ left: 20, right: 20, bottom: 10 })
      }
      .scrollable(ScrollDirection.Horizontal)
      .scrollBar(BarState.Off)
      .width('100%')

      // 内容区域
      Scroll() {
        Column() {
          if (this.result === '') {
            Column() {
              LoadingProgress()
                .width(40)
                .height(40)
                .color('#007DFF')
              Text('AI 正在思考中...')
                .fontSize(14)
                .fontColor('#999')
                .margin({ top: 10 })
            }
            .width('100%')
            .height(200)
            .justifyContent(FlexAlign.Center)
          } else {
            Text(this.result)
              .fontSize(16)
              .lineHeight(26)
              .fontColor('#333')
          }
        }
      }
      .height(320)
      .padding({ left: 20, right: 20, bottom: 20 })
      .align(Alignment.TopStart)
    }
    .backgroundColor(Color.White)
    .borderRadius({ topLeft: 20, topRight: 20 })
    .width('100%')
  }
}