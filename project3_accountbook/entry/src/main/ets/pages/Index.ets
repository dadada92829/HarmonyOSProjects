import { HomeView } from '../view/HomeView';
import { StatsView } from '../view/StatsView';

@Entry
@Component
struct Index {
  @State currentIndex: number = 0;
  private tabsController: TabsController = new TabsController();

  // 修改点：去掉了多余的 Image 参数，直接用 Emoji 或 Text 替代图标，保证不报错
  @Builder
  TabBuilder(title: string, targetIndex: number) {
    Column() {
      // 选中变蓝，未选中灰色
      Text(targetIndex === 0 ? '🏠' : '📊')
        .fontSize(24)
        .fontColor(this.currentIndex === targetIndex ? '#007DFF' : '#999999')

      Text(title)
        .fontColor(this.currentIndex === targetIndex ? '#007DFF' : '#999999')
        .fontSize(10)
        .margin({ top: 4 })
    }
    .width('100%')
    .height(50)
    .justifyContent(FlexAlign.Center)
    .onClick(() => {
      this.currentIndex = targetIndex;
      this.tabsController.changeIndex(targetIndex);
    })
  }

  build() {
    Tabs({ barPosition: BarPosition.End, controller: this.tabsController }) {
      // Tab 1: 明细
      TabContent() {
        HomeView()
      }
      .tabBar(this.TabBuilder('明细', 0))

      // Tab 2: 统计
      TabContent() {
        // 【修改这里】替换为 StatsView 组件
        StatsView()
      }
      .tabBar(this.TabBuilder('统计', 1))
    }
    .onChange((index: number) => {
      this.currentIndex = index;
    })
    .barHeight(60)
  }
}