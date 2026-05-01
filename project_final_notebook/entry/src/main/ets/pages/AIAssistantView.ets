import { QwenService } from '../utils/QwenService';
import { webview } from '@kit.ArkWeb';

// --- 思维导图展示弹窗 ---
@CustomDialog
struct MindMapDialog {
  controller: CustomDialogController;
  @Prop mermaidCode: string;

  // WebView 控制器
  webviewController: webview.WebviewController = new webview.WebviewController();

  // Mermaid 渲染模板 (修复缩放问题)
  private readonly htmlTemplate = `
    <!DOCTYPE html>
    <html>
    <head>
      <!-- [核心修复] 允许自由缩放，范围 0.1倍 到 10倍 -->
      <meta name="viewport" content="width=device-width, initial-scale=0.8, minimum-scale=0.1, maximum-scale=10.0, user-scalable=yes">
      <script src="https://cdn.jsdelivr.net/npm/mermaid@10/dist/mermaid.min.js" onerror="alert('Mermaid JS 加载失败，请检查网络')"></script>
      <style>
        body {
          margin: 0; padding: 20px;
          background-color: #f5f7fa;
          font-family: sans-serif;
          /* 允许内容溢出，配合 WebView 的滚动和缩放 */
          width: fit-content;
          min-width: 100%;
        }
        #graph { display: block; overflow: visible; }

        #graph svg {
          max-width: none !important;
          height: auto;
          filter: drop-shadow(2px 4px 6px rgba(0,0,0,0.05));
        }

        /* 样式定义 */
        .nodeLabel, .edgeLabel, .label {
          color: #000000 !important;
          font-size: 16px !important;
          line-height: 1.5 !important;
        }
        .root .nodeLabel {
          color: #ffffff !important;
          font-weight: bold !important;
          font-size: 18px !important;
        }
        .node rect, .node circle { stroke-width: 1px; }

        /* 强制连线可见 */
        .edgePath .path {
          stroke: #999999 !important;
          stroke-width: 2px !important;
          fill: none !important;
        }
        #graph .marker {
          fill: #999999 !important;
          stroke: #999999 !important;
        }
      </style>
    </head>
    <body>
      <div id="graph" class="mermaid">
        <div style="color: #0A59F7; font-size: 14px; text-align: center; margin-top: 50%;">
          正在绘制思维导图...
        </div>
      </div>
      <script>
        mermaid.initialize({
          startOnLoad: false,
          theme: 'base',
          flowchart: {
            htmlLabels: true,
            curve: 'bumpX',
            useMaxWidth: false
          },
          themeVariables: {
            primaryColor: '#ffffff',
            primaryTextColor: '#000000',
            primaryBorderColor: '#FF8800',
            lineColor: '#999999',
            fontFamily: 'sans-serif'
          }
        });

        function render(code) {
          try {
            const element = document.getElementById('graph');
            let cleanCode = code.replace(/\\\`\\\`\\\`mermaid/g, '').replace(/\\\`\\\`\\\`/g, '').trim();

            if (cleanCode.startsWith('graph')) {
               cleanCode = cleanCode.replace(/^graph [a-zA-Z]+\s*/, 'graph LR\\n');
            } else {
               cleanCode = 'graph LR\\n' + cleanCode;
            }

            const styleDefs = '\\nclassDef root fill:#0A59F7,stroke:none,color:#fff,rx:5,ry:5;\\nclassDef level1 fill:#fff,stroke:#FF8800,stroke-width:1px,color:#000,rx:5,ry:5;\\nclassDef level2 fill:#fff,stroke:#ccc,stroke-width:1px,color:#000,rx:2,ry:2;';
            cleanCode = cleanCode + styleDefs;

            element.innerHTML = cleanCode;
            element.removeAttribute('data-processed');

            mermaid.run({ nodes: [element] }).catch(err => {
               document.getElementById('graph').innerHTML = '<div style="color:red;padding:20px">渲染错误：' + err.message + '</div>';
            });
          } catch (e) {
            alert('JS 错误: ' + e.message);
          }
        }
      </script>
    </body>
    </html>
  `;

  build() {
    Column() {
      // 顶部
      Row() {
        Text('思维导图').fontSize(18).fontWeight(FontWeight.Bold)
        SymbolGlyph($r('sys.symbol.xmark'))
          .fontSize(24).fontColor(['#666'])
          .onClick(() => this.controller.close())
      }
      .width('100%').justifyContent(FlexAlign.SpaceBetween)
      .padding(16)
      .backgroundColor('#FAFAFA')

      // WebView 区域
      Web({ src: '', controller: this.webviewController })
        .layoutWeight(1)
        .width('100%')
        .onControllerAttached(() => {
          this.webviewController.loadData(
            this.htmlTemplate,
            "text/html",
            "UTF-8",
            "https://www.example.com"
          );
        })
        .onPageEnd(() => {
          if (this.mermaidCode) {
            const safeCode = this.mermaidCode
              .replace(/\\/g, '\\\\')
              .replace(/`/g, '\\`')
              .replace(/\n/g, '\\n')
              .replace(/'/g, "\\'")
              .replace(/"/g, '\\"');

            this.webviewController.runJavaScript(`render('${safeCode}')`);
          }
        })
        .domStorageAccess(true)
        .javaScriptAccess(true)
          // [核心修复] 允许缩放
        .zoomAccess(true)
        .overviewModeAccess(true)
        .multiWindowAccess(false)
        .onAlert((event) => {
          if (event) {
            AlertDialog.show({ message: event.message });
            return true;
          }
          return false;
        })
    }
    .width('100%')
    .height('90%')
    .backgroundColor(Color.White)
    .borderRadius({ topLeft: 16, topRight: 16 })
  }
}

// --- AI 助手主视图 ---
@Component
export struct AIAssistantView {
  @Prop currentContent: string;
  onApplyResult: (text: string) => void = () => {};
  onClose: () => void = () => {};

  @State aiResult: string = '';
  @State isLoading: boolean = false;
  @State lastAction: string = '';

  @State mindMapCode: string = '';

  mindMapController: CustomDialogController = new CustomDialogController({
    builder: MindMapDialog({ mermaidCode: this.mindMapCode }),
    alignment: DialogAlignment.Bottom,
    customStyle: true,
    autoCancel: true
  });

  async handleAIAction(actionName: string, prompt: string) {
    if (!this.currentContent || this.currentContent.trim().length === 0) {
      this.aiResult = '当前笔记为空，无法处理。';
      return;
    }

    this.isLoading = true;
    this.lastAction = actionName;
    this.aiResult = '';

    try {
      if (actionName.includes('思维导图')) {
        const code = await QwenService.generateMindMapCode(this.currentContent);
        this.mindMapCode = code;
        this.isLoading = false;
        this.mindMapController.open();
      } else {
        // [核心修复] 这里适配了新的 QwenService.chat 接口
        // 手动构造 System Prompt 和 User Prompt，恢复以前的功能逻辑
        const systemPrompt = "你是一个专业的笔记助手。请根据用户的要求处理笔记内容。直接输出结果，不要包含多余的寒暄。";
        const userPrompt = `${prompt}\n\n待处理内容：\n${this.currentContent}`;

        const result = await QwenService.chat(systemPrompt, userPrompt);

        this.aiResult = result;
        this.isLoading = false;
      }
    } catch (e) {
      this.aiResult = 'AI 请求出错，请稍后重试。';
      this.isLoading = false;
    }
  }

  build() {
    Column() {
      // 把手
      Row() { Row().width(40).height(5).backgroundColor('#E0E0E0').borderRadius(3) }
      .width('100%').justifyContent(FlexAlign.Center).padding({ top: 10, bottom: 5 })
      .onClick(() => this.onClose())

      // 标题栏
      Row() {
        Row() {
          SymbolGlyph($r('sys.symbol.wand_and_stars')).fontSize(20).fontColor(['#7B1FA2']).margin({ right: 8 })
          Text('AI 笔记助手').fontSize(18).fontWeight(FontWeight.Bold).fontColor('#333')
        }
        Text('收起').fontSize(14).fontColor('#999').onClick(() => this.onClose())
      }
      .width('100%').justifyContent(FlexAlign.SpaceBetween).padding({ left: 20, right: 20, bottom: 15 })

      // 功能区
      Grid() {
        GridItem() { this.FeatureBtn('📝 润色文本', '请润色这篇笔记，使其语言更加通顺、优雅。') }
        GridItem() { this.FeatureBtn('💡 重点提炼', '请为这篇笔记提炼核心观点，列出 3-5 个关键点。') }
        GridItem() { this.FeatureBtn('✨ 续写内容', '请根据这篇笔记当前的风格、逻辑和语境，尝试续写一段后续内容，保持思路连贯。') }
        GridItem() { this.FeatureBtn('🧠 生成思维导图', 'MINDMAP') }
      }
      .columnsTemplate('1fr 1fr')
      .rowsGap(10).columnsGap(10)
      .padding({ left: 20, right: 20 })
      .height(120)

      // 结果区
      if (this.isLoading) {
        Column() {
          LoadingProgress().width(40).height(40).color('#7B1FA2')
          Text('AI 正在思考中...').fontSize(14).fontColor('#999').margin({ top: 10 })
        }
        .width('100%').height(150).justifyContent(FlexAlign.Center)
      } else if (this.aiResult) {
        Column() {
          Row() {
            Text(this.lastAction + '结果：').fontSize(14).fontWeight(FontWeight.Bold).fontColor('#555')
            Blank()
            Button('追加到笔记', { type: ButtonType.Normal, stateEffect: true })
              .backgroundColor('#F3E5F5').fontColor('#7B1FA2').fontSize(12).height(24).borderRadius(12)
              .onClick(() => {
                this.onApplyResult('\n\n--- AI ' + this.lastAction + ' ---\n' + this.aiResult);
                AlertDialog.show({ message: '已追加到笔记末尾' });
              })
          }
          .width('100%').margin({ bottom: 8 })

          Scroll() {
            Text(this.aiResult).fontSize(15).fontColor('#333').lineHeight(24)
          }
          .height(150).align(Alignment.TopStart)
          .backgroundColor('#F9F9F9').padding(12).borderRadius(8)
        }
        .padding({ left: 20, right: 20, top: 10, bottom: 20 })
      }
    }
    .width('100%')
    .backgroundColor(Color.White)
    .shadow({ radius: 20, color: 'rgba(0,0,0,0.1)', offsetY: 5 })
    .borderRadius({ bottomLeft: 20, bottomRight: 20 })
  }

  @Builder FeatureBtn(title: string, prompt: string) {
    Button(title)
      .backgroundColor('#F5F5F5').fontColor('#333').fontSize(14).width('100%').height(44)
      .onClick(() => this.handleAIAction(title.substring(2), prompt))
  }
}