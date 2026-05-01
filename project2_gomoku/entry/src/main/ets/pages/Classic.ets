// entry/src/main/ets/pages/Classic.ets
import router from '@ohos.router';
// 导入AIEasy的方法和类型（注意路径要正确：../utils/AIEasy）
import { aiMoveEasy, checkPlayerThreat, Coord as AICoord } from '../utils/AIEasy';
// 导入AIMedium中的Point接口（解决类型不兼容）
import { aiMoveMedium, getMediumHint, HintPoint } from '../utils/AIMedium'; // 导入HintPoint
import { aiMoveMax } from '../utils/AIMax';
import promptAction from '@ohos.promptAction';

// 新增：定义路由参数接口（替代对象字面量类型）
interface RouterParams {
  gameMode?: number;
}

// 确保Coord类型与AIEasy一致（可直接复用AIEasy的Coord）
type Coord = AICoord;

@Entry
@Component
struct Index {
  // 游戏模式：0=人人对战，1=简单，2=中等，3=困难
  private gameMode: number = 0;
  // AI相关状态
  private isAIMoving: boolean = false; // 防止AI重复落子
  private aiColor: boolean = false; // AI固定白棋（false）
  private playerColor: boolean = true; // 玩家固定黑棋（true）
  private isGameOver: boolean = false; // 游戏结束标记
  @State isAiThinking: boolean = false;

  // 新增：提示标记相关状态
  @State hintCoord: Coord | null = null; // 提示的落子坐标（null表示无提示）

  // 新增：背景色常量（254,255,250 转换为RGBA）
  private bgColor: string = 'rgba(254, 255, 250, 1)'; // 按钮所在区域背景色
  private hintColor: string = 'rgba(255, 165, 0, 0.8)'; // 提示状态颜色（橙黄色）


  // 新增：提示功能相关变量
  @State showHintButton: boolean = false; // 提示按钮是否显示
  private hintTimer: number = -1; // 计时器ID（用于清除）

  // Classic.ets -> getHintAndMark (简化版)

  private getHintAndMark() {
    const bestPoint: HintPoint | null = getMediumHint(
      this.chess_coord,
      this.chess_color,
      this.isCoordEmpty.bind(this)
    );

    if (bestPoint) {
      // 【核心修正】创建完整的 Coord 对象 (这个修正你上次已经做了，保持住)
      this.hintCoord = {
        x: bestPoint.x,
        y: bestPoint.y,
        color: this.chess_color
      };
      // 【简化】不再需要调用 startHintBlink()
      // 只需要触发一次重绘，让提示点显示出来
      this.redrawAllChess();
    } else {
      promptAction.showToast({ message: '没有可落子的位置了' });
    }
  }

  // 新增：启动超时计时器（每次回合开始时调用）
  private startHintTimer(): void {
    // 先清除之前的计时器（避免重复计时）
    if (this.hintTimer !== -1) {
      clearTimeout(this.hintTimer);
    }
    // 5秒后显示提示按钮
    this.hintTimer = setTimeout(() => {
      this.showHintButton = true;
    }, 5000); // 5000ms = 5秒
  }

  // Classic.ets -> resetHintState (简化版)

  private resetHintState(): void {
    if (this.hintTimer !== -1) {
      clearTimeout(this.hintTimer);
      this.hintTimer = -1;
    }
    this.showHintButton = false;

    // 如果之前有提示，现在清空它并重绘一次棋盘以擦除提示点
    if (this.hintCoord) {
      this.hintCoord = null;
      this.redrawAllChess();
    } else {
      this.hintCoord = null;
    }

    // 【删除】this.isHintAnimating = false;
  }

  // 新增：计算属性 - 判断是否可悔棋（控制悔棋按钮禁用状态）
  // 去掉@Computed，保留getter方法+显式返回类型
  private get canUndo(): boolean {
    // 基础条件：游戏未结束 + 非AI落子中
    if (this.isGameOver || this.isAIMoving) return false;

    if (this.gameMode === 0) {
      return this.chess_coord.length >= 1;
    } else {
      return this.chess_coord.length >= 2 && this.chess_color === this.playerColor;
    }
  }

  // 画布相关变量
  private settings: RenderingContextSettings = new RenderingContextSettings(true)
  private context: CanvasRenderingContext2D = new CanvasRenderingContext2D(this.settings)
  board_x: number = 0
  board_y: number = 0
  board_width: number = 0
  line_spacing: number = 0
  // 修改后（添加@State，确保UI随状态变化）
  @State chess_color: boolean = true; // 当前落子颜色
  chess_coord: Coord[] = []; // 所有棋子坐标

  // 页面初始化：获取路由参数
  aboutToAppear() {
    const params = router.getParams() as RouterParams | undefined;
    if (params && params.gameMode !== undefined) {
      this.gameMode = params.gameMode;
    }
  }

  build() {
    Column() {
      // 顶部仅保留返回按钮（移除当前回合提示）
      Row() {
        Button({ type: ButtonType.Circle }) {
          Text('返回')
            .fontSize(14)
            .fontColor('#000')
        }
        .width(40)
        .height(40)
        .margin({ top: 20, left: 20 })
        .backgroundColor('rgba(255,255,255,0.3)')
        .onClick(() => router.back())

        Blank() // 右侧留空，保持返回按钮居左
      }
      .width('100%')

      // 提示按钮的onClick事件修改
      Button('提示')
        .fontSize(18).fontWeight(FontWeight.Bold)
        .width(100).height(40)
        .backgroundColor(this.showHintButton ? this.hintColor : this.bgColor)
        .fontColor(this.showHintButton ? '#FFFFFF' : this.bgColor)
        .borderWidth(0)
        .margin({ top: 10, bottom: 5 })
        .onClick(() => {
          this.showHintButton = false; // 隐藏提示按钮
          this.getHintAndMark(); // 新增：获取提示并标记
        })

      // 当前回合提示（移到操作按钮上方，居中显示）
      Row() {
        Image(this.chess_color ? $r('app.media.black_chess') : $r('app.media.white_chess'))
          .width(30).height(30).objectFit(ImageFit.Contain)
        Text(this.isGameOver ? '游戏结束' : '当前回合')
          .fontSize(18).fontColor(Color.Black).margin({ left: 10 })
      }
      .padding({ left: 15, right: 15, top: 5, bottom: 5 })
      .backgroundColor('rgba(255, 255, 255, 0.5)').borderRadius(20)
      .margin({ bottom: 1 }) // 与下方操作按钮间距减小

      // 悔棋+重新开始按钮（靠近棋盘，减少与棋盘的距离）
      Row() {
        Button('悔棋')
          .fontSize(18).fontWeight(FontWeight.Bold)
          .width(120).height(50)
          .backgroundColor('rgba(255, 255, 255, 0.7)').fontColor(Color.Black)
          .enabled(this.canUndo)
          .onClick(() => this.undoMove())

        Blank()

        Button('重新开始')
          .fontSize(18).fontWeight(FontWeight.Bold)
          .width(120).height(50)
          .backgroundColor('rgba(255, 255, 255, 0.7)').fontColor(Color.Black)
          .onClick(() => this.restartGame())
      }
      .width('90%')
      .margin({ bottom: 1 }) // 大幅减少与棋盘的距离（原15→8）

      // 棋盘区域
      Stack() {
        Canvas(this.context)
          .width('90%')
          .aspectRatio(1)
          .onReady(() => this.init())
          .onClick((e) => {
            if (this.isGameOver || this.isAIMoving || (this.gameMode !== 0 && this.chess_color !== this.playerColor)) {
              return;
            }
            this.drawChess(e.x, e.y);
          })
      }
      .layoutWeight(1)
      .alignContent(Alignment.Center)
    }
    .width('100%').height('100%')
    .backgroundImage($r("app.media.background_new"))
    .backgroundImageSize(ImageSize.Cover)
  }

  // 新增：单独绘制棋盘（棋盘线、星位、背景，不含棋子）
  private drawBoard() {
    // 计算棋盘尺寸（适配屏幕）
    if (this.context.width < this.context.height) {
      this.board_width = this.context.width - 40;
    } else {
      this.board_width = this.context.height - 40;
    }
    this.board_x = (this.context.width - this.board_width) / 2;
    this.board_y = (this.context.height - this.board_width) / 2;

    // 绘制棋盘背景和边框
    this.context.lineWidth = 4;
    this.context.fillStyle = '#DBC26F';
    this.context.strokeStyle = '#000';
    this.context.fillRect(this.board_x, this.board_y, this.board_width, this.board_width);
    this.context.strokeRect(this.board_x, this.board_y, this.board_width, this.board_width);

    // 绘制棋盘线（14x14棋盘，15个格点）
    this.line_spacing = this.board_width / 14;
    this.context.beginPath();
    this.context.lineWidth = 2;
    for (let i = 0; i < 15; i++) {
      // 水平线
      this.context.moveTo(this.board_x, this.board_y + i * this.line_spacing);
      this.context.lineTo(this.board_x + this.board_width, this.board_y + i * this.line_spacing);
      // 垂直线
      this.context.moveTo(this.board_x + i * this.line_spacing, this.board_y);
      this.context.lineTo(this.board_x + i * this.line_spacing, this.board_y + this.board_width);
    }
    this.context.stroke();

    // 绘制星位
    const starPoints: Coord[] = [
      { x: 3, y: 3, color: true },
      { x: 11, y: 3, color: true },
      { x: 3, y: 11, color: true },
      { x: 11, y: 11, color: true },
      { x: 7, y: 7, color: true }
    ];
    this.context.fillStyle = '#000';
    this.context.lineWidth = 1;
    for (const point of starPoints) {
      this.context.beginPath();
      const x = this.board_x + point.x * this.line_spacing;
      const y = this.board_y + point.y * this.line_spacing;
      this.context.arc(x, y, 4, 0, 2 * Math.PI);
      this.context.fill();
    }
  }

  // Classic.ets -> redrawAllChess (全新修改版)

  private redrawAllChess(): void {
    this.context.clearRect(0, 0, this.context.width, this.context.height);
    this.initBoard(); // 重新绘制棋盘网格

    // 1. 绘制所有真实的棋子（这部分逻辑不变）
    this.chess_coord.forEach(coord => {
      this.context.fillStyle = coord.color ? '#000' : '#FFF';
      this.context.strokeStyle = '#000';
      this.context.lineWidth = 1;
      this.context.beginPath();
      this.context.arc(
        this.board_x + coord.x * this.line_spacing,
        this.board_y + coord.y * this.line_spacing,
        this.line_spacing / 2 - 2,
        0, 2 * Math.PI
      );
      this.context.fill();
      this.context.stroke();
    });

    // 2. 【核心修改】绘制虚线提示棋子
    if (this.hintCoord) {
      const hintX = this.board_x + this.hintCoord.x * this.line_spacing;
      const hintY = this.board_y + this.hintCoord.y * this.line_spacing;
      const radius = this.line_spacing / 2 - 3; // 提示棋子比真实棋子略小一点

      // 步骤 A: 绘制半透明的棋子内部
      this.context.fillStyle = this.chess_color
        ? 'rgba(0, 0, 0, 0.5)'   // 半透明黑色
        : 'rgba(255, 255, 255, 0.6)'; // 半透明白色
      this.context.beginPath();
      this.context.arc(hintX, hintY, radius, 0, 2 * Math.PI);
      this.context.fill();

      // 步骤 B: 绘制虚线边框
      this.context.strokeStyle = '#FFA500'; // 橙色边框
      this.context.lineWidth = 2;
      // 设置虚线样式：[线长, 间距] -> [5, 3] 表示 5像素的线段 + 3像素的空白
      this.context.setLineDash([5, 3]);
      this.context.beginPath();
      this.context.arc(hintX, hintY, radius, 0, 2 * Math.PI);
      this.context.stroke();

      // 步骤 C: 【非常重要】取消虚线设置，恢复为实线，以免影响后续绘制
      this.context.setLineDash([]);
    }
  }

  // 1. 只负责绘制棋盘样式（线、星位、背景），不重置棋子
  private initBoard(): void {
    // 计算棋盘尺寸（适配屏幕）
    if (this.context.width < this.context.height) {
      this.board_width = this.context.width - 40;
    } else {
      this.board_width = this.context.height - 40;
    }
    this.board_x = (this.context.width - this.board_width) / 2;
    this.board_y = (this.context.height - this.board_width) / 2;

    // 绘制棋盘背景和边框
    this.context.lineWidth = 4;
    this.context.fillStyle = '#DBC26F';
    this.context.strokeStyle = '#000';
    this.context.fillRect(this.board_x, this.board_y, this.board_width, this.board_width);
    this.context.strokeRect(this.board_x, this.board_y, this.board_width, this.board_width);

    // 绘制棋盘线
    this.line_spacing = this.board_width / 14;
    this.context.beginPath();
    this.context.lineWidth = 2;
    for (let i = 0; i < 15; i++) {
      this.context.moveTo(this.board_x, this.board_y + i * this.line_spacing);
      this.context.lineTo(this.board_x + this.board_width, this.board_y + i * this.line_spacing);
      this.context.moveTo(this.board_x + i * this.line_spacing, this.board_y);
      this.context.lineTo(this.board_x + i * this.line_spacing, this.board_y + this.board_width);
    }
    this.context.stroke();

    // 绘制星位
    const starPoints: Coord[] = [
      { x: 3, y: 3, color: true },
      { x: 11, y: 3, color: true },
      { x: 3, y: 11, color: true },
      { x: 11, y: 11, color: true },
      { x: 7, y: 7, color: true }
    ];
    this.context.fillStyle = '#000';
    this.context.lineWidth = 1;
    for (const point of starPoints) {
      this.context.beginPath();
      const x = this.board_x + point.x * this.line_spacing;
      const y = this.board_y + point.y * this.line_spacing;
      this.context.arc(x, y, 4, 0, 2 * Math.PI);
      this.context.fill();
    }
  }

  // 2. 初始化游戏（调用棋盘绘制+重置状态）
  private init(): void {
    this.initBoard(); // 只绘制棋盘样式
    // 重置游戏状态（清空棋子等）
    this.chess_coord = [];
    this.chess_color = this.playerColor;
    this.isGameOver = false;
    this.isAIMoving = false;
    this.resetHintState(); // 重置提示状态
    this.startHintTimer(); // 新回合开始，启动计时
  }

  private undoMove(): void {
    // 1. 游戏结束时不能悔棋
    if (this.isGameOver) {
      promptAction.showToast({ message: '游戏已结束，不能悔棋！' });
      return;
    }

    // 2. 检查是否有足够棋子可悔
    if (this.gameMode === 0) {
      // 人人对战：至少1步
      if (this.chess_coord.length < 1) {
        promptAction.showToast({ message: '没有棋子可悔！' });
        return;
      }
    } else {
      // 人机对战：至少2步
      if (this.chess_coord.length < 2) {
        promptAction.showToast({ message: '至少下两步才能悔棋！' });
        return;
      }
    }

    // 3. 根据模式删除棋子
    if (this.gameMode === 0) {
      this.chess_coord.pop(); // 人人对战删1步
      this.chess_color = !this.chess_color; // 切换回合
    } else {
      this.chess_coord.pop(); // 人机对战删AI的棋
      this.chess_coord.pop(); // 再删玩家的棋
      // 人机对战悔棋后仍为玩家回合（无需切换）
    }
    // 4. 重新绘制棋盘和棋子（使用新的redrawAllChess）
    this.redrawAllChess();
    this.resetHintState();
    if (!this.isGameOver) {
      this.startHintTimer();
    }
  }

  // 新增：重新开始游戏
  private restartGame(): void {
    // 重置棋子数组
    this.chess_coord = [];
    // 重置当前回合（玩家先出）
    this.chess_color = this.playerColor;
    // 重置游戏状态
    this.isGameOver = false;
    this.isAIMoving = false;
    // 清空画布并重新初始化
    this.context.clearRect(0, 0, this.context.width, this.context.height);
    this.init();
    this.resetHintState();
    this.startHintTimer();
    this.redrawAllChess();
  }

  // 绘制玩家棋子（核心：落子后触发AI回合）
  drawChess(x: number, y: number) {
    // 1. 检查是否在棋盘内
    if (x < this.board_x || x > this.board_x + this.board_width ||
      y < this.board_y || y > this.board_y + this.board_width) {
      return;
    }

    // 2. 转换为棋盘格点坐标（0-13）
    const gridX = Math.round((x - this.board_x) / this.line_spacing);
    const gridY = Math.round((y - this.board_y) / this.line_spacing);

    // 3. 检查该位置是否已有棋子
    if (!this.isCoordEmpty(gridX, gridY)) {
      return;
    }

    // 4. 绘制玩家棋子
    this.context.fillStyle = this.chess_color ? '#000' : '#FFF';
    this.context.strokeStyle = '#000';
    this.context.beginPath();
    this.context.arc(
      this.board_x + gridX * this.line_spacing,
      this.board_y + gridY * this.line_spacing,
      this.line_spacing / 2 - 2, // 棋子大小（适配线间距）
      0,
      2 * Math.PI
    );
    this.context.fill();
    this.context.stroke();

    // 5. 记录棋子坐标
    const newCoord: Coord = { x: gridX, y: gridY, color: this.chess_color };
    this.chess_coord.push(newCoord);

    // 6. 检查玩家是否获胜
    if (this.checkLink(newCoord)) {
      this.gameOver(`${this.chess_color ? '黑棋（玩家）' : '白棋（AI）'} 获胜！`);
      return;
    }

    // 7. 检查是否平局（棋盘满）
    if (this.chess_coord.length >= 14 * 14) {
      this.gameOver('平局！');
      return;
    }

    this.resetHintState();
    if (!this.isGameOver) {
      this.startHintTimer();
    }

    // 8. 切换回合（玩家→AI）
    this.chess_color = !this.chess_color;

    // 9. 简单难度：触发AI落子
    if (this.gameMode === 1 && this.chess_color === this.aiColor) {
      // 简单难度逻辑（不变）
      this.isAIMoving = true;
      setTimeout(() => {
        aiMoveEasy(
          this.chess_coord,
          this.aiColor,
          this.isGameOver,
          this.drawAIChess.bind(this),
          this.isCoordEmpty.bind(this),
          checkPlayerThreat
        );
        this.isAIMoving = false;
      }, 100);
    } else if (this.gameMode === 2 && this.chess_color === this.aiColor) {
      // 新增：中等难度逻辑
      this.isAIMoving = true;
      setTimeout(() => {
        aiMoveMedium(
          this.chess_coord,
          this.aiColor,
          this.isGameOver,
          this.drawAIChess.bind(this), // 复用AI落子回调
          this.isCoordEmpty.bind(this)   // 复用空位校验回调
        );
        this.isAIMoving = false;
      }, 100);
    }else if (this.gameMode === 3 && this.chess_color === this.aiColor) {
      // 困难难度：Minimax+Alpha-Beta剪枝（预测3步）
      this.isAIMoving = true;
      setTimeout(() => {
        aiMoveMax(
          this.chess_coord,
          this.aiColor,
          this.isGameOver,
          this.drawAIChess.bind(this), // 复用落子回调
          this.isCoordEmpty.bind(this)  // 复用空位校验
        );
        this.isAIMoving = false; // 重置状态，避免卡住
      }, 100); // 困难难度搜索稍久，延迟800ms更自然
    }
    this.redrawAllChess();
  }

  // 绘制AI棋子（专门给AI用的落子方法）
  private drawAIChess(x: number, y: number) {
    // 1. 绘制AI棋子（白棋）
    this.context.fillStyle = '#FFF';
    this.context.strokeStyle = '#000';
    this.context.beginPath();
    this.context.arc(
      this.board_x + x * this.line_spacing,
      this.board_y + y * this.line_spacing,
      this.line_spacing / 2 - 2,
      0,
      2 * Math.PI
    );
    this.context.fill();
    this.context.stroke();

    // 2. 记录AI棋子坐标
    const aiCoord: Coord = { x, y, color: this.aiColor };
    this.chess_coord.push(aiCoord);

    // 3. 检查AI是否获胜
    if (this.checkLink(aiCoord)) {
      this.gameOver('白棋（AI）获胜！');
      return;
    }

    // 4. 检查是否平局
    if (this.chess_coord.length >= 14 * 14) {
      this.gameOver('平局！');
      return;
    }

    this.resetHintState();
    if (!this.isGameOver) {
      this.startHintTimer();
    }
    // 5. 切换回合（AI→玩家）
    this.chess_color = this.playerColor;
  }

  // 辅助方法：检查坐标是否为空
  private isCoordEmpty(x: number, y: number): boolean {
    return !this.chess_coord.some(coord => coord.x === x && coord.y === y);
  }

  // 胜负判断（原有逻辑不变，修正方向遍历语法）
  private checkLink(lastCoord: Coord): boolean {
    const directions: [number, number][] = [[1, 0], [0, 1], [1, 1], [-1, 1]];

    // 遍历4个方向
    for (let i = 0; i < directions.length; i++) {
      const dx = directions[i][0];
      const dy = directions[i][1];
      // 检查该方向是否有5连子
      for (let method = 0; method < 5; method++) {
        const linkingCoords: Coord[] = [];
        for (let j = 0; j < 5; j++) {
          const newCoord: Coord = {
            x: lastCoord.x + dx * (j - method),
            y: lastCoord.y + dy * (j - method),
            color: lastCoord.color
          };
          // 查找是否有对应棋子
          const found = this.chess_coord.find(coord =>
          coord.x === newCoord.x && coord.y === newCoord.y && coord.color === newCoord.color
          );
          if (found) linkingCoords.push(found);
        }
        // 5连子则判定获胜
        if (linkingCoords.length >= 5) {
          // 高亮获胜棋子（黄色边框）
          linkingCoords.forEach(item => {
            this.context.strokeStyle = '#FEFE00';
            this.context.lineWidth = 2;
            this.context.beginPath();
            this.context.arc(
              item.x * this.line_spacing + this.board_x,
              item.y * this.line_spacing + this.board_y,
              this.line_spacing / 2 - 2,
              0,
              2 * Math.PI
            );
            this.context.stroke();
          });
          return true;
        }
      }
    }
    return false;
  }

  // 游戏结束弹窗（修正AlertDialog导入和配置）
  private gameOver(message: string) {
    this.isGameOver = true;
    this.resetHintState();
    AlertDialog.show({
      message: message, // 对应你之前的 `恭喜${xxx}赢了` 格式
      cancel: () => {
        // 初始化棋盘（完全复用你之前的逻辑）
        this.chess_coord = [];
        this.chess_color = this.playerColor; // 玩家重新先落子
        this.context.clearRect(0, 0, this.context.width, this.context.height);
        this.init();
      }
    });
  }
}