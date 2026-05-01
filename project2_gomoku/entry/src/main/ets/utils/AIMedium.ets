// entry/src/main/ets/utils/AIMedium.ets
// （保留原有接口定义）
export interface Coord {
  x: number;
  y: number;
  color: boolean; // true=玩家（黑），false=AI（白）
}

export interface HintPoint {
  x: number;
  y: number;
}

export interface Point {
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
const SCORE_MAP: ScoreMap = {
  win: 100000,
  live4: 10000,
  sleep4: 1000,
  live3: 1000,
  sleep3: 100,
  live2: 100,
  sleep2: 10
};

// 原有AI落子方法（不变，供AI自己落子时使用）
export function aiMoveMedium(
  chess_coord: Coord[],
  aiColor: boolean,
  isGameOver: boolean,
  drawAIChess: (x: number, y: number) => void,
  isCoordEmpty: (x: number, y: number) => boolean
) {
  if (isGameOver) return;
  const bestMove = findBestMove(chess_coord, aiColor, isCoordEmpty);
  if (bestMove) {
    drawAIChess(bestMove.x, bestMove.y);
  } else {
    drawAIChess(-1, -1);
  }
}

// 新增：提示功能专用方法（只返回最优落子点，不落子）
export function getMediumHint(
  chess_coord: Coord[],
  targetColor: boolean,
  isCoordEmpty: (x: number, y: number) => boolean
): HintPoint | null { // 返回HintPoint
  return findBestMove(chess_coord, targetColor, isCoordEmpty);
}

// 原有核心评分逻辑（不变，供上面两个方法共用）
function findBestMove(
  chess_coord: Coord[],
  targetColor: boolean, // 改为通用的"目标颜色"（AI或当前回合颜色）
  isCoordEmpty: (x: number, y: number) => boolean
): HintPoint | null {
  let bestScore = -1;
  let bestMove: HintPoint | null = null;
  const emptyPoints: HintPoint[] = [];
  const oppositeColor = !targetColor; // 对手颜色

  // 遍历所有空位计算得分（复用原有逻辑）
  for (let y = 0; y < 15; y++) {
    for (let x = 0; x < 15; x++) {
      if (isCoordEmpty(x, y)) {
        emptyPoints.push({ x, y });
        const targetScore = getPointScore(chess_coord, x, y, targetColor); // 目标颜色进攻分
        const oppositeScore = getPointScore(chess_coord, x, y, oppositeColor); // 对手防守分
        const currentScore = targetScore + oppositeScore * 1.1; // 保持原权重

        if (currentScore > bestScore) {
          bestScore = currentScore;
          bestMove = { x, y };
        }
      }
    }
  }

  // 特殊情况处理（空棋盘或无得分点，复用原有逻辑）
  if (bestScore === 0 && emptyPoints.length > 0) {
    if (chess_coord.length === 0) {
      return { x: 7, y: 7 }; // 中心
    }
    let minDist = Infinity;
    for (const p of emptyPoints) {
      for (const c of chess_coord) {
        const dist = Math.abs(p.x - c.x) + Math.abs(p.y - c.y);
        if (dist < minDist) {
          minDist = dist;
          bestMove = p;
        }
      }
    }
  }

  return bestMove;
}

// 原有评分计算（不变）
function getPointScore(
  chess_coord: Coord[],
  x: number,
  y: number,
  targetColor: boolean
): number {
  let score = 0;
  const directions: [number, number][] = [[1, 0], [0, 1], [1, 1], [1, -1]];

  for (const direction of directions) {
    const dx = direction[0];
    const dy = direction[1];
    let count = 1;
    let open = 0;

    for (let dir = -1; dir <= 1; dir += 2) {
      if (dir === 0) continue;
      for (let i = 1; i < 5; i++) {
        const curX = x + i * dx * dir;
        const curY = y + i * dy * dir;

        if (curX < 0 || curX >= 15 || curY < 0 || curY >= 15) break;

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