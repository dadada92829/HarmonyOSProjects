// entry/src/main/ets/utils/AIEasy.ets
export interface Coord {
  x: number;
  y: number;
  color: boolean;
}

interface ThreatResult {
  hasThreat: boolean;
  coord?: Coord;
}

/**
 * 强化关键棋型堵截：优先堵 活四 → 冲四（不堵就输的局面）
 * 活四：4连子 + 两端空；冲四：4连子 + 一端空、一端堵
 */
export function checkPlayerThreat(
  chess_coord: Coord[],
  playerColor: boolean,
  isCoordEmpty: (x: number, y: number) => boolean
): ThreatResult {
  const directions: [number, number][] = [[1, 0], [0, 1], [1, 1], [-1, 1]];

  for (const coord of chess_coord) {
    if (coord.color !== playerColor) continue;

    for (let i = 0; i < directions.length; i++) {
      const dx = directions[i][0];
      const dy = directions[i][1];
      let consecutive = 1; // 当前连子数（包含自身）
      let leftStatus = 'empty'; // leftStatus: empty=空, blocked=被堵, out=出界
      let rightStatus = 'empty'; // rightStatus: 同上
      let leftX = -1, leftY = -1; // 左端空位坐标
      let rightX = -1, rightY = -1; // 右端空位坐标

      // 1. 向左/上遍历（统计连子数 + 左端状态）
      let nx = coord.x - dx;
      let ny = coord.y - dy;
      while (nx >= 0 && nx < 15 && ny >= 0 && ny < 15) { // 15×15棋盘
        const found = chess_coord.find(c => c.x === nx && c.y === ny && c.color === playerColor);
        if (found) {
          consecutive++;
          nx -= dx;
          ny -= dy;
        } else {
          // 左端是空位或被对方棋子堵了
          leftStatus = isCoordEmpty(nx, ny) ? 'empty' : 'blocked';
          leftX = nx;
          leftY = ny;
          break;
        }
      }
      // 遍历到棋盘外，标记为出界
      if (nx < 0 || nx >= 15 || ny < 0 || ny >= 15) {
        leftStatus = 'out';
      }

      // 2. 向右/下遍历（统计连子数 + 右端状态）
      nx = coord.x + dx;
      ny = coord.y + dy;
      while (nx >= 0 && nx < 15 && ny >= 0 && ny < 15) { // 15×15棋盘
        const found = chess_coord.find(c => c.x === nx && c.y === ny && c.color === playerColor);
        if (found) {
          consecutive++;
          nx += dx;
          ny += dy;
        } else {
          // 右端是空位或被对方棋子堵了
          rightStatus = isCoordEmpty(nx, ny) ? 'empty' : 'blocked';
          rightX = nx;
          rightY = ny;
          break;
        }
      }
      // 遍历到棋盘外，标记为出界
      if (nx < 0 || nx >= 15 || ny < 0 || ny >= 15) {
        rightStatus = 'out';
      }

      // 3. 优先检测「活四」（4连子 + 两端空 → 不堵必输）
      if (consecutive === 4 && leftStatus === 'empty' && rightStatus === 'empty') {
        // 随便堵一端即可（优先堵左端）
        return { hasThreat: true, coord: { x: leftX, y: leftY, color: false } };
      }

      // 4. 再检测「冲四」（4连子 + 一端空、一端堵/出界 → 不堵必输）
      if (consecutive === 4) {
        // 左端是空位，堵左端
        if (leftStatus === 'empty') {
          return { hasThreat: true, coord: { x: leftX, y: leftY, color: false } };
        }
        // 右端是空位，堵右端
        if (rightStatus === 'empty') {
          return { hasThreat: true, coord: { x: rightX, y: rightY, color: false } };
        }
      }
    }
  }

  // 无活四/冲四威胁，返回无威胁
  return { hasThreat: false };
}

/**
 * 优化落子逻辑：先堵活四/冲四 → 再堵活三 → 最后随机连子
 */
export function aiMoveEasy(
  chess_coord: Coord[],
  aiColor: boolean,
  isGameOver: boolean,
  drawAIChess: (x: number, y: number) => void,
  isCoordEmpty: (x: number, y: number) => boolean,
  checkThreat: (
    chess_coord: Coord[],
    playerColor: boolean,
    isCoordEmpty: (x: number, y: number) => boolean
  ) => ThreatResult
) {
  if (isGameOver) return;

  const playerColor = !aiColor;
  const directions: [number, number][] = [[1, 0], [0, 1], [1, 1], [-1, 1]];

  // 第一步：最高优先级 → 堵活四/冲四（不堵就输）
  const deadlyThreat = checkThreat(chess_coord, playerColor, isCoordEmpty);
  if (deadlyThreat.hasThreat && deadlyThreat.coord) {
    if (isCoordEmpty(deadlyThreat.coord.x, deadlyThreat.coord.y)) {
      drawAIChess(deadlyThreat.coord.x, deadlyThreat.coord.y);
    }
    return;
  }

  // 第二步：次优先级 → 堵活三（3连子 + 两端空 → 下一步可能活四）
  const live3Threat = checkLive3Threat(chess_coord, playerColor, isCoordEmpty);
  if (live3Threat.hasThreat && live3Threat.coord) {
    if (isCoordEmpty(live3Threat.coord.x, live3Threat.coord.y)) {
      drawAIChess(live3Threat.coord.x, live3Threat.coord.y);
    }
    return;
  }

  // 第三步：无威胁时，优先选自己连子的相邻位置（不随机乱下）
  const potentialCoords: Coord[] = [];
  const aiCoords = chess_coord.filter(c => c.color === aiColor);
  for (const coord of aiCoords) {
    for (let i = 0; i < directions.length; i++) {
      const dx = directions[i][0];
      const dy = directions[i][1];
      // 检查相邻的8个方向（上下左右+对角线）
      for (let step = -1; step <= 1; step += 2) {
        const nx = coord.x + dx * step;
        const ny = coord.y + dy * step;
        if (nx >= 0 && nx < 15 && ny >= 0 && ny < 15 && isCoordEmpty(nx, ny)) {
          potentialCoords.push({ x: nx, y: ny, color: aiColor });
        }
      }
    }
  }

  // 优先选连子潜力位置，否则随机落子
  if (potentialCoords.length > 0) {
    const randomIndex = Math.floor(Math.random() * potentialCoords.length);
    drawAIChess(potentialCoords[randomIndex].x, potentialCoords[randomIndex].y);
  } else {
    const emptyCoords: Coord[] = [];
    for (let x = 0; x < 15; x++) {
      for (let y = 0; y < 15; y++) {
        if (isCoordEmpty(x, y)) {
          emptyCoords.push({ x, y, color: aiColor });
        }
      }
    }
    if (emptyCoords.length > 0) {
      const randomIndex = Math.floor(Math.random() * emptyCoords.length);
      drawAIChess(emptyCoords[randomIndex].x, emptyCoords[randomIndex].y);
    } else {
      drawAIChess(-1, -1); // 平局
    }
  }
}

/**
 * 辅助函数：检测活三威胁（3连子 + 两端空）
 */
function checkLive3Threat(
  chess_coord: Coord[],
  playerColor: boolean,
  isCoordEmpty: (x: number, y: number) => boolean
): ThreatResult {
  const directions: [number, number][] = [[1, 0], [0, 1], [1, 1], [-1, 1]];

  for (const coord of chess_coord) {
    if (coord.color !== playerColor) continue;

    for (let i = 0; i < directions.length; i++) {
      const dx = directions[i][0];
      const dy = directions[i][1];
      let consecutive = 1;
      let leftEmpty = false;
      let rightEmpty = false;
      let leftX = -1, leftY = -1;

      // 向左/上遍历
      let nx = coord.x - dx;
      let ny = coord.y - dy;
      while (nx >= 0 && nx < 15 && ny >= 0 && ny < 15) {
        const found = chess_coord.find(c => c.x === nx && c.y === ny && c.color === playerColor);
        if (found) {
          consecutive++;
          nx -= dx;
          ny -= dy;
        } else {
          leftEmpty = isCoordEmpty(nx, ny);
          leftX = nx;
          leftY = ny;
          break;
        }
      }
      if (nx < 0 || nx >= 15 || ny < 0 || ny >= 15) leftEmpty = false;

      // 向右/下遍历
      nx = coord.x + dx;
      ny = coord.y + dy;
      while (nx >= 0 && nx < 15 && ny >= 0 && ny < 15) {
        const found = chess_coord.find(c => c.x === nx && c.y === ny && c.color === playerColor);
        if (found) {
          consecutive++;
          nx += dx;
          ny += dy;
        } else {
          rightEmpty = isCoordEmpty(nx, ny);
          break;
        }
      }
      if (nx < 0 || nx >= 15 || ny < 0 || ny >= 15) rightEmpty = false;

      // 活三：3连子 + 两端空
      if (consecutive === 3 && leftEmpty && rightEmpty) {
        return { hasThreat: true, coord: { x: leftX, y: leftY, color: false } };
      }
    }
  }
  return { hasThreat: false };
}