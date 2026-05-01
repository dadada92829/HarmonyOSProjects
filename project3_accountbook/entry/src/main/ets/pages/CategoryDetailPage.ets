import { router } from '@kit.ArkUI';
import { RecordItem, RecordType } from '../model/RecordType';
import RdbUtils from '../common/utils/RdbUtils';

// 定义接收参数的接口
interface RouterParams {
  category: string;
  amount: number;
  type: number;
  startTime: number;
  endTime: number;
}

@Entry
@Component
struct CategoryDetailPage {
  @State category: string = '';
  @State totalAmount: number = 0;
  @State recordList: RecordItem[] = [];

  // 页面加载时获取参数并查询数据
  async aboutToAppear() {
    const params = router.getParams() as RouterParams;
    if (params) {
      this.category = params.category;
      this.totalAmount = params.amount;

      // 查询数据库：指定时间段 + 指定分类
      // advancedQuery(start, end, type, category, min, max, keyword)
      this.recordList = await RdbUtils.advancedQuery(
        params.startTime,
        params.endTime,
        params.type,     // 支出或收入
        params.category, // 核心：只查这个分类
        0, 0, ''
      );
    }
  }

  // 辅助函数：获取图标
  getCategoryIcon(category: string): string {
    const iconMap: Record<string, string> = {
      '餐饮': '🍔', '交通': '🚇', '购物': '🛍️', '娱乐': '🎮', '医疗': '💊',
      '教育': '🎓', '工资': '💰', '兼职': '💎', '理财': '📈', '礼金': '🧧',
      '居住': '🏠', '其他': '📄'
    };
    return iconMap[category] || '📝';
  }

  build() {
    Column() {
      // 1. 导航栏
      Row() {
        SymbolGlyph($r('sys.symbol.chevron_left'))
          .fontSize(24)
          .fontColor(['#191919'])
          .onClick(() => router.back())

        Text('分类详情')
          .fontSize(18)
          .fontWeight(FontWeight.Bold)
          .layoutWeight(1)
          .textAlign(TextAlign.Center)
          .margin({ right: 24 }) // 平衡左侧图标
      }
      .height(56)
      .width('100%')
      .padding({ left: 16, right: 16 })
      .backgroundColor(Color.White)

      // 2. 头部汇总大卡片
      Column() {
        // 图标
        Text(this.getCategoryIcon(this.category))
          .fontSize(40)
          .margin({ bottom: 10 })

        // 分类名
        Text(this.category)
          .fontSize(16)
          .fontColor('#666')
          .margin({ bottom: 5 })

        // 总金额
        Text(`¥ ${this.totalAmount.toFixed(2)}`)
          .fontSize(32)
          .fontWeight(FontWeight.Bold)
          .fontColor('#191919')
      }
      .width('100%')
      .padding({ top: 30, bottom: 40 })
      .backgroundColor(Color.White)
      .border({ width: { bottom: 1 }, color: '#F1F3F5' })

      // 3. 账单列表
      List({ space: 12 }) {
        ForEach(this.recordList, (item: RecordItem) => {
          ListItem() {
            this.RecordItemView(item)
          }
        }, (item: RecordItem) => item.id.toString())
      }
      .layoutWeight(1)
      .width('100%')
      .padding({ left: 16, right: 16, top: 20, bottom: 20 })
      .backgroundColor('#F7F8FA')
    }
    .height('100%')
    .backgroundColor('#F7F8FA')
  }

  // 复用列表项样式
  @Builder
  RecordItemView(item: RecordItem) {
    Row() {
      // 日期 (左侧显示日期，因为分类都是一样的，就不显示分类图标了)
      Column() {
        Text(new Date(item.date).getDate().toString())
          .fontSize(20)
          .fontWeight(FontWeight.Bold)
          .fontColor('#191919')
        Text(`${new Date(item.date).getMonth() + 1}月`)
          .fontSize(12)
          .fontColor('#999')
      }
      .width(50)
      .justifyContent(FlexAlign.Center)
      .alignItems(HorizontalAlign.Center)
      .border({ width: { right: 1 }, color: '#F1F3F5' })
      .padding({ right: 10 })

      // 中间：备注
      Column() {
        Text(item.remark ? item.remark : item.category)
          .fontSize(16)
          .fontWeight(FontWeight.Medium)
          .fontColor('#191919')
      }
      .alignItems(HorizontalAlign.Start)
      .layoutWeight(1)
      .padding({ left: 15 })

      // 右侧：金额
      Text(item.amount.toFixed(2))
        .fontSize(18)
        .fontWeight(FontWeight.Bold)
        .fontColor('#191919')
    }
    .width('100%')
    .padding(16)
    .backgroundColor(Color.White)
    .borderRadius(16)
  }
}