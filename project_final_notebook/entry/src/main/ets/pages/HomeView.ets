import { FileNode, NodeType, SortOption } from '../model/NoteModel';
import DBManager from '../utils/DBManager';
import { common } from '@kit.AbilityKit';
import { promptAction } from '@kit.ArkUI';

// --- 0. 接口定义 ---
interface MatchSnippet {
  prefix: string;
  text: string;
}

interface HighlightPart {
  text: string;
  isHighlight: boolean;
}

// --- 1. 密码验证弹窗 (保持不变) ---
@CustomDialog
struct PasswordDialog {
  controller: CustomDialogController;
  confirm: () => void = () => {};

  @State passwordInput: string = '';
  @State errorMessage: string = '';

  build() {
    Column() {
      Text('进入编辑模式').fontSize(18).fontWeight(FontWeight.Bold).margin({ top: 24, bottom: 8 })
      Text('请输入管理员密码').fontSize(14).fontColor('#999').margin({ bottom: 20 })

      TextInput({ text: this.passwordInput, placeholder: '8位数字密码' })
        .type(InputType.Password).maxLength(8)
        .onChange((value) => { this.passwordInput = value; this.errorMessage = ''; })
        .width('90%').height(44).margin({ bottom: 8 })
        .backgroundColor('#F5F5F5').borderRadius(8).defaultFocus(true)

      if (this.errorMessage) {
        Text(this.errorMessage).fontSize(12).fontColor(Color.Red).margin({ bottom: 8 })
      } else {
        Text(' ').fontSize(12).margin({ bottom: 8 })
      }

      Row() {
        Button('取消').onClick(() => { this.controller.close() }).backgroundColor(Color.White).fontColor('#666666').width('40%')
        Divider().vertical(true).height(20).color('#E5E5E5')
        Button('验证').onClick(() => {
          if (this.passwordInput === '82728008') { this.confirm(); this.controller.close(); }
          else { this.errorMessage = '密码错误，请重试'; this.passwordInput = ''; }
        }).backgroundColor(Color.White).fontColor('#0A59F7').width('40%')
      }.width('100%').justifyContent(FlexAlign.SpaceEvenly).margin({ bottom: 16 })
    }
    .backgroundColor(Color.White).borderRadius(16).width('80%')
  }
}

// --- 2. 通用输入弹窗 (保持不变) ---
@CustomDialog
struct InputDialog {
  controller: CustomDialogController;
  title: string = '';
  @State inputValue: string = '';
  confirm: (value: string) => void = () => {};

  build() {
    Column() {
      Text(this.title).fontSize(18).fontWeight(FontWeight.Bold).margin({ top: 24, bottom: 16 }).fontColor('#333333')
      TextInput({ text: this.inputValue, placeholder: '请输入名称' })
        .onChange((value) => { this.inputValue = value }).width('90%').height(44).margin({ bottom: 24 })
        .backgroundColor('#F5F5F5').borderRadius(8).defaultFocus(true)
      Row() {
        Button('取消').onClick(() => { this.controller.close() }).backgroundColor(Color.White).fontColor('#666666').width('40%')
        Divider().vertical(true).height(20).color('#E5E5E5')
        Button('确认').onClick(() => {
          if (this.inputValue.trim().length > 0) { this.confirm(this.inputValue); this.controller.close(); }
        }).backgroundColor(Color.White).fontColor('#0A59F7').width('40%')
      }.width('100%').justifyContent(FlexAlign.SpaceEvenly).margin({ bottom: 16 })
    }
    .backgroundColor(Color.White).borderRadius(16).width('80%')
  }
}

// --- 3. ToolbarIconBtn (已适配深色模式) ---
@Component
struct ToolbarIconBtn {
  @Prop icon: Resource;
  @Prop tooltip: string;
  @Prop iconSize: number = 22;
  @Prop angle: number = 0;
  action: () => void = () => {};

  @State showPopup: boolean = false;
  // [新增] 监听深色模式，改变图标颜色
  @StorageLink('IsDarkMode') isDarkMode: boolean = false;

  @Builder TooltipBuilder(): void {
    Row() { Text(this.tooltip).fontColor(Color.White).fontSize(12) }
    .padding({ left: 12, right: 12, top: 8, bottom: 8 }).backgroundColor('#333333').borderRadius(6)
  }

  build(): void {
    Row() {
      SymbolGlyph(this.icon)
        .fontSize(this.iconSize)
          // [修改] 颜色适配
        .fontColor(this.isDarkMode ? ['#E6E6E6'] : ['#333333'])
        .rotate({ angle: this.angle }).animation({ duration: 300, curve: Curve.FastOutSlowIn })
    }
    .onClick(() => { this.action(); })
    .bindPopup(this.showPopup, {
      builder: () => { this.TooltipBuilder() },
      placement: Placement.Bottom, popupColor: '#333333', enableArrow: true,
      onStateChange: (e) => { if (!e.isVisible) { this.showPopup = false; } }
    })
    .gesture(LongPressGesture({ repeat: false }).onAction(() => { this.showPopup = true; }).onActionEnd(() => { this.showPopup = false; }))
  }
}

// --- 4. FolderArrow (已适配深色模式) ---
@Component
struct FolderArrow {
  @Prop isExpanded: boolean;
  @StorageLink('IsDarkMode') isDarkMode: boolean = false;

  build() {
    Row() {
      SymbolGlyph($r('sys.symbol.chevron_right'))
        .fontSize(14)
          // [修改] 颜色适配
        .fontColor(this.isDarkMode ? ['#999999'] : ['#666666'])
        .rotate({ angle: this.isExpanded ? 90 : 0 }).animation({ duration: 300, curve: Curve.FastOutSlowIn })
    }
    .width('100%').height('100%').justifyContent(FlexAlign.Center)
  }
}

// --- 5. HomeView ---
@Component
export struct HomeView {
  @Consume('pageStack') pageStack: NavPathStack;

  @State rawTree: FileNode[] = [];
  @State displayList: FileNode[] = [];
  @State currentSort: SortOption = 'name_asc';
  @State isAllExpanded: boolean = true;
  @State showFavoritesOnly: boolean = false;
  @State searchKeyword: string = '';

  @StorageLink('IsEditMode') isEditMode: boolean = false;

  // [新增] 全局深色模式状态 (默认浅色)
  @StorageLink('IsDarkMode') isDarkMode: boolean = false;

  @StorageProp('RefreshHome') @Watch('onRefreshTriggered') refreshSignal: number = 0;

  inputDialogController: CustomDialogController | null = null;

  passwordDialogController: CustomDialogController = new CustomDialogController({
    builder: PasswordDialog({
      confirm: () => {
        this.isEditMode = true;
        promptAction.showToast({ message: '已切换至编辑模式', duration: 2000 });
      }
    }), alignment: DialogAlignment.Center, autoCancel: true
  });

  async aboutToAppear(): Promise<void> {
    AppStorage.setOrCreate('IsEditMode', false);
    // 初始化深色模式状态
    if (AppStorage.get('IsDarkMode') === undefined) {
      AppStorage.setOrCreate('IsDarkMode', false);
    }

    const context = getContext(this) as common.UIAbilityContext;
    await DBManager.init(context);
    this.reloadFromDB();
  }

  onRefreshTriggered() {
    this.reloadFromDB();
  }

  async reloadFromDB(): Promise<void> {
    const tree = await DBManager.getFileTree();
    this.rawTree = tree;
    this.refreshDisplayList();
  }

  refreshDisplayList(): void {
    let treeToDisplay = this.rawTree;
    const keyword = this.searchKeyword.trim().toLowerCase();
    if (keyword.length > 0) {
      treeToDisplay = this.filterTreeByKeyword(treeToDisplay, keyword);
    }
    if (this.showFavoritesOnly) {
      treeToDisplay = this.filterFavorites(treeToDisplay);
    }
    this.sortTree(treeToDisplay);
    this.displayList = this.flattenTree(treeToDisplay, 0);
  }

  formatDate(timestamp: number): string {
    const dateObj = new Date(timestamp);
    return `${dateObj.getFullYear()}/${dateObj.getMonth() + 1}/${dateObj.getDate()}`;
  }

  filterTreeByKeyword(nodes: FileNode[], keyword: string): FileNode[] {
    let result: FileNode[] = [];
    for (const node of nodes) {
      const isSelfMatch = this.checkMatch(node, keyword);
      if (node.type === 'folder') {
        const filteredChildren = this.filterTreeByKeyword(node.children, keyword);
        const hasChildMatch = filteredChildren.length > 0;
        if (hasChildMatch) {
          const folderCopy = this.cloneNode(node);
          folderCopy.isExpanded = true;
          folderCopy.children = filteredChildren;
          result.push(folderCopy);
        } else if (isSelfMatch) {
          const folderCopy = this.cloneNode(node);
          folderCopy.isExpanded = false;
          folderCopy.children = [...node.children];
          result.push(folderCopy);
        }
      } else {
        if (isSelfMatch) {
          result.push(node);
        }
      }
    }
    return result;
  }

  checkMatch(node: FileNode, keyword: string): boolean {
    const matchTitle = node.title.toLowerCase().includes(keyword);
    const matchContent = node.content.toLowerCase().includes(keyword);
    const updateStr = this.formatDate(node.updatedAt);
    const createStr = this.formatDate(node.createdAt);
    const matchDate = updateStr.includes(keyword) || createStr.includes(keyword);
    return matchTitle || matchContent || matchDate;
  }

  cloneNode(node: FileNode): FileNode {
    const newNode = new FileNode(node.id, node.type, node.title, node.content, node.parentId, node.level);
    newNode.updatedAt = node.updatedAt;
    newNode.createdAt = node.createdAt;
    newNode.isFavorite = node.isFavorite;
    newNode.isExpanded = node.isExpanded;
    return newNode;
  }

  filterFavorites(nodes: FileNode[]): FileNode[] {
    let result: FileNode[] = [];
    for (const node of nodes) {
      if (node.type === 'file') {
        if (node.isFavorite) result.push(node);
      } else {
        const filteredChildren = this.filterFavorites(node.children);
        if (filteredChildren.length > 0) {
          const folderCopy = this.cloneNode(node);
          folderCopy.isExpanded = true;
          folderCopy.children = filteredChildren;
          result.push(folderCopy);
        }
      }
    }
    return result;
  }

  flattenTree(nodes: FileNode[], depth: number): FileNode[] {
    let result: FileNode[] = [];
    for (const node of nodes) {
      node.level = depth;
      result.push(node);
      if (node.type === 'folder' && node.isExpanded && node.children.length > 0) {
        result = result.concat(this.flattenTree(node.children, depth + 1));
      }
    }
    return result;
  }

  sortTree(nodes: FileNode[]): void {
    nodes.sort((a, b) => {
      if (a.type !== b.type) return a.type === 'folder' ? -1 : 1;
      switch (this.currentSort) {
        case 'name_asc': return a.title.localeCompare(b.title);
        case 'name_desc': return b.title.localeCompare(a.title);
        case 'edit_new': return b.updatedAt - a.updatedAt;
        case 'edit_old': return a.updatedAt - b.updatedAt;
        case 'create_new': return b.createdAt - a.createdAt;
        case 'create_old': return a.createdAt - b.createdAt;
        default: return 0;
      }
    });
    for (const node of nodes) {
      if (node.type === 'folder' && node.children.length > 0) {
        this.sortTree(node.children);
      }
    }
  }

  findNodeById(nodes: FileNode[], id: string): FileNode | null {
    for (const node of nodes) {
      if (node.id === id) return node;
      if (node.children.length > 0) {
        const found = this.findNodeById(node.children, id);
        if (found) return found;
      }
    }
    return null;
  }

  toggleExpand(item: FileNode): void {
    const realNode = this.findNodeById(this.rawTree, item.id);
    if (realNode) {
      realNode.isExpanded = !realNode.isExpanded;
      DBManager.update(realNode);
      animateTo({ duration: 300, curve: Curve.FastOutSlowIn }, () => {
        this.refreshDisplayList();
      });
    }
  }

  toggleAll(): void {
    if (this.searchKeyword.length > 0) return;
    this.isAllExpanded = !this.isAllExpanded;
    const recursiveSet = (nodes: FileNode[]) => {
      for (const node of nodes) {
        if (node.type === 'folder') {
          node.isExpanded = this.isAllExpanded;
          DBManager.update(node);
          if (node.children.length > 0) recursiveSet(node.children);
        }
      }
    };
    recursiveSet(this.rawTree);
    animateTo({ duration: 300, curve: Curve.FastOutSlowIn }, () => {
      this.refreshDisplayList();
    })
  }

  toggleFavorite(item: FileNode): void {
    const realNode = this.findNodeById(this.rawTree, item.id);
    if (realNode) {
      realNode.isFavorite = !realNode.isFavorite;
      DBManager.update(realNode);
      this.refreshDisplayList();
    }
  }

  createItem(type: NodeType, parent?: FileNode): void {
    const dialogTitle = type === 'folder' ? '新建文件夹' : '新建笔记';
    this.inputDialogController = new CustomDialogController({
      builder: InputDialog({
        title: dialogTitle,
        inputValue: '',
        confirm: (title: string) => { this.performCreateItem(type, title, parent); }
      }), alignment: DialogAlignment.Center, autoCancel: true
    });
    this.inputDialogController.open();
  }

  performCreateItem(type: NodeType, title: string, parent?: FileNode): void {
    const parentId = parent ? parent.id : 'root';
    const newItem = new FileNode(`${Date.now()}`, type, title, '', parentId);
    DBManager.insert(newItem).then(() => {
      this.reloadFromDB();
    });
  }

  startRename(item: FileNode): void {
    this.inputDialogController = new CustomDialogController({
      builder: InputDialog({
        title: '重命名',
        inputValue: item.title,
        confirm: (newValue: string) => {
          item.title = newValue;
          DBManager.update(item);
          this.refreshDisplayList();
        }
      }), alignment: DialogAlignment.Center, autoCancel: true
    });
    this.inputDialogController.open();
  }

  deleteItem(item: FileNode): void {
    DBManager.delete(item.id).then(() => {
      this.reloadFromDB();
    });
  }

  @Builder MenuRow(icon: Resource, text: string, color: string = '#333333'): void {
    Row() {
      SymbolGlyph(icon).fontColor([color]).fontSize(20).margin({ right: 12 })
      Text(text).fontColor(color).fontSize(16).fontWeight(FontWeight.Medium).layoutWeight(1)
    }
    .padding({ left: 4, right: 4, top: 4, bottom: 4 })
  }

  @Builder FolderMenuBuilder(item: FileNode): void {
    Menu() {
      MenuItem() { this.MenuRow($r('sys.symbol.folder'), '新建文件夹') }.onClick(() => { this.createItem('folder', item) })
      MenuItem() { this.MenuRow($r('sys.symbol.plus'), '新建笔记') }.onClick(() => { this.createItem('file', item) })
      MenuItem() { Divider() }
      MenuItem() { this.MenuRow($r('sys.symbol.square_and_pencil'), '重命名') }.onClick(() => { this.startRename(item) })
      MenuItem() { this.MenuRow($r('sys.symbol.trash'), '删除', '#FF0000') }.onClick(() => { this.deleteItem(item) })
    }
  }

  @Builder FileMenuBuilder(item: FileNode): void {
    Menu() {
      MenuItem() {
        this.MenuRow(
          item.isFavorite ? $r('sys.symbol.star_fill') : $r('sys.symbol.star'),
          item.isFavorite ? '取消收藏' : '收藏'
        )
      }
      .onClick(() => { this.toggleFavorite(item) })

      MenuItem() { Divider() }
      MenuItem() { this.MenuRow($r('sys.symbol.square_and_pencil'), '重命名') }.onClick(() => { this.startRename(item) })
      MenuItem() { this.MenuRow($r('sys.symbol.trash'), '删除', '#FF0000') }.onClick(() => { this.deleteItem(item) })
    }
  }

  @Builder ContextMenuBuilder(item: FileNode): void {
    if (this.isEditMode) {
      if (item.type === 'folder') {
        this.FolderMenuBuilder(item);
      } else {
        this.FileMenuBuilder(item);
      }
    }
  }

  getSortLabel(option: SortOption, label: string): string {
    return label + (this.currentSort === option ? '  ✓' : '');
  }

  applySort(option: SortOption): void {
    this.currentSort = option;
    this.refreshDisplayList();
  }

  splitTextToParts(text: string, keyword: string): HighlightPart[] {
    if (!keyword || keyword.length === 0) return [{ text: text, isHighlight: false }];
    const result: HighlightPart[] = [];
    let tempText = text;
    const lowerKeyword = keyword.toLowerCase();
    while (true) {
      const idx = tempText.toLowerCase().indexOf(lowerKeyword);
      if (idx === -1) {
        if (tempText.length > 0) { result.push({ text: tempText, isHighlight: false }); }
        break;
      }
      if (idx > 0) { result.push({ text: tempText.substring(0, idx), isHighlight: false }); }
      const matchText = tempText.substring(idx, idx + keyword.length);
      result.push({ text: matchText, isHighlight: true });
      tempText = tempText.substring(idx + keyword.length);
    }
    return result;
  }

  @Builder HighlightText(text: string, keyword: string, fontSize: number = 16, normalColor: string = '#333333'): void {
    Text() {
      ForEach(this.splitTextToParts(text, keyword), (part: HighlightPart) => {
        Span(part.text)
          .fontSize(fontSize)
            // [修改] 颜色适配：在深色模式下，普通文字用白色
          .fontColor(part.isHighlight ? Color.Black : (this.isDarkMode ? '#E6E6E6' : normalColor))
          .backgroundColor(part.isHighlight ? '#FFF600' : Color.Transparent)
          .fontWeight(part.isHighlight ? FontWeight.Bold : FontWeight.Normal)
      })
    }
    .maxLines(1).textOverflow({ overflow: TextOverflow.Ellipsis })
  }

  getMatchSnippet(item: FileNode): MatchSnippet | null {
    if (this.searchKeyword.length === 0) return null;
    const keyword = this.searchKeyword.toLowerCase();
    const contentOneLine = item.content.replace(/[\r\n]+/g, ' ');
    const contentIndex = contentOneLine.toLowerCase().indexOf(keyword);
    if (contentIndex !== -1) {
      const start = Math.max(0, contentIndex - 10);
      const end = Math.min(contentOneLine.length, contentIndex + keyword.length + 20);
      let snippet = contentOneLine.substring(start, end);
      if (start > 0) snippet = '...' + snippet;
      if (end < contentOneLine.length) snippet = snippet + '...';
      return { prefix: '', text: snippet };
    }
    const updateStr = this.formatDate(item.updatedAt);
    if (updateStr.includes(keyword)) { return { prefix: '最后编辑：', text: updateStr }; }
    const createStr = this.formatDate(item.createdAt);
    if (createStr.includes(keyword)) { return { prefix: '创建日期：', text: createStr }; }
    return null;
  }

  @Builder MatchSnippetView(item: FileNode): void {
    if (this.getMatchSnippet(item)) {
      Row() {
        Text(this.getMatchSnippet(item)!.prefix).fontSize(12).fontColor('#999999')
        this.HighlightText(this.getMatchSnippet(item)!.text, this.searchKeyword, 12, '#888888')
      }.margin({ top: 2 })
    }
  }

  @Builder FileTreeNode(item: FileNode, isExpanded: boolean, title: string): void {
    Row() {
      ForEach(new Array(item.level).fill(0), (val: number, index: number) => {
        Row() { Divider().vertical(true).strokeWidth(1).color(this.isDarkMode ? '#444' : '#E0E0E0').height('100%') }
        .width(24).height('100%').justifyContent(FlexAlign.Center)
      }, (val: number, index: number) => index.toString())

      Row() {
        if (item.type === 'folder') {
          FolderArrow({ isExpanded: isExpanded })
        }
      }
      .width(24).height('100%').justifyContent(FlexAlign.Center)
      .onClick(() => { if (item.type === 'folder') this.toggleExpand(item); })

      Column() {
        Row() {
          if (this.searchKeyword.length > 0) {
            this.HighlightText(title, this.searchKeyword)
          } else {
            Text(title)
              .fontSize(16)
                // [修改] 颜色适配
              .fontColor(this.isDarkMode ? '#E6E6E6' : '#333333')
              .maxLines(1).textOverflow({ overflow: TextOverflow.Ellipsis })
          }

          if (item.type === 'file' && item.isFavorite) {
            SymbolGlyph($r('sys.symbol.star_fill')).fontSize(14).fontColor(['#FFB900']).margin({ left: 8 })
          }
        }
        .width('100%')

        if (this.searchKeyword.length > 0) {
          this.MatchSnippetView(item)
        }
      }
      .layoutWeight(1).padding({ left: 4, right: 16, top: 6, bottom: 6 })
      .justifyContent(FlexAlign.Center).alignItems(HorizontalAlign.Start)
    }
    .width('100%')
    .height(this.searchKeyword.length > 0 && this.getMatchSnippet(item) ? 56 : 40)
    .backgroundColor(Color.Transparent)
    .bindContextMenu(
      this.isEditMode ? this.ContextMenuBuilder(item) : null,
      ResponseType.LongPress
    )
    .onClick(() => {
      if (item.type === 'folder') {
        this.toggleExpand(item);
      } else {
        const pathInfo = new NavPathInfo('Editor', item.id, (popInfo) => { this.reloadFromDB(); });
        this.pageStack.pushDestination(pathInfo, true);
      }
    })
  }

  build(): void {
    Stack({ alignContent: Alignment.BottomEnd }) {
      Column() {
        this.ToolbarBuilder()
        this.SearchBuilder()

        List() {
          ForEach(this.displayList, (item: FileNode) => {
            ListItem() {
              this.FileTreeNode(item, item.isExpanded, item.title)
            }
          }, (item: FileNode) => {
            return item.id + '_' + item.title + '_' + (item.isFavorite ? '1' : '0') + '_' + this.searchKeyword;
          })
        }
        .width('100%').layoutWeight(1).scrollBar(BarState.Auto).edgeEffect(EdgeEffect.Spring)
      }
      .width('100%').height('100%')
      // [修改] 颜色适配：背景
      .backgroundColor(this.isDarkMode ? '#121212' : '#FAFAFA')
    }
  }

  @Builder ToolbarBuilder(): void {
    Row() {
      // 1. 左侧标题
      Text('我的笔记')
        .fontSize(24).fontWeight(FontWeight.Bold).layoutWeight(1)
        .fontColor(this.isDarkMode ? '#E6E6E6' : '#000000')

      // 2. 右侧图标总容器
      Row() {
        // --- 第一组：文件与视图操作 (紧凑排列) ---
        Row({ space: 4 }) {
          // 编辑模式下才显示的新建按钮
          if (this.isEditMode) {
            ToolbarIconBtn({
              icon: $r('sys.symbol.folder'), tooltip: '新建文件夹',
              action: () => this.createItem('folder')
            })
            ToolbarIconBtn({
              icon: $r('sys.symbol.plus'), tooltip: '新建笔记', iconSize: 24,
              action: () => this.createItem('file')
            })
          }

          // 排序按钮
          Row() {
            SymbolGlyph($r('sys.symbol.list_bullet')).fontSize(22)
              .fontColor(this.isDarkMode ? ['#E6E6E6'] : ['#333333'])
          }
          .padding({ left: 8, right: 8, top: 8, bottom: 8 }) // 增加点击热区
          .bindMenu([
            { value: this.getSortLabel('name_asc', '文件名 (A-Z)'), action: () => this.applySort('name_asc') },
            { value: this.getSortLabel('name_desc', '文件名 (Z-A)'), action: () => this.applySort('name_desc') },
            { value: this.getSortLabel('edit_new', '编辑时间 (从新到旧)'), action: () => this.applySort('edit_new') },
            { value: this.getSortLabel('edit_old', '编辑时间 (从旧到新)'), action: () => this.applySort('edit_old') },
            { value: this.getSortLabel('create_new', '创建时间 (从新到旧)'), action: () => this.applySort('create_new') },
            { value: this.getSortLabel('create_old', '创建时间 (从旧到新)'), action: () => this.applySort('create_old') },
          ])

          // 折叠按钮
          ToolbarIconBtn({
            icon: $r('sys.symbol.chevron_right'), tooltip: this.isAllExpanded ? '全部折叠' : '全部展开',
            angle: this.isAllExpanded ? 90 : 0, action: () => this.toggleAll()
          })
        }

        // --- 中间分隔符 (竖线) ---
        Divider()
          .vertical(true)
          .height(20)
          .color(this.isDarkMode ? '#444' : '#D0D0D0')
          .margin({ left: 12, right: 12 }) // 分隔符左右留白

        // --- 第二组：系统模式切换 (深色、锁) ---
        Row({ space: 16 }) {
          // 深色模式开关
          Row() {
            SymbolGlyph(this.isDarkMode ? $r('sys.symbol.moon_fill') : $r('sys.symbol.sun_max_fill'))
              .fontSize(22)
              .fontColor(this.isDarkMode ? ['#FFB900'] : ['#666'])
          }
          .onClick(() => {
            animateTo({ duration: 300 }, () => {
              this.isDarkMode = !this.isDarkMode;
            })
          })

          // 编辑模式锁
          Row() {
            SymbolGlyph(this.isEditMode ? $r('sys.symbol.lock_open_fill') : $r('sys.symbol.lock_fill'))
              .fontSize(22)
              .fontColor(this.isEditMode ? ['#0A59F7'] : (this.isDarkMode ? ['#999'] : ['#666']))
          }
          .onClick(() => {
            if (this.isEditMode) {
              this.isEditMode = false;
              promptAction.showToast({ message: '已切换至只读模式', duration: 2000 });
            } else {
              this.passwordDialogController.open();
            }
          })
        }
      }
    }
    .width('100%')
    .padding({ left: 20, right: 20, top: 12, bottom: 12 })
    .backgroundColor(this.isDarkMode ? '#121212' : '#FAFAFA')
  }

  @Builder SearchBuilder(): void {
    Row({ space: 8 }) {
      Row() {
        SymbolGlyph($r('sys.symbol.magnifyingglass')).fontSize(18).fontColor(['#999999'])
        TextInput({ text: this.searchKeyword, placeholder: '搜索标题、内容、日期...' })
          .fontSize(14)
            // [修改] 颜色适配
          .fontColor(this.isDarkMode ? '#E6E6E6' : '#333')
          .placeholderColor('#999').caretColor('#0A59F7')
          .backgroundColor(Color.Transparent).layoutWeight(1).margin({ left: 4 })
          .onChange((value) => { this.searchKeyword = value; this.refreshDisplayList(); })
        if (this.searchKeyword.length > 0) {
          SymbolGlyph($r('sys.symbol.xmark_circle_fill')).fontSize(16).fontColor(['#999'])
            .onClick(() => { this.searchKeyword = ''; this.refreshDisplayList(); })
        }
      }
      .layoutWeight(1).height(36)
      // [修改] 颜色适配
      .backgroundColor(this.isDarkMode ? '#2C2C2C' : '#F0F0F0')
      .borderRadius(10).padding({ left: 12, right: 8 })

      Row() {
        SymbolGlyph($r('sys.symbol.star_fill')).fontSize(20)
          .fontColor(this.showFavoritesOnly ? ['#FFB900'] : ['#CCCCCC'])
      }
      .width(36).height(36)
      .backgroundColor(this.showFavoritesOnly ? '#FFF6D1' : (this.isDarkMode ? '#2C2C2C' : '#F0F0F0'))
      .borderRadius(10).justifyContent(FlexAlign.Center)
      .onClick(() => {
        this.showFavoritesOnly = !this.showFavoritesOnly;
        this.refreshDisplayList();
      })
    }
    .width('92%').margin({ bottom: 8 }).padding({ left: 4, right: 4 })
  }
}