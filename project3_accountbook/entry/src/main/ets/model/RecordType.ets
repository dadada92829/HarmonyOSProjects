// ets/model/RecordType.ets

// 定义收支类型枚举
export enum RecordType {
  EXPENSE = 0, // 支出
  INCOME = 1   // 收入
}

// 定义每一笔账单的接口
export interface RecordItem {
  id: number;          // 数据库 ID
  amount: number;      // 金额
  type: RecordType;    // 类型：收入/支出
  category: string;    // 分类名：餐饮、交通、工资等
  remark?: string;     // 备注 (可选)
  date: number;        // 时间戳
}

// 定义首页统计数据的接口
export interface MonthlyStats {
  totalIncome: number;
  totalExpense: number;
  balance: number;
}

// 【新增】用于统计页面的分类汇总结构
export interface CategoryStat {
  category: string; // 分类名
  amount: number;   // 总金额
  percentage: number; // 百分比 (0~1)
  color: string;    // 饼图对应的颜色
}