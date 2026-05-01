// ets/common/utils/RdbUtils.ets
import { relationalStore } from '@kit.ArkData';
import { common } from '@kit.AbilityKit';
import { RecordItem, RecordType } from '../../model/RecordType';

class RdbUtils {
  private rdbStore: relationalStore.RdbStore | null = null;
  private tableName: string = 'record';

  // SQL建表语句
  private sqlCreateTable: string = `CREATE TABLE IF NOT EXISTS record (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    amount REAL,
    type INTEGER,
    category TEXT,
    remark TEXT,
    date INTEGER
  )`;

  /**
   * 初始化数据库 (在EntryAbility中调用)
   */
  async initDb(context: common.UIAbilityContext): Promise<void> {
    const config: relationalStore.StoreConfig = {
      name: 'EasyBook.db',
      securityLevel: relationalStore.SecurityLevel.S1
    };

    try {
      this.rdbStore = await relationalStore.getRdbStore(context, config);
      if (this.rdbStore) {
        await this.rdbStore.executeSql(this.sqlCreateTable);
        console.info('[RdbUtils] 数据库初始化成功，表已创建');
      }
    } catch (err) {
      console.error(`[RdbUtils] 初始化失败: ${JSON.stringify(err)}`);
    }
  }

  /**
   * 插入一条记录
   */
  async insert(item: RecordItem): Promise<number> {
    if (!this.rdbStore) {
      console.error('[RdbUtils] rdbStore 未初始化');
      return -1;
    }

    const valueBucket: relationalStore.ValuesBucket = {
      amount: item.amount,
      type: item.type,
      category: item.category,
      remark: item.remark || '',
      date: item.date
    };

    try {
      const rowId = await this.rdbStore.insert(this.tableName, valueBucket);
      console.info(`[RdbUtils] 插入成功, rowId: ${rowId}`);
      return rowId;
    } catch (err) {
      console.error(`[RdbUtils] 插入失败: ${JSON.stringify(err)}`);
      return -1;
    }
  }

  /**
   * 删除一条记录
   */
  async delete(id: number): Promise<number> {
    if (!this.rdbStore) return -1;

    const predicates = new relationalStore.RdbPredicates(this.tableName);
    predicates.equalTo('id', id);

    return await this.rdbStore.delete(predicates);
  }

  /**
   * 查询所有记录 (用于 StatsView 统计 或 兜底)
   */
  async queryAll(): Promise<RecordItem[]> {
    if (!this.rdbStore) return [];

    const predicates = new relationalStore.RdbPredicates(this.tableName);
    predicates.orderByDesc('date'); // 按时间倒序

    return await this.executePredicates(predicates);
  }

  /**
   * 简单模糊搜索 (旧版搜索保留，防止报错)
   */
  async search(keyword: string): Promise<RecordItem[]> {
    if (!this.rdbStore) return [];

    const predicates = new relationalStore.RdbPredicates(this.tableName);
    predicates.contains('remark', keyword)
      .or()
      .contains('category', keyword)
      .orderByDesc('date');

    return await this.executePredicates(predicates);
  }

  /**
   * 【核心】高级组合查询 (用于 SearchPage 和 新版 HomeView)
   * @param start 开始时间戳 (0表示不限)
   * @param end 结束时间戳 (0表示不限)
   * @param type 类型: -1全部, 0支出, 1收入
   * @param category 分类名: 空字符串表示全部
   * @param minAmount 最小金额: 0表示不限
   * @param maxAmount 最大金额: 0表示不限
   * @param keyword 搜索关键字: 匹配备注
   */
  async advancedQuery(start: number, end: number, type: number, category: string, minAmount: number, maxAmount: number, keyword: string): Promise<RecordItem[]> {
    if (!this.rdbStore) return [];

    const predicates = new relationalStore.RdbPredicates(this.tableName);

    // 1. 日期范围
    if (start > 0 && end > 0) {
      predicates.between('date', start, end);
    }

    // 2. 类型 (-1代表全部)
    if (type !== -1) {
      predicates.equalTo('type', type);
    }

    // 3. 分类
    if (category && category !== '') {
      predicates.equalTo('category', category);
    }

    // 4. 金额区间
    if (maxAmount > 0) {
      // 如果设置了最大金额，才生效。最小金额默认为0
      predicates.greaterThanOrEqualTo('amount', minAmount);
      predicates.lessThanOrEqualTo('amount', maxAmount);
    }

    // 5. 关键字 (模糊搜索备注)
    if (keyword && keyword.trim() !== '') {
      predicates.contains('remark', keyword);
    }

    // 按时间倒序排列
    predicates.orderByDesc('date');

    return await this.executePredicates(predicates);
  }

  /**
   * 私有辅助方法：执行查询并格式化结果
   */
  private async executePredicates(predicates: relationalStore.RdbPredicates): Promise<RecordItem[]> {
    const resultList: RecordItem[] = [];
    if (!this.rdbStore) return resultList;

    try {
      const resultSet = await this.rdbStore.query(predicates);
      while (resultSet.goToNextRow()) {
        resultList.push({
          id: resultSet.getDouble(resultSet.getColumnIndex('id')),
          amount: resultSet.getDouble(resultSet.getColumnIndex('amount')),
          type: resultSet.getDouble(resultSet.getColumnIndex('type')) as RecordType,
          category: resultSet.getString(resultSet.getColumnIndex('category')),
          remark: resultSet.getString(resultSet.getColumnIndex('remark')),
          date: resultSet.getDouble(resultSet.getColumnIndex('date'))
        });
      }
      resultSet.close();
    } catch (err) {
      console.error(`[RdbUtils] 查询执行失败: ${JSON.stringify(err)}`);
    }
    return resultList;
  }
}

export default new RdbUtils();