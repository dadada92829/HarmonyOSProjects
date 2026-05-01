import { relationalStore } from '@kit.ArkData';
import { common } from '@kit.AbilityKit';
import { FileNode, NodeType } from '../model/NoteModel';

interface MockComment {
  id: string;
  rangeStart: number;
  rangeEnd: number;
  content: string;
  colorStr: string;
  styleType: number;
  createTime: number;
}

class DBManager {
  private store: relationalStore.RdbStore | null = null;
  private tableName = 'notes';

  private sqlCreate = `CREATE TABLE IF NOT EXISTS ${this.tableName} (
    id TEXT PRIMARY KEY,
    type TEXT,
    title TEXT,
    content TEXT,
    parentId TEXT,
    updatedAt INTEGER,
    createdAt INTEGER,
    isExpanded INTEGER,
    isFavorite INTEGER,
    comments TEXT
  )`;

  async init(context: common.UIAbilityContext): Promise<void> {
    const config: relationalStore.StoreConfig = {
      name: 'mindflow.db',
      securityLevel: relationalStore.SecurityLevel.S1
    };

    try {
      this.store = await relationalStore.getRdbStore(context, config);
      await this.store.executeSql(this.sqlCreate);

      // 自动修复逻辑 (保留好习惯)
      try {
        await this.store.executeSql(`ALTER TABLE ${this.tableName} ADD COLUMN comments TEXT`);
      } catch (e) {
        // 字段已存在，忽略
      }

      await this.checkAndGenerateMockData();
      console.info('DBManager: Database initialized');
    } catch (err) {
      console.error(`DBManager: Init failed. Code:${err.code}, Msg:${err.message}`);
    }
  }

  private async checkAndGenerateMockData() {
    if (!this.store) return;
    const predicates = new relationalStore.RdbPredicates(this.tableName);
    const resultSet = await this.store.query(predicates);
    const count = resultSet.rowCount;
    resultSet.close();

    // 如果数据库里有数据，就不生成了
    if (count > 0) return;

    console.info('DBManager: Generating Rich Mock Data...');
    const insertNode = async (node: FileNode) => { await this.insert(node); };

    // --- 1. 创建文件夹体系 ---
    const folderCS = new FileNode('folder_cs', 'folder', '计算机专业课', '', 'root');
    folderCS.isExpanded = true;

    const folderLife = new FileNode('folder_life', 'folder', '生活 & 灵感', '', 'root');
    const folderWork = new FileNode('folder_work', 'folder', '实习工作', '', 'root');

    await insertNode(folderCS);
    await insertNode(folderLife);
    await insertNode(folderWork);

    // --- 2. 创建带有批注的复杂笔记 (操作系统) ---
    const osNoteContent = `进程管理是操作系统的核心功能之一。
进程是程序的一次执行过程，是系统进行资源分配和调度的一个独立单位。
引入线程后，线程成为CPU调度的基本单位，而进程依然是资源分配的基本单位。
死锁产生的四个必要条件：互斥条件、请求与保持条件、不剥夺条件、循环等待条件。`;

    const osNote = new FileNode('file_os_1', 'file', '01. 操作系统核心概念', osNoteContent, 'folder_cs');
    osNote.isFavorite = true;

    // 构造预设的批注数据 (模拟 Map 转 JSON)
    const comment1: MockComment = {
      id: 'mock_c1',
      rangeStart: 0,
      rangeEnd: 4,
      content: '重点章节，期末必考！',
      colorStr: '#FF0000',
      styleType: 2,
      createTime: Date.now()
    };

    // 加上 : MockComment
    const comment2: MockComment = {
      id: 'mock_c2',
      rangeStart: 77,
      rangeEnd: 79,
      content: '死锁检测算法需要复习一下银行家算法。',
      colorStr: '#FF8800',
      styleType: 1,
      createTime: Date.now()
    };

    // 序列化批注
    const commentsArray = [
      [`${comment1.rangeStart}_${comment1.rangeEnd}`, comment1],
      [`${comment2.rangeStart}_${comment2.rangeEnd}`, comment2]
    ];
    osNote.comments = JSON.stringify(commentsArray);
    await insertNode(osNote);

    // --- 3. 创建更多测试文件 ---
    await insertNode(new FileNode('file_net_1', 'file', '02. 计算机网络 TCP/IP', '三次握手与四次挥手...\nSYN=1, ACK=0...', 'folder_cs'));

    const poetryNote = new FileNode('file_poetry', 'file', '摘抄：海子的诗', '面朝大海，春暖花开。\n从明天起，做一个幸福的人...', 'folder_life');
    await insertNode(poetryNote);

    const todoNote = new FileNode('file_todo', 'file', '本周待办事项', '1. 完成鸿蒙大作业\n2. 复习英语六级\n3. 这里的文本可以用来测试搜索功能', 'root');
    await insertNode(todoNote);
  }

  async getNoteById(id: string): Promise<FileNode | null> {
    if (!this.store) return null;
    const predicates = new relationalStore.RdbPredicates(this.tableName);
    predicates.equalTo('id', id);
    const resultSet = await this.store.query(predicates);

    if (resultSet.goToNextRow()) {
      const type = resultSet.getString(resultSet.getColumnIndex('type')) as NodeType;
      const title = resultSet.getString(resultSet.getColumnIndex('title'));
      const content = resultSet.getString(resultSet.getColumnIndex('content'));
      const parentId = resultSet.getString(resultSet.getColumnIndex('parentId'));
      const updatedAt = resultSet.getLong(resultSet.getColumnIndex('updatedAt'));
      const createdAt = resultSet.getLong(resultSet.getColumnIndex('createdAt'));
      const isFavorite = resultSet.getLong(resultSet.getColumnIndex('isFavorite')) === 1;

      let comments = '';
      try {
        const commentsIndex = resultSet.getColumnIndex('comments');
        if (commentsIndex !== -1) comments = resultSet.getString(commentsIndex) || '';
      } catch (e) {}

      const node = new FileNode(id, type, title, content, parentId);
      node.updatedAt = updatedAt;
      node.createdAt = createdAt;
      node.isFavorite = isFavorite;
      node.comments = comments;

      resultSet.close();
      return node;
    }
    resultSet.close();
    return null;
  }

  async getFileTree(): Promise<FileNode[]> {
    if (!this.store) return [];
    const predicates = new relationalStore.RdbPredicates(this.tableName);
    predicates.orderByDesc('type').orderByDesc('createdAt');

    const resultSet = await this.store.query(predicates);
    const allNodes: FileNode[] = [];

    while (resultSet.goToNextRow()) {
      const id = resultSet.getString(resultSet.getColumnIndex('id'));
      const type = resultSet.getString(resultSet.getColumnIndex('type')) as NodeType;
      const title = resultSet.getString(resultSet.getColumnIndex('title'));
      const content = resultSet.getString(resultSet.getColumnIndex('content'));
      const parentId = resultSet.getString(resultSet.getColumnIndex('parentId'));
      const updatedAt = resultSet.getLong(resultSet.getColumnIndex('updatedAt'));
      const createdAt = resultSet.getLong(resultSet.getColumnIndex('createdAt'));
      const isExpanded = resultSet.getLong(resultSet.getColumnIndex('isExpanded')) === 1;
      const isFavorite = resultSet.getLong(resultSet.getColumnIndex('isFavorite')) === 1;

      let comments = '';
      try {
        const commentsIndex = resultSet.getColumnIndex('comments');
        if (commentsIndex !== -1) comments = resultSet.getString(commentsIndex) || '';
      } catch (e) {}

      const node = new FileNode(id, type, title, content, parentId);
      node.updatedAt = updatedAt;
      node.createdAt = createdAt;
      node.isExpanded = isExpanded;
      node.isFavorite = isFavorite;
      node.comments = comments;
      allNodes.push(node);
    }
    resultSet.close();

    const nodeMap = new Map<string, FileNode>();
    const rootNodes: FileNode[] = [];
    allNodes.forEach(node => nodeMap.set(node.id, node));
    allNodes.forEach(node => {
      if (node.parentId === 'root') {
        rootNodes.push(node);
      } else {
        const parent = nodeMap.get(node.parentId);
        if (parent) {
          parent.children.push(node);
        } else {
          rootNodes.push(node);
        }
      }
    });
    return rootNodes;
  }

  async getNotePath(nodeId: string): Promise<string> {
    if (!this.store) return '';
    let currentId = nodeId;
    const pathNames: string[] = [];
    for(let i=0; i<20; i++) {
      const predicates = new relationalStore.RdbPredicates(this.tableName);
      predicates.equalTo('id', currentId);
      const resultSet = await this.store.query(predicates, ['title', 'parentId']);
      if (resultSet.goToNextRow()) {
        const parentId = resultSet.getString(1);
        if (currentId !== nodeId) {
          const title = resultSet.getString(0);
          pathNames.unshift(title);
        }
        currentId = parentId;
        resultSet.close();
        if (currentId === 'root') break;
      } else {
        resultSet.close();
        break;
      }
    }
    return pathNames.join(' / ');
  }

  async insert(node: FileNode): Promise<void> {
    if (!this.store) return;
    const valueBucket: relationalStore.ValuesBucket = {
      id: node.id,
      type: node.type,
      title: node.title,
      content: node.content,
      parentId: node.parentId,
      updatedAt: node.updatedAt,
      createdAt: node.createdAt,
      isExpanded: node.isExpanded ? 1 : 0,
      isFavorite: node.isFavorite ? 1 : 0,
      comments: node.comments || ''
    };
    await this.store.insert(this.tableName, valueBucket);
  }

  async update(node: FileNode): Promise<void> {
    if (!this.store) return;
    const valueBucket: relationalStore.ValuesBucket = {
      title: node.title,
      content: node.content,
      parentId: node.parentId,
      updatedAt: new Date().getTime(),
      isExpanded: node.isExpanded ? 1 : 0,
      isFavorite: node.isFavorite ? 1 : 0,
      comments: node.comments || ''
    };
    const predicates = new relationalStore.RdbPredicates(this.tableName);
    predicates.equalTo('id', node.id);
    await this.store.update(valueBucket, predicates);
  }

  async delete(nodeId: string): Promise<void> {
    if (!this.store) return;
    const predicates = new relationalStore.RdbPredicates(this.tableName);
    predicates.equalTo('id', nodeId);
    await this.store.delete(predicates);
  }
}

export default new DBManager();