// D:\HarmonyOSProjects\app_24point\entry\src\main\ets\pages\GamePage.ets

import router from '@ohos.router'

const EPSILON = 1e-6;

// ... (getCardImage 函数保持不变) ...
function getCardImage(value: number): Resource {
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
      return $r('app.media.img_14') // 牌背
  }
}

interface RouteParams {
  cards?: string;
}

@Entry
@Component
struct GamePage {
  @State selectedNumbers: number[] = []
  @State resultExpressions: string[] = []
  @State isLoading: boolean = true

  // --- 新增代码段 开始 ---
  // 与Index页面一样，链接到同一个全局状态
  @StorageLink('selectedBackground') selectedBg: Resource = $r('app.media.bg_dark');
  @StorageLink('fontColor') fontColor: Color = Color.White;
  // --- 新增代码段 结束 ---

  // ... (calculate24, aboutToAppear 函数保持不变) ...
  calculate24(numbers: number[]): string[] {
    const solutions = new Set<string>();

    const find = (nums: number[], exprs: string[]) => {
      if (nums.length === 1) {
        if (Math.abs(nums[0] - 24) < EPSILON) {
          let finalExpr = exprs[0];
          if (finalExpr.startsWith('(') && finalExpr.endsWith(')')) {
            finalExpr = finalExpr.substring(1, finalExpr.length - 1);
          }
          solutions.add(finalExpr);
        }
        return;
      }

      for (let i = 0; i < nums.length; i++) {
        for (let j = i + 1; j < nums.length; j++) {
          const nextNums: number[] = [];
          const nextExprs: string[] = [];

          for (let k = 0; k < nums.length; k++) {
            if (k !== i && k !== j) {
              nextNums.push(nums[k]);
              nextExprs.push(exprs[k]);
            }
          }

          const a = nums[i], b = nums[j];
          const exprA = exprs[i], exprB = exprs[j];

          find([...nextNums, a + b], [...nextExprs, `(${exprA} + ${exprB})`]);
          find([...nextNums, a * b], [...nextExprs, `(${exprA} * ${exprB})`]);
          find([...nextNums, a - b], [...nextExprs, `(${exprA} - ${exprB})`]);
          find([...nextNums, b - a], [...nextExprs, `(${exprB} - ${exprA})`]);

          if (b !== 0 && a % b === 0) {
            find([...nextNums, a / b], [...nextExprs, `(${exprA} / ${exprB})`]);
          }
          if (a !== 0 && b % a === 0) {
            find([...nextNums, b / a], [...nextExprs, `(${exprB} / ${exprA})`]);
          }
        }
      }
    };

    const initialExprs = numbers.map(String);
    find(numbers, initialExprs);

    return Array.from(solutions);
  }

  aboutToAppear() {
    const params = router.getParams() as RouteParams;
    if (params?.cards && typeof params.cards === 'string') {
      try {
        this.selectedNumbers = JSON.parse(params.cards) as number[];
        this.resultExpressions = this.calculate24(this.selectedNumbers);
      } catch (e) {
        console.error('解析 cards 失败:', e);
      }
      this.isLoading = false;
    }
  }


  build() {
    // --- 修改代码段 开始 ---
    // 同样，替换背景颜色为背景图片
    Column() {
      Text('计算结果')
        .fontSize(24)
        .fontWeight(FontWeight.Bold)
        .padding(20)
        .fontColor(this.fontColor) // 使用动态字体颜色

      // ... (中间的Row和Column布局保持不变) ...
      Row({ space: 10 }) {
        ForEach(this.selectedNumbers, (val: number) => {
          Image(getCardImage(val))
            .width(60)
            .height(90)
            .objectFit(ImageFit.Contain)
            .border({ width: 1, color: Color.Gray, radius: 5 })
        })
      }
      .height(120)
      .justifyContent(FlexAlign.Center)

      Column() {
        if (this.isLoading) {
          Text('正在计算中...')
            .fontSize(18)
            .fontColor(this.fontColor) // 使用动态字体颜色
        } else {
          if (this.resultExpressions.length > 0) {
            List({ space: 10 }) {
              ForEach(this.resultExpressions, (expr: string) => {
                ListItem() {
                  Text(`${expr} = 24`)
                    .fontSize(20)
                    .width('100%')
                    .textAlign(TextAlign.Center)
                    .padding(10)
                    .fontColor(Color.Black)
                    .backgroundColor('#EEEEEE')
                    .borderRadius(8)
                }
              })
            }
          } else {
            Text('这组牌无法计算出24！')
              .fontSize(20)
              .fontColor(this.fontColor === Color.White ? Color.Yellow : Color.Red)
              .fontWeight(FontWeight.Bold)
          }
        }
      }
      .layoutWeight(1)
      .width('100%')
      .padding(20)
      .justifyContent(FlexAlign.Center)


      Button('返回重新选择')
        .fontSize(18)
        .width('80%')
        .height(50)
        .margin(20)
        .onClick(() => {
          router.back()
        })
    }
    .width('100%')
    .height('100%')
    .backgroundImage(this.selectedBg)
    .backgroundImageSize(ImageSize.Cover)
    .backgroundImagePosition(Alignment.Center) // 使用这个独立的修饰符来设置居中对齐
    // --- 修改代码段 结束 ---
  }
}