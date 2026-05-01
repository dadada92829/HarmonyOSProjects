import { FileNode } from '../model/NoteModel';
import DBManager from '../utils/DBManager';
import { picker } from '@kit.CoreFileKit';
import { fileIo as fs } from '@kit.CoreFileKit';
import { util } from '@kit.ArkTS';
import { QwenService } from '../utils/QwenService';
import { BusinessError } from '@kit.BasicServicesKit';
import { media } from '@kit.MediaKit';
import { abilityAccessCtrl, common } from '@kit.AbilityKit';
// [找回] 引入 AI 助手组件
import { AIAssistantView } from './AIAssistantView';

// --- 类型与类定义 ---

class LineStyleItem {
  name: string;
  value: number;
  style: TextDecorationStyle;

  constructor(name: string, value: number, style: TextDecorationStyle) {
    this.name = name;
    this.value = value;
    this.style = style;
  }
}

interface NoteComment {
  id: string;
  rangeStart: number;
  rangeEnd: number;
  content: string;
  colorStr: string;
  styleType: number;
  createTime: number;
}

// 用于只读模式渲染的数据结构
interface ReadSpanData {
  text: string;
  comment?: NoteComment;
}

const LINE_STYLES: LineStyleItem[] = [
  new LineStyleItem('实线', 0, TextDecorationStyle.SOLID),
  new LineStyleItem('虚线', 1, TextDecorationStyle.DASHED),
  new LineStyleItem('波浪', 2, TextDecorationStyle.WAVY)
];

const COLORS: string[] = ['#FF8800', '#0A59F7', '#FF0000', '#000000', '#009688'];

// --- 1. 自动保存设置弹窗 ---
@CustomDialog
struct SaveSettingsDialog {
  controller: CustomDialogController;
  @Link currentInterval: number;
  confirm: (interval: number) => void = () => {};

  build() {
    Column() {
      Text('自动保存设置').fontSize(18).fontWeight(FontWeight.Bold).margin({ top: 20, bottom: 20 })
      Column({ space: 12 }) {
        this.RadioItem('手动保存', 0)
        this.RadioItem('每 5 秒自动保存', 5000)
        this.RadioItem('每 30 秒自动保存', 30000)
      }
      .width('100%').padding({ left: 24, right: 24 })
      Button('关闭').onClick(() => { this.controller.close() }).margin({ top: 20, bottom: 20 })
        .backgroundColor(Color.White).fontColor('#0A59F7')
    }
    .backgroundColor(Color.White).borderRadius(16).width('80%')
  }

  @Builder RadioItem(label: string, value: number) {
    Row() {
      Text(label).fontSize(16).fontColor('#333')
      Blank()
      Radio({ value: value.toString(), group: 'autosave' })
        .checked(this.currentInterval === value)
        .onChange((isChecked: boolean) => { if (isChecked) { this.currentInterval = value; this.confirm(value); } })
    }
    .width('100%').height(40)
  }
}

// --- 2. 语音输入弹窗 ---
@CustomDialog
struct VoiceInputDialog {
  controller: CustomDialogController;
  onConfirm: (filePath: string) => void = () => {};
  @State isRecording: boolean = false;
  @State recordDuration: number = 0;
  private avRecorder: media.AVRecorder | undefined = undefined;
  private timer: number = -1;
  private tempFilePath: string = '';

  async aboutToAppear() {
    const context = getContext(this) as common.UIAbilityContext;
    const manager = abilityAccessCtrl.createAtManager();
    try { await manager.requestPermissionsFromUser(context, ['ohos.permission.MICROPHONE']); } catch (err) {}
  }

  async startRecording() {
    try {
      this.avRecorder = await media.createAVRecorder();
      const context = getContext(this) as common.UIAbilityContext;
      this.tempFilePath = `${context.cacheDir}/voice_${Date.now()}.m4a`;
      const file = fs.openSync(this.tempFilePath, fs.OpenMode.READ_WRITE | fs.OpenMode.CREATE);
      const fd = file.fd;
      const config: media.AVRecorderConfig = {
        audioSourceType: media.AudioSourceType.AUDIO_SOURCE_TYPE_MIC,
        profile: {
          audioBitrate: 48000, audioChannels: 1, audioCodec: media.CodecMimeType.AUDIO_AAC,
          audioSampleRate: 16000, fileFormat: media.ContainerFormatType.CFT_MPEG_4,
        }, url: `fd://${fd}`,
      };
      await this.avRecorder.prepare(config);
      await this.avRecorder.start();
      this.isRecording = true;
      this.recordDuration = 0;
      this.timer = setInterval(() => { this.recordDuration++; }, 1000);
    } catch (e) { AlertDialog.show({ message: '启动录音失败' }); }
  }

  async stopRecording() {
    if (!this.avRecorder) return;
    try {
      await this.avRecorder.stop(); await this.avRecorder.release();
      this.avRecorder = undefined; clearInterval(this.timer);
      this.isRecording = false; this.onConfirm(this.tempFilePath); this.controller.close();
    } catch (e) {}
  }

  async uploadAudio() {
    try {
      const docPicker = new picker.DocumentViewPicker();
      const options = new picker.DocumentSelectOptions();
      options.maxSelectNumber = 1;
      const result = await docPicker.select(options);
      if (result.length > 0) { this.onConfirm(result[0]); this.controller.close(); }
    } catch (e) {}
  }

  build() {
    Column() {
      Text('语音输入').fontSize(18).fontWeight(FontWeight.Bold).margin({ top: 24, bottom: 24 })
      if (this.isRecording) {
        Column() {
          Text(`${this.recordDuration} s`).fontSize(32).fontWeight(FontWeight.Bold).fontColor('#0A59F7').margin({ bottom: 16 })
          LoadingProgress().width(48).height(48).color('#0A59F7')
          Button('停止并识别').backgroundColor('#FF4040').fontColor(Color.White).width('60%').margin({ top: 24 })
            .onClick(() => this.stopRecording())
        }
      } else {
        Column({ space: 16 }) {
          Button('开始录音').backgroundColor('#0A59F7').fontColor(Color.White).width('70%').height(50)
            .onClick(() => this.startRecording())
          Text('或').fontSize(14).fontColor('#999')
          Button('上传录音文件').backgroundColor('#F0F0F0').fontColor('#333').width('70%').height(50)
            .onClick(() => this.uploadAudio())
        }
      }
    }
    .width('80%').padding({ bottom: 24 }).backgroundColor(Color.White).borderRadius(16)
  }
}

// --- 3. 样式选择器 ---
@Component
struct StyleSelector {
  @Link selectedColor: string;
  @Link selectedStyle: number;

  build() {
    Column({ space: 16 }) {
      Row({ space: 20 }) {
        ForEach(COLORS, (color: string) => {
          Stack() {
            Circle({ width: 28, height: 28 }).fill(color)
            if (this.selectedColor === color) {
              SymbolGlyph($r('sys.symbol.checkmark')).fontSize(16).fontColor([Color.White])
            }
          }.onClick(() => { this.selectedColor = color })
        })
      }.width('100%').justifyContent(FlexAlign.Center)

      Row({ space: 15 }) {
        ForEach(LINE_STYLES, (styleItem: LineStyleItem) => {
          this.StyleItem(styleItem.name, styleItem.value, styleItem.style)
        })
      }.width('100%').justifyContent(FlexAlign.Center)
    }
    .padding({ top: 10, bottom: 10 })
  }

  @Builder StyleItem(name: string, val: number, style: TextDecorationStyle) {
    Column() {
      Row() {
        if (style === TextDecorationStyle.SOLID) { Divider().color(this.selectedColor).strokeWidth(2) }
        else if (style === TextDecorationStyle.DASHED) { Text('- - - -').fontColor(this.selectedColor).fontWeight(FontWeight.Bold).maxLines(1) }
        else if (style === TextDecorationStyle.WAVY) { Text('~~~~').fontColor(this.selectedColor).fontWeight(FontWeight.Bold).maxLines(1) }
      }
      .width(50).height(24).justifyContent(FlexAlign.Center)
      .backgroundColor(this.selectedStyle === val ? '#F0F0F0' : Color.Transparent)
      .borderRadius(4)
      .border({ width: 1, color: this.selectedStyle === val ? this.selectedColor : '#EEE' })
      Text(name).fontSize(10).fontColor('#999').margin({ top: 4 })
    }
    .onClick(() => { this.selectedStyle = val })
  }
}

// --- 4. 批注输入弹窗 ---
@CustomDialog
struct NoteInputDialog {
  controller: CustomDialogController;
  @Link text: string;
  @Link selectedColor: string;
  @Link selectedStyle: number;
  onSave: () => void = () => {};

  build() {
    Column() {
      Text('添加/编辑批注').fontSize(18).fontWeight(FontWeight.Bold).margin({ top: 20, bottom: 10 })
      TextArea({ text: this.text, placeholder: '写下你的想法...' })
        .height(120).backgroundColor('#F5F5F5').borderRadius(8).margin({ bottom: 16 })
        .onChange((value) => { this.text = value; })
      Text('样式选择').fontSize(14).fontColor('#999').alignSelf(ItemAlign.Start).margin({ bottom: 8 })
      StyleSelector({ selectedColor: $selectedColor, selectedStyle: $selectedStyle })
      Row({ space: 16 }) {
        Button('取消').backgroundColor('#F5F5F5').fontColor('#666').layoutWeight(1).onClick(() => { this.controller.close() })
        Button('保存').backgroundColor('#FF8800').fontColor(Color.White).layoutWeight(1).onClick(() => { this.onSave(); this.controller.close(); })
      }.margin({ top: 20 })
    }
    .padding(24).backgroundColor(Color.White).borderRadius(16).width('90%')
  }
}

// --- 5. 批注查看弹窗 ---
@CustomDialog
struct NoteViewDialog {
  controller: CustomDialogController;
  @Prop commentContent: string;
  @Prop commentTime: number;
  @Prop isEditMode: boolean;
  @Prop isDarkMode: boolean;

  onEdit: () => void = () => {};
  onDelete: () => void = () => {};
  onCloseCall: () => void = () => {};

  build() {
    Column() {
      Row() {
        Row() {
          Image($r('sys.media.ohos_app_icon')).width(30).height(30).borderRadius(15).margin({ right: 10 })
          Column() {
            Text('我的批注').fontSize(14).fontWeight(FontWeight.Medium)
              .fontColor(this.isDarkMode ? '#E6E6E6' : '#000')
            Text(new Date(this.commentTime).toLocaleString()).fontSize(12).fontColor('#999')
          }.alignItems(HorizontalAlign.Start)
        }.layoutWeight(1)
        SymbolGlyph($r('sys.symbol.xmark')).fontSize(24).fontColor(['#999'])
          .onClick(() => { this.onCloseCall(); this.controller.close() })
      }.width('100%').margin({ bottom: 16 })

      Text(this.commentContent)
        .fontSize(16)
        .fontColor(this.isDarkMode ? '#E6E6E6' : '#333')
        .width('100%').margin({ bottom: 24 })

      Row({ space: 16 }) {
        Button('删除')
          .backgroundColor(this.isEditMode ? '#FFEBEE' : (this.isDarkMode ? '#2C2C2C' : '#F0F0F0'))
          .fontColor(this.isEditMode ? '#FF0000' : '#999')
          .layoutWeight(1)
          .enabled(this.isEditMode)
          .onClick(() => {
            this.onDelete(); this.onCloseCall(); this.controller.close();
          })

        Button('编辑')
          .backgroundColor(this.isEditMode ? '#E3F2FD' : (this.isDarkMode ? '#2C2C2C' : '#F0F0F0'))
          .fontColor(this.isEditMode ? '#0A59F7' : '#999')
          .layoutWeight(1)
          .enabled(this.isEditMode)
          .onClick(() => {
            this.onCloseCall(); this.controller.close(); setTimeout(() => { this.onEdit(); }, 50);
          })
      }
    }
    .padding(24)
    .backgroundColor(this.isDarkMode ? '#1E1E1E' : Color.White)
    .borderRadius(16).width('90%')
  }
}

// --- 主视图 ---
@Component
export struct EditorView {
  @Consume('pageStack') pageStack: NavPathStack;

  @State noteId: string = '';
  @State title: string = '';
  @State notePath: string = '';
  @State isLoaded: boolean = false;
  @State isProcessing: boolean = false;

  @StorageLink('IsDarkMode') isDarkMode: boolean = false;
  @StorageLink('IsEditMode') isEditMode: boolean = false;

  // --- AI 助手状态 ---
  // [找回] AI 助手开关
  @State isAIHelperOpen: boolean = false;
  @State currentContentForAI: string = '';

  // --- 批注状态 ---
  @State tempCommentText: string = '';
  @State tempColor: string = '#FF8800';
  @State tempStyle: number = 1;
  @State currentSelectionStart: number = -1;
  @State currentSelectionEnd: number = -1;

  @State viewContent: string = '';
  @State viewTime: number = 0;

  private activeComment: NoteComment | null = null;
  @State commentsMap: Map<string, NoteComment> = new Map();
  private lastDialogCloseTime: number = 0;
  private contentCache: string = '';

  @State autoSaveInterval: number = 0;
  private timerId: number = -1;

  // [新增] 只读视图数据
  @State readModeSpans: ReadSpanData[] = [];

  controller: RichEditorController = new RichEditorController();
  options: RichEditorOptions = { controller: this.controller };
  private currentNote: FileNode | null = null;
  private hasUnsavedChanges: boolean = false;

  // Dialog Controllers
  saveDialogController: CustomDialogController = new CustomDialogController({
    builder: SaveSettingsDialog({
      currentInterval: $autoSaveInterval,
      confirm: (val: number) => { this.updateAutoSaveStrategy(val) }
    }), alignment: DialogAlignment.Center
  });

  voiceDialogController: CustomDialogController = new CustomDialogController({
    builder: VoiceInputDialog({
      onConfirm: (path: string) => { this.handleVoiceTranscribe(path) }
    }), alignment: DialogAlignment.Center
  });

  noteInputDialogController: CustomDialogController = new CustomDialogController({
    builder: NoteInputDialog({
      text: $tempCommentText,
      selectedColor: $tempColor,
      selectedStyle: $tempStyle,
      onSave: () => { this.handleSaveComment() }
    }),
    alignment: DialogAlignment.Center,
    autoCancel: true,
    customStyle: true
  });

  noteViewDialogController: CustomDialogController = new CustomDialogController({
    builder: NoteViewDialog({
      commentContent: this.viewContent,
      commentTime: this.viewTime,
      isEditMode: this.isEditMode,
      isDarkMode: this.isDarkMode,
      onEdit: () => { this.openEditMode() },
      onDelete: () => { this.handleDeleteComment() },
      onCloseCall: () => { this.lastDialogCloseTime = Date.now(); }
    }),
    alignment: DialogAlignment.Center,
    autoCancel: true,
    customStyle: true,
    cancel: () => { this.lastDialogCloseTime = Date.now(); }
  });

  async aboutToAppear(): Promise<void> {
    const params = this.pageStack.getParamByName('Editor') as string[];
    if (params && params.length > 0) {
      this.noteId = params[params.length - 1];
      await this.loadData();
    }
  }

  aboutToDisappear(): void {
    this.clearAutoSaveTimer();
  }

  async loadData(): Promise<void> {
    const note = await DBManager.getNoteById(this.noteId);
    if (note) {
      this.currentNote = note;
      this.title = note.title;
      this.notePath = await DBManager.getNotePath(this.noteId);

      this.contentCache = note.content;
      this.currentContentForAI = note.content;

      if (note.comments && note.comments.length > 0) {
        try {
          const arr = JSON.parse(note.comments) as Array<[string, NoteComment]>;
          this.commentsMap = new Map(arr);
        } catch (e) {
          console.error('Load comments failed:', e);
        }
      }
      // 生成只读视图数据
      if (!this.isEditMode) {
        this.generateReadModeSpans();
      }
      this.isLoaded = true;
    }
  }

  updateAutoSaveStrategy(interval: number): void {
    this.autoSaveInterval = interval;
    this.clearAutoSaveTimer();
    if (interval > 0) {
      this.timerId = setInterval(() => { if (this.hasUnsavedChanges) this.saveNote(); }, interval);
    }
  }

  clearAutoSaveTimer(): void {
    if (this.timerId !== -1) { clearInterval(this.timerId); this.timerId = -1; }
  }

  updateCurrentContent(): string {
    try {
      let content = '';
      const spans = this.controller.getSpans({ start: -1, end: -1 });
      if (spans && spans.length > 0) {
        spans.forEach(span => {
          const textSpan = span as RichEditorTextSpanResult;
          if (textSpan.value) {
            content += textSpan.value;
          }
        });
        this.contentCache = content;
        this.currentContentForAI = content;
      }
    } catch(e) {
      console.error('getSpans failed:', e);
    }
    return this.contentCache;
  }

  async saveNote(): Promise<void> {
    if (!this.currentNote || !this.isLoaded) return;
    if (!this.isEditMode) return;

    try {
      const content = this.updateCurrentContent();
      this.currentNote.title = this.title;
      this.currentNote.content = content;
      if (this.commentsMap.size > 0) {
        this.currentNote.comments = JSON.stringify(Array.from(this.commentsMap.entries()));
      } else {
        this.currentNote.comments = '';
      }
      await DBManager.update(this.currentNote);
      AppStorage.setOrCreate('RefreshHome', Date.now());
      this.hasUnsavedChanges = false;
    } catch (e) {
      console.error('Save Note Error:', JSON.stringify(e));
    }
  }

  markAsDirty(): void {
    if (this.isEditMode) {
      this.hasUnsavedChanges = true;
    }
  }

  getFullBreadcrumb(): string {
    let path = this.notePath;
    if (path) { return path + ' / ' + this.title; }
    return this.title;
  }

  // --- AI 助手回调 ---
  handleAIResultApply(text: string) {
    if (this.isEditMode) {
      this.controller.addTextSpan(text);
      this.markAsDirty();
      this.saveNote();
    } else {
      AlertDialog.show({ message: '当前为只读模式，无法追加内容' });
    }
  }

  async handleImageOCR(): Promise<void> {
    try {
      const documentPicker = new picker.DocumentViewPicker();
      const documentSelectOptions = new picker.DocumentSelectOptions();
      documentSelectOptions.maxSelectNumber = 1;
      documentSelectOptions.fileSuffixFilters = ['.png', '.jpg', '.jpeg', '.bmp', '.webp'];
      const result = await documentPicker.select(documentSelectOptions);
      if (result.length > 0) {
        this.isProcessing = true;
        const uri = result[0];
        const file = fs.openSync(uri, fs.OpenMode.READ_ONLY);
        const stat = fs.statSync(file.fd);
        const buffer = new ArrayBuffer(stat.size);
        fs.readSync(file.fd, buffer);
        fs.closeSync(file);
        const base64Helper = new util.Base64Helper();
        const base64Str = base64Helper.encodeToStringSync(new Uint8Array(buffer));
        const text = await QwenService.recognizeText(base64Str);
        this.controller.addTextSpan('\n' + text + '\n');
        this.markAsDirty();
        this.saveNote();
        this.isProcessing = false;
        AlertDialog.show({ message: 'OCR 识别完成' });
      }
    } catch (err) {
      this.isProcessing = false;
      console.error('OCR Failed:', err);
    }
  }

  async handleVoiceTranscribe(filePath: string): Promise<void> {
    this.isProcessing = true;
    try {
      const text = await QwenService.transcribeAudio(filePath);
      this.controller.addTextSpan('\n' + text + '\n');
      this.markAsDirty();
      this.saveNote();
      AlertDialog.show({ message: '语音转换完成' });
    } catch (err) {
      console.error('ASR Failed', err);
      AlertDialog.show({ message: '语音识别失败' });
    } finally {
      this.isProcessing = false;
    }
  }

  applyCommentStyle(start: number, end: number, color: string, styleType: number) {
    let style = TextDecorationStyle.SOLID;
    if (styleType === 1) style = TextDecorationStyle.DASHED;
    if (styleType === 2) style = TextDecorationStyle.WAVY;
    this.controller.updateSpanStyle({
      start: start, end: end,
      textStyle: { decoration: { type: TextDecorationType.Underline, color: color, style: style } }
    });
  }

  removeCommentStyle(start: number, end: number) {
    this.controller.updateSpanStyle({
      start: start, end: end,
      textStyle: { decoration: { type: TextDecorationType.None } }
    });
  }

  handleSaveComment() {
    if (this.tempCommentText.trim() === '') return;
    if (this.currentSelectionStart >= 0 && this.currentSelectionEnd > this.currentSelectionStart) {
      const id = this.activeComment ? this.activeComment.id : `${Date.now()}`;
      const comment: NoteComment = {
        id: id,
        rangeStart: this.currentSelectionStart,
        rangeEnd: this.currentSelectionEnd,
        content: this.tempCommentText,
        colorStr: this.tempColor,
        styleType: this.tempStyle,
        createTime: Date.now()
      };
      this.commentsMap.set(id, comment);
      this.applyCommentStyle(this.currentSelectionStart, this.currentSelectionEnd, this.tempColor, this.tempStyle);
      this.activeComment = null;
      this.markAsDirty();
    }
  }

  handleDeleteComment() {
    if (this.activeComment) {
      this.removeCommentStyle(this.activeComment.rangeStart, this.activeComment.rangeEnd);
      this.commentsMap.delete(this.activeComment.id);
      this.activeComment = null;
      this.markAsDirty();
    }
  }

  openCreateMode() {
    this.controller.closeSelectionMenu();
    const selection = this.controller.getSelection();
    if (selection.selection[0] !== selection.selection[1]) {
      this.currentSelectionStart = selection.selection[0];
      this.currentSelectionEnd = selection.selection[1];
      this.tempCommentText = '';
      this.tempColor = '#FF8800';
      this.tempStyle = 1;
      this.activeComment = null;
      setTimeout(() => { this.noteInputDialogController.open(); }, 200);
    }
  }

  openEditMode() {
    if (this.activeComment) {
      this.currentSelectionStart = this.activeComment.rangeStart;
      this.currentSelectionEnd = this.activeComment.rangeEnd;
      this.tempCommentText = this.activeComment.content;
      this.tempColor = this.activeComment.colorStr;
      this.tempStyle = this.activeComment.styleType;
      this.noteInputDialogController.open();
    }
  }

  checkCommentAtCursor(index: number) {
    if (Date.now() - this.lastDialogCloseTime < 500) return;
    let found: NoteComment | null = null;
    this.commentsMap.forEach((val) => {
      if (index >= val.rangeStart && index < val.rangeEnd) { found = val; }
    });
    if (found) {
      this.activeComment = found;
      this.viewContent = (found as NoteComment).content;
      this.viewTime = (found as NoteComment).createTime;
      this.noteViewDialogController.open();
    }
  }

  // 只读模式渲染算法
  generateReadModeSpans() {
    const text = this.contentCache;
    if (!text) {
      this.readModeSpans = [];
      return;
    }
    const comments = Array.from(this.commentsMap.values()).sort((a, b) => a.rangeStart - b.rangeStart);
    const spans: ReadSpanData[] = [];
    let currentIndex = 0;
    for (const comment of comments) {
      if (comment.rangeStart >= text.length) continue;
      if (comment.rangeStart > currentIndex) {
        spans.push({ text: text.substring(currentIndex, comment.rangeStart) });
      }
      const end = Math.min(comment.rangeEnd, text.length);
      if (end > comment.rangeStart) {
        spans.push({
          text: text.substring(comment.rangeStart, end),
          comment: comment
        });
      }
      currentIndex = end;
    }
    if (currentIndex < text.length) {
      spans.push({ text: text.substring(currentIndex) });
    }
    this.readModeSpans = spans;
  }

  // [新增] 只读视图构建器
  @Builder ReadModeView() {
    Scroll() {
      Text() {
        ForEach(this.readModeSpans, (span: ReadSpanData) => {
          if (span.comment) {
            // 带下划线的批注
            Span(span.text)
              .fontColor(this.isDarkMode ? '#E6E6E6' : '#000000')
              .fontSize(16)
              .decoration({
                type: TextDecorationType.Underline,
                color: span.comment.colorStr,
                style: span.comment.styleType === 1 ? TextDecorationStyle.DASHED :
                  (span.comment.styleType === 2 ? TextDecorationStyle.WAVY : TextDecorationStyle.SOLID)
              })
              .onClick(() => {
                this.activeComment = span.comment || null;
                if (this.activeComment) {
                  this.viewContent = this.activeComment.content;
                  this.viewTime = this.activeComment.createTime;
                  this.noteViewDialogController.open();
                }
              })
          } else {
            // 普通文本
            Span(span.text)
              .fontColor(this.isDarkMode ? '#E6E6E6' : '#000000')
              .fontSize(16)
          }
        })
      }
      .width('100%')
      .padding({ left: 24, right: 24, bottom: 16 })
    }
    .layoutWeight(1)
    .width('100%')
    .align(Alignment.TopStart)
  }

  build() {
    NavDestination() {
      // [找回] 使用 Stack 包裹所有内容
      Stack({ alignContent: Alignment.Top }) {
        Column() {
          Row() {
            Row() { SymbolGlyph($r('sys.symbol.chevron_left')).fontSize(24).fontColor(this.isDarkMode ? ['#E6E6E6'] : ['#333']) }
            .width(40).height(40).justifyContent(FlexAlign.Center)
            .onClick(async () => {
              try { await this.saveNote(); } catch(e) {}
              this.pageStack.pop();
            })

            Text(this.getFullBreadcrumb()).fontSize(14)
              .fontColor(this.isDarkMode ? '#999' : '#666')
              .maxLines(1).textOverflow({ overflow: TextOverflow.Ellipsis }).layoutWeight(1).padding({ left: 8, right: 8 })

            // [找回] 魔法棒 AI 入口 (常驻)
            Row() {
              SymbolGlyph($r('sys.symbol.wand_and_stars'))
                .fontSize(24)
                .fontColor(this.isAIHelperOpen ? ['#7B1FA2'] : (this.isDarkMode ? ['#E6E6E6'] : ['#666']))
            }
            .width(40).height(40).justifyContent(FlexAlign.Center)
            .onClick(() => {
              animateTo({ duration: 300, curve: Curve.FastOutSlowIn }, () => {
                this.isAIHelperOpen = !this.isAIHelperOpen;
              });
            })

            // 保存按钮 (仅编辑模式显示)
            if (this.isEditMode) {
              Row() {
                if (this.isProcessing) { LoadingProgress().width(24).height(24).color('#0A59F7') }
                else { SymbolGlyph($r('sys.symbol.checkmark')).fontSize(24).fontColor(this.hasUnsavedChanges ? ['#0A59F7'] : ['#999']) }
              }
              .width(40).height(40).justifyContent(FlexAlign.Center)
              .onClick(async () => { await this.saveNote(); AlertDialog.show({ message: '已保存' }); })
              .gesture(LongPressGesture().onAction(() => { this.saveDialogController.open(); }))
            }
          }
          .width('100%').height(56).padding({ left: 12, right: 12 })
          .backgroundColor(this.isDarkMode ? '#1E1E1E' : Color.White)
          .border({ width: { bottom: 1 }, color: this.isDarkMode ? '#333' : '#f0f0f0' })

          TextInput({ text: this.title, placeholder: '无标题' })
            .fontSize(26).fontWeight(FontWeight.Bold).backgroundColor(Color.Transparent)
            .fontColor(this.isDarkMode ? '#E6E6E6' : '#000')
            .placeholderColor(this.isDarkMode ? '#666' : '#999')
            .padding({ left: 24, right: 24, top: 16, bottom: 8 })
            .focusable(this.isEditMode)
            .onChange((value) => { this.title = value; this.markAsDirty(); })

          // [核心逻辑] 根据模式切换组件
          if (this.isEditMode) {
            if (this.isLoaded) {
              RichEditor(this.options)
                .layoutWeight(1).width('100%').padding({ left: 24, right: 24, bottom: 16 })
                .focusable(true)
                .copyOptions(CopyOptions.LocalDevice)
                .onReady(() => {
                  if (this.currentNote) {
                    const textColor = this.isDarkMode ? '#E6E6E6' : '#000000';
                    this.controller.setTypingStyle({ fontColor: textColor, fontSize: 16 });
                    this.controller.addTextSpan(this.currentNote.content, { style: { fontSize: 16, fontColor: textColor } });
                    this.commentsMap.forEach(c => {
                      this.applyCommentStyle(c.rangeStart, c.rangeEnd, c.colorStr, c.styleType);
                    });
                    this.updateCurrentContent();
                  }
                })
                .onSelectionChange((value: RichEditorRange) => {
                  if (value.start !== undefined && value.end !== undefined && value.start === value.end) {
                    this.checkCommentAtCursor(value.start);
                  }
                })
                .onIMEInputComplete(() => {
                  this.updateCurrentContent();
                  this.markAsDirty();
                })
                .aboutToDelete(() => { this.markAsDirty(); return true; })
                .bindSelectionMenu(RichEditorSpanType.TEXT, this.CustomMenuBuilder, ResponseType.LongPress)
            } else {
              Column() { LoadingProgress().width(40).height(40) }.layoutWeight(1).justifyContent(FlexAlign.Center)
            }
          } else {
            // 只读模式视图
            this.ReadModeView()
          }

          if (this.isEditMode) {
            Row() {
              this.ToolButton($r('sys.symbol.picture'), () => { this.handleImageOCR(); })
              this.ToolButton($r('sys.symbol.camera'), () => { AlertDialog.show({ message: '模拟器暂不支持相机，请使用图片上传功能' }); })
              this.ToolButton($r('sys.symbol.mic'), () => { this.voiceDialogController.open(); })
            }
            .width('100%').height(56)
            .backgroundColor(this.isDarkMode ? '#1E1E1E' : Color.White)
            .justifyContent(FlexAlign.SpaceAround).shadow({ radius: 10, color: 'rgba(0,0,0,0.05)', offsetY: -2 })
          }
        }
        .width('100%').height('100%')
        .backgroundColor(this.isDarkMode ? '#121212' : Color.White)

        // [找回] AI 助手层
        if (this.isAIHelperOpen) {
          Column() {
            AIAssistantView({
              currentContent: this.currentContentForAI,
              onApplyResult: (text: string) => { this.handleAIResultApply(text); },
              onClose: () => {
                animateTo({ duration: 300, curve: Curve.FastOutSlowIn }, () => {
                  this.isAIHelperOpen = false;
                });
              }
            })
          }
          .width('100%')
          .transition(TransitionEffect.move(TransitionEdge.TOP))
          .zIndex(100)
        }
      }
    }
    .hideTitleBar(true)
    .onBackPressed(() => { this.saveNote(); this.pageStack.pop(); return true; })
  }

  @Builder CustomMenuBuilder() {
    Column() {
      Row() {
        SymbolGlyph($r('sys.symbol.square_and_pencil')).fontSize(20).fontColor(['#333']).margin({ right: 8 })
        Text('添加批注').fontSize(16).fontColor('#333')
      }.padding({ left: 16, right: 16, top: 12, bottom: 12 }).onClick(() => { this.openCreateMode(); })
    }.backgroundColor(Color.White).borderRadius(12).shadow({ radius: 10, color: 'rgba(0,0,0,0.2)' })
  }

  @Builder ToolButton(icon: Resource, action: () => void) {
    Button({ type: ButtonType.Circle, stateEffect: true }) {
      SymbolGlyph(icon).fontSize(24)
        .fontColor(this.isDarkMode ? ['#E6E6E6'] : ['#555'])
    }
    .backgroundColor(Color.Transparent).width(48).height(48).onClick(action)
  }
}