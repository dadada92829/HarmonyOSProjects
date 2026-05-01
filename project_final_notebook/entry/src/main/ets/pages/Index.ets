import { HomeView } from './HomeView';
import { EditorView } from './EditorView';

@Entry
@Component
struct Index {
  // 路由栈，管理页面跳转
  @Provide('pageStack') pageStack: NavPathStack = new NavPathStack();

  // 路由构建器：根据路由名称渲染对应的页面
  @Builder
  PageMap(name: string, param: object) {
    if (name === 'Editor') {
      EditorView()
    }
  }

  build() {
    // Navigation 是全屏容器
    Navigation(this.pageStack) {
      // 默认显示首页视图
      HomeView()
    }
    .navDestination(this.PageMap) // 绑定路由表
    .height('100%')
    .width('100%')
    .hideTitleBar(true) // 隐藏系统默认的标题栏，我们自己写
    .mode(NavigationMode.Stack) // 堆叠模式，适合手机
  }
}