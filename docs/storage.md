# 存储设计

## 分类枚举
| code | name | 含义 |
|------|------|------|
| 1 | bug | 缺陷记录 |
| 2 | requirement | 需求 |
| 3 | idea | 想法/点子 |

## 表: notes (SQLite, 后期切 MySQL 字段不变)
| 字段 | 类型 | 默认 | 备注 |
|------|------|------|------|
| id | INTEGER PRIMARY KEY AUTOINCREMENT | | 自增 ID |
| category | TINYINT | 0 | 1=bug,2=requirement,3=idea |
| title | VARCHAR(200) | '' | 标题 |
| content | TEXT | '' | Markdown 内容 |
| created_at | BIGINT | 0 | 创建时间戳(秒) |
| updated_at | BIGINT | 0 | 更新时间戳(秒) |
| is_deleted | TINYINT | 0 | 0=未删,1=已删(软删) |

索引:
- `idx_notes_category_updated (category, updated_at DESC)` — 列表按分类+时间
- `idx_notes_updated (updated_at DESC)` — 周报取近 7 天

## 切换 MySQL
- 把驱动换成 `github.com/go-sql-driver/mysql`
- 把 `INTEGER PRIMARY KEY AUTOINCREMENT` 改为 `BIGINT NOT NULL AUTO_INCREMENT`
- `TEXT` 保持不变
- DAO 层 SQL 兼容