import RdbUtils from './RdbUtils';
import { RecordType } from '../../model/RecordType';

export class MockDataGenerator {

  // 支出分类
  private static expenseCategories = ['餐饮', '交通', '购物', '娱乐', '医疗', '教育', '居住', '其他'];
  // 收入分类
  private static incomeCategories = ['工资', '兼职', '理财', '礼金'];

  // 备注库
  private static foodRemarks = ['麦当劳', '沙县小吃', '火锅', '奶茶', '超市买菜', '工作餐'];
  private static trafficRemarks = ['地铁', '打车', '公交充值', '加油'];
  private static shopRemarks = ['买衣服', '日用品', '电子产品', '网购'];

  /**
   * 核心方法：生成模拟数据
   */
  static async generateData(count: number) {
    console.info('[MockData] 开始生成模拟数据...');

    const startTime = new Date('2023-01-01').getTime();
    const endTime = new Date('2025-12-31').getTime();

    for (let i = 0; i < count; i++) {
      // 随机生成时间
      const randomDate = new Date(startTime + Math.random() * (endTime - startTime));

      // 随机决定是收入还是支出 (80%是支出，20%是收入)
      const isExpense = Math.random() > 0.2;

      let type: RecordType;
      let category: string;
      let amount: number;
      let remark: string;

      if (isExpense) {
        type = RecordType.EXPENSE;
        // 【修复】将 this 改为类名 MockDataGenerator
        category = MockDataGenerator.getRandomItem(MockDataGenerator.expenseCategories);

        // 随机金额 10 - 500 元
        amount = parseFloat((Math.random() * 490 + 10).toFixed(2));

        // 【修复】将 this 改为类名 MockDataGenerator
        if (category === '餐饮') remark = MockDataGenerator.getRandomItem(MockDataGenerator.foodRemarks);
        else if (category === '交通') remark = MockDataGenerator.getRandomItem(MockDataGenerator.trafficRemarks);
        else if (category === '购物') remark = MockDataGenerator.getRandomItem(MockDataGenerator.shopRemarks);
        else remark = category + '消费';

      } else {
        type = RecordType.INCOME;
        // 【修复】将 this 改为类名 MockDataGenerator
        category = MockDataGenerator.getRandomItem(MockDataGenerator.incomeCategories);
        // 收入通常比较大 2000 - 10000
        amount = parseFloat((Math.random() * 8000 + 2000).toFixed(2));
        remark = category + '入账';
      }

      // 写入数据库
      await RdbUtils.insert({
        id: 0,
        amount: amount,
        type: type,
        category: category,
        remark: remark,
        date: randomDate.getTime()
      });
    }

    console.info('[MockData] 数据生成完毕！');
  }

  private static getRandomItem(arr: string[]): string {
    return arr[Math.floor(Math.random() * arr.length)];
  }
}