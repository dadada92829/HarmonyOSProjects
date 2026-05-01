export type NodeType = 'file' | 'folder';

export type SortOption =
  'name_asc' | 'name_desc' |
  'edit_new' | 'edit_old' |
  'create_new' | 'create_old';

export class FileNode {
  id: string;
  type: NodeType;
  title: string;
  content: string;
  parentId: string;
  updatedAt: number;
  createdAt: number;
  isFavorite: boolean;
  isExpanded: boolean;
  children: FileNode[];
  level: number;

  // [新增] 存储批注数据的 JSON 字符串
  comments: string;

  constructor(id: string, type: NodeType, title: string, content: string = '', parentId: string = 'root', level: number = 0) {
    this.id = id;
    this.type = type;
    this.title = title;
    this.content = content;
    this.parentId = parentId;
    this.updatedAt = new Date().getTime();
    this.createdAt = new Date().getTime();
    this.isFavorite = false;
    this.isExpanded = true;
    this.children = [];
    this.level = level;

    // [新增] 初始化为空
    this.comments = '';
  }

  addChild(node: FileNode): void {
    node.level = this.level + 1;
    node.parentId = this.id;
    this.children.push(node);
  }
}