// entry/src/main/ets/utils/AIMax.ets
// 1. 完全复用中等难度的基础类型（无任何修改）
export interface Coord {
  x: number;
  y: number;
  color: boolean; // true=玩家（黑），false=AI（白）
}

interface Point {
  x: number;
  y: number;
}

interface ScoreMap {
  win: number;
  live4: number;
  sleep4: number;
  live3: number;
  sleep3: number;
  live2: number;
  sleep2: number;
}

// 2. 完全复用老师的评分参数（无任何修改）
const SCORE_MAP: ScoreMap = {
  win: 100000,
  live4: 10000,
  sleep4: 1000,
  live3: 1000,
  sleep3: 100,
  live2: 100,
  sleep2: 10
};

// 3. 困难难度配置（显式类型声明，避免语法报错）
interface Config {
  PREDICT_STEPS: number; // 5步预测（AI→玩家→AI→玩家→AI）
  MAX_SCORE: number;     // AI获胜的最高分
  MIN_SCORE: number;     // 玩家获胜的最低分
  MAX_DIST: number;      // 筛选空位的最大距离（优化性能）
}

const CONFIG: Config = {
  PREDICT_STEPS: 1,
  MAX_SCORE: 1000000,
  MIN_SCORE: -1000000,
  MAX_DIST: 3 // 只搜离已有棋子≤3的空位，减少5步预测的搜索量
};

// 4. 完全复用中等难度的 getPointScore 打分函数（无任何修改）
function getPointScore(
  chess_coord: Coord[],
  x: number,
  y: number,
  targetColor: boolean
): number {
  let score = 0;
  const directions: [number, number][] = [[1, 0], [0, 1], [1, 1], [1, -1]];

  // 遍历4个方向（无数组解构，用索引访问）
  for (let i = 0; i < directions.length; i++) {
    const dx = directions[i][0];
    const dy = directions[i][1];
    let count = 1;
    let open = 0;

    for (let dir = -1; dir <= 1; dir += 2) {
      if (dir === 0) continue;
      for (let iStep = 1; iStep < 5; iStep++) {
        const curX = x + iStep * dx * dir;
        const curY = y + iStep * dy * dir;

        if (curX < 0 || curX >= 15 || curY < 0 || curY >= 15) {
          break;
        }

        const piece = chess_coord.find(c => c.x === curX && c.y === curY);
        if (piece) {
          if (piece.color === targetColor) {
            count++;
          } else {
            break;
          }
        } else {
          open++;
          break;
        }
      }
    }

    if (count >= 5) {
      score += SCORE_MAP.win;
    } else if (count === 4) {
      score += (open === 2) ? SCORE_MAP.live4 : SCORE_MAP.sleep4;
    } else if (count === 3) {
      score += (open === 2) ? SCORE_MAP.live3 : SCORE_MAP.sleep3;
    } else if (count === 2) {
      score += (open === 2) ? SCORE_MAP.live2 : SCORE_MAP.sleep2;
    }
  }

  return score;
}

// 5. 辅助函数：筛选有价值的空位（优化5步预测性能）
function getValidEmptyPoints(
  chess_coord: Coord[],
  isCoordEmpty: (x: number, y: number) => boolean
): Point[] {
  const validPoints: Point[] = [];

  // 空棋盘：直接返回中心及周围空位（复用中等难度逻辑）
  if (chess_coord.length === 0) {
    return [
      { x: 7, y: 7 }, { x: 6, y: 7 }, { x: 7, y: 6 },
      { x: 8, y: 7 }, { x: 7, y: 8 }, { x: 6, y: 6 }
    ];
  }

  // 非空棋盘：只保留离已有棋子≤3的空位（减少搜索量）
  for (let x = 0; x < 15; x++) {
    for (let y = 0; y < 15; y++) {
      if (isCoordEmpty(x, y)) {
        let minDist = Infinity;
        // 计算当前空位到所有已有棋子的最小曼哈顿距离
        for (const coord of chess_coord) {
          const dist = Math.abs(x - coord.x) + Math.abs(y - coord.y);
          if (dist < minDist) {
            minDist = dist;
          }
        }
        if (minDist <= CONFIG.MAX_DIST) {
          validPoints.push({ x, y });
        }
      }
    }
  }

  // 极端情况：无有效空位，返回中心
  return validPoints.length > 0 ? validPoints : [{ x: 7, y: 7 }];
}

// 6. 辅助函数：判断当前棋盘的胜利者（Minimax终止条件）
function checkWinner(chess_coord: Coord[]): boolean | null {
  if (chess_coord.length < 5) return null; // 不足5子，不可能获胜

  for (const coord of chess_coord) {
    const color = coord.color;
    const directions: [number, number][] = [[1, 0], [0, 1], [1, 1], [1, -1]];

    // 遍历4个方向（无数组解构）
    for (let i = 0; i < directions.length; i++) {
      const dx = directions[i][0];
      const dy = directions[i][1];
      let count = 1;

      // 正方向查4步
      for (let iStep = 1; iStep < 5; iStep++) {
        const found = chess_coord.find(
          c => c.x === coord.x + iStep * dx && c.y === coord.y + iStep * dy && c.color === color
        );
        if (found) count++; else break;
      }

      // 反方向查4步
      for (let iStep = 1; iStep < 5; iStep++) {
        const found = chess_coord.find(
          c => c.x === coord.x - iStep * dx && c.y === coord.y - iStep * dy && c.color === color
        );
        if (found) count++; else break;
      }

      // 五连子获胜
      if (count >= 5) {
        return color;
      }
    }
  }

  return null;
}

// 7. 修复：计算棋盘总得分（改用“所有空位的最大得分”，和中等难度逻辑一致）
function calculateTotalScore(chess_coord: Coord[], targetColor: boolean): number {
  let maxScore = 0; // 记录目标颜色在所有空位的最大得分
  const isCoordEmpty = (x: number, y: number) => {
    return !chess_coord.some(c => c.x === x && c.y === y);
  };

  // 遍历所有空位，计算目标颜色在该空位落子后的得分
  for (let x = 0; x < 15; x++) {
    for (let y = 0; y < 15; y++) {
      if (isCoordEmpty(x, y)) {
        const score = getPointScore(chess_coord, x, y, targetColor);
        if (score > maxScore) {
          maxScore = score;
        }
      }
    }
  }

  return maxScore;
}

// 8. Minimax核心函数（含Alpha-Beta剪枝，5步预测核心）
function minimax(
  chess_coord: Coord[],
  aiColor: boolean,
  playerColor: boolean,
  depth: number, // 剩余预测步数
  alpha: number, // Max层最优得分
  beta: number,  // Min层最优得分
  isMaxTurn: boolean // true=AI回合（Max），false=玩家回合（Min）
): number {
  // 终止条件1：预测步数用尽，返回当前棋盘总分差
  if (depth === 0) {
    const aiTotal = calculateTotalScore(chess_coord, aiColor);
    const playerTotal = calculateTotalScore(chess_coord, playerColor);
    return aiTotal - playerTotal * 1.1; // 复用中等难度的防守权重
  }

  // 终止条件2：分出胜负
  const winner = checkWinner(chess_coord);
  if (winner === aiColor) {
    return CONFIG.MAX_SCORE + depth; // AI赢，步数越多分越高（优先快赢）
  } else if (winner === playerColor) {
    return CONFIG.MIN_SCORE - depth; // 玩家赢，步数越多分越低（避免慢输）
  }

  // 终止条件3：棋盘满（平局）
  if (chess_coord.length >= 15 * 15) {
    return 0;
  }

  // 筛选当前层的有效空位（继续优化性能）
  const emptyPoints = getValidEmptyPoints(chess_coord, (x, y) => {
    return !chess_coord.some(c => c.x === x && c.y === y);
  });

  if (isMaxTurn) {
    // Max层：AI落子，追求得分最大化
    let maxScore = CONFIG.MIN_SCORE;
    for (let i = 0; i < emptyPoints.length; i++) {
      const point = emptyPoints[i];
      const x = point.x; // 直接访问属性
      const y = point.y; // 直接访问属性

      // 模拟AI落子
      chess_coord.push({ x, y, color: aiColor });
      // 递归：下一层是Min层（玩家），步数-1
      const score = minimax(chess_coord, aiColor, playerColor, depth - 1, alpha, beta, false);
      // 撤销模拟落子（关键：不影响真实棋盘）
      chess_coord.pop();

      // 更新Max层最优得分
      maxScore = Math.max(maxScore, score);
      alpha = Math.max(alpha, maxScore);

      // Alpha-Beta剪枝：当前得分≥Min层最优，后续分支无需搜索
      if (alpha >= beta) {
        break;
      }
    }
    return maxScore;
  } else {
    // Min层：玩家落子，追求得分最小化（给AI制造麻烦）
    let minScore = CONFIG.MAX_SCORE;
    for (let i = 0; i < emptyPoints.length; i++) {
      const point = emptyPoints[i];
      const x = point.x; // 直接访问属性
      const y = point.y; // 直接访问属性

      // 模拟玩家落子
      chess_coord.push({ x, y, color: playerColor });
      // 递归：下一层是Max层（AI），步数-1
      const score = minimax(chess_coord, aiColor, playerColor, depth - 1, alpha, beta, true);
      // 撤销模拟落子
      chess_coord.pop();

      // 更新Min层最优得分
      minScore = Math.min(minScore, score);
      beta = Math.min(beta, minScore);

      // Alpha-Beta剪枝：当前得分≤Max层最优，后续分支无需搜索
      if (alpha >= beta) {
        break;
      }
    }
    return minScore;
  }
}

// 9. 困难难度对外暴露函数（和aiMoveMedium入参完全一致，确保Classic调用不变）
export function aiMoveMax(
  chess_coord: Coord[],
  aiColor: boolean,
  isGameOver: boolean,
  drawAIChess: (x: number, y: number) => void,
  isCoordEmpty: (x: number, y: number) => boolean
) {
  if (isGameOver) return;

  let bestScore = CONFIG.MIN_SCORE;
  let bestMove: Point | null = null;
  const playerColor = !aiColor;
  // 筛选有效空位（减少5步预测的搜索量）
  const validEmptyPoints = getValidEmptyPoints(chess_coord, isCoordEmpty);

  // 遍历所有有效空位，计算Minimax得分
  for (let i = 0; i < validEmptyPoints.length; i++) {
    const point = validEmptyPoints[i];
    const x = point.x; // 直接访问属性
    const y = point.y; // 直接访问属性

    // 模拟AI落子（第一步）
    chess_coord.push({ x, y, color: aiColor });
    // 调用Minimax：剩余4步（5-1），下一层是玩家（Min层）
    const score = minimax(
      chess_coord,
      aiColor,
      playerColor,
      CONFIG.PREDICT_STEPS - 1,
      CONFIG.MIN_SCORE,
      CONFIG.MAX_SCORE,
      false
    );
    // 撤销模拟落子
    chess_coord.pop();

    // 记录最高分落子
    if (score > bestScore) {
      bestScore = score;
      bestMove = point;
    }

    // 剪枝优化：找到必胜落子，直接终止搜索
    if (score === CONFIG.MAX_SCORE) {
      break;
    }
  }

  // 执行落子（和中等难度逻辑一致）
  if (bestMove) {
    drawAIChess(bestMove.x, bestMove.y);
  } else {
    drawAIChess(-1, -1); // 平局
  }
}
