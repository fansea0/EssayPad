package store

import (
	"database/sql"
	"errors"
	"fmt"
	"strings"
	"time"

	"essaypad/internal/model"
)

var ErrNotFound = errors.New("note not found")

type NoteDAO struct {
	db *sql.DB
}

func NewNoteDAO(db *sql.DB) *NoteDAO {
	return &NoteDAO{db: db}
}

const noteColumns = "id, category, title, content, created_at, updated_at, task_id"

func scanNote(row interface {
	Scan(...interface{}) error
}) (*model.Note, error) {
	var n model.Note
	if err := row.Scan(&n.ID, &n.Category, &n.Title, &n.Content, &n.CreatedAt, &n.UpdatedAt, &n.TaskID); err != nil {
		return nil, err
	}
	return &n, nil
}

func (d *NoteDAO) Create(n *model.Note) (int64, error) {
	if n.CreatedAt == 0 {
		n.CreatedAt = time.Now().Unix()
	}
	if n.UpdatedAt == 0 {
		n.UpdatedAt = n.CreatedAt
	}
	res, err := d.db.Exec(
		`INSERT INTO notes (category, title, content, created_at, updated_at, task_id) VALUES (?,?,?,?,?,?)`,
		n.Category, n.Title, n.Content, n.CreatedAt, n.UpdatedAt, n.TaskID,
	)
	if err != nil {
		return 0, err
	}
	return res.LastInsertId()
}

func (d *NoteDAO) Get(id int64) (*model.Note, error) {
	row := d.db.QueryRow(
		`SELECT `+noteColumns+` FROM notes WHERE id=? AND is_deleted=0`,
		id,
	)
	n, err := scanNote(row)
	if errors.Is(err, sql.ErrNoRows) {
		return nil, ErrNotFound
	}
	return n, err
}

func (d *NoteDAO) List(category int, page, pageSize int) ([]*model.Note, int, error) {
	if page < 1 {
		page = 1
	}
	if pageSize < 1 || pageSize > 200 {
		pageSize = 20
	}
	offset := (page - 1) * pageSize

	var total int
	if err := d.db.QueryRow(`SELECT COUNT(*) FROM notes WHERE is_deleted=0 AND category=?`, category).Scan(&total); err != nil {
		return nil, 0, err
	}

	rows, err := d.db.Query(
		`SELECT `+noteColumns+`
		 FROM notes WHERE is_deleted=0 AND category=?
		 ORDER BY updated_at DESC LIMIT ? OFFSET ?`,
		category, pageSize, offset,
	)
	if err != nil {
		return nil, 0, err
	}
	defer rows.Close()

	var list []*model.Note
	for rows.Next() {
		n, err := scanNote(rows)
		if err != nil {
			return nil, 0, err
		}
		list = append(list, n)
	}
	return list, total, rows.Err()
}

func (d *NoteDAO) Update(id int64, title, content string, category int) error {
	res, err := d.db.Exec(
		`UPDATE notes SET title=?, content=?, category=?, updated_at=? WHERE id=? AND is_deleted=0`,
		title, content, category, time.Now().Unix(), id,
	)
	if err != nil {
		return err
	}
	n, _ := res.RowsAffected()
	if n == 0 {
		return ErrNotFound
	}
	return nil
}

// UpdateTask 设置 / 清空笔记的 task_id 关联
func (d *NoteDAO) UpdateTask(id int64, taskID int64) error {
	res, err := d.db.Exec(
		`UPDATE notes SET task_id=?, updated_at=? WHERE id=? AND is_deleted=0`,
		taskID, time.Now().Unix(), id,
	)
	if err != nil {
		return err
	}
	n, _ := res.RowsAffected()
	if n == 0 {
		return ErrNotFound
	}
	return nil
}

func (d *NoteDAO) SoftDelete(id int64) error {
	res, err := d.db.Exec(`UPDATE notes SET is_deleted=1, updated_at=? WHERE id=?`, time.Now().Unix(), id)
	if err != nil {
		return err
	}
	n, _ := res.RowsAffected()
	if n == 0 {
		return ErrNotFound
	}
	return nil
}

func (d *NoteDAO) TrimCategoryToLimit(category int, keep int) (int64, error) {
	rows, err := d.db.Query(
		`SELECT id FROM notes WHERE is_deleted=0 AND category=?
		 ORDER BY updated_at DESC LIMIT -1 OFFSET ?`,
		category, keep,
	)
	if err != nil {
		return 0, err
	}
	defer rows.Close()
	var ids []int64
	for rows.Next() {
		var id int64
		if err := rows.Scan(&id); err != nil {
			return 0, err
		}
		ids = append(ids, id)
	}
	if err := rows.Err(); err != nil {
		return 0, err
	}
	if len(ids) == 0 {
		return 0, nil
	}
	for _, id := range ids {
		if _, err := d.db.Exec(`DELETE FROM notes WHERE id=?`, id); err != nil {
			return 0, err
		}
	}
	return int64(len(ids)), nil
}

func (d *NoteDAO) ListInRange(days int) ([]*model.Note, error) {
	since := time.Now().AddDate(0, 0, -days).Unix()
	rows, err := d.db.Query(
		`SELECT `+noteColumns+`
		 FROM notes WHERE is_deleted=0 AND updated_at >= ?
		 ORDER BY updated_at DESC`,
		since,
	)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	var list []*model.Note
	for rows.Next() {
		n, err := scanNote(rows)
		if err != nil {
			return nil, fmt.Errorf("scan: %w", err)
		}
		list = append(list, n)
	}
	return list, rows.Err()
}

// ListInRangeByMode 按日历窗口查(today/yesterday/week),排除草稿
func (d *NoteDAO) ListInRangeByMode(mode string) ([]*model.Note, error) {
	now := time.Now()
	loc := now.Location()
	todayStart := time.Date(now.Year(), now.Month(), now.Day(), 0, 0, 0, 0, loc)

	var start, end time.Time
	switch mode {
	case "today":
		start = todayStart
		end = todayStart.Add(24 * time.Hour)
	case "yesterday":
		start = todayStart.AddDate(0, 0, -1)
		end = todayStart
	case "week":
		// 本周 = 今天 0 点往前 6 天 ~ 今天 24 点(共 7 天)
		start = todayStart.AddDate(0, 0, -6)
		end = todayStart.Add(24 * time.Hour)
	default:
		return d.ListInRange(7)
	}

	rows, err := d.db.Query(
		`SELECT `+noteColumns+`
		 FROM notes WHERE is_deleted=0 AND category != ?
		   AND updated_at >= ? AND updated_at < ?
		 ORDER BY updated_at DESC`,
		model.CategoryDraft,
		start.Unix(), end.Unix(),
	)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	var list []*model.Note
	for rows.Next() {
		n, err := scanNote(rows)
		if err != nil {
			return nil, fmt.Errorf("scan: %w", err)
		}
		list = append(list, n)
	}
	return list, rows.Err()
}

// ListByTask 列出某个任务关联的所有笔记
func (d *NoteDAO) ListByTask(taskID int64) ([]*model.Note, error) {
	rows, err := d.db.Query(
		`SELECT `+noteColumns+`
		 FROM notes WHERE is_deleted=0 AND task_id=?
		 ORDER BY updated_at DESC`,
		taskID,
	)
	if err != nil {
		return nil, err
	}
	defer rows.Close()
	var list []*model.Note
	for rows.Next() {
		n, err := scanNote(rows)
		if err != nil {
			return nil, err
		}
		list = append(list, n)
	}
	return list, rows.Err()
}

// CountByTaskIDs 一次性批量查多个 task 的关联笔记数
func (d *NoteDAO) CountByTaskIDs(taskIDs []int64) (map[int64]int, error) {
	out := make(map[int64]int, len(taskIDs))
	if len(taskIDs) == 0 {
		return out, nil
	}
	placeholders := strings.Repeat("?,", len(taskIDs))
	placeholders = placeholders[:len(placeholders)-1]
	args := make([]interface{}, len(taskIDs))
	for i, id := range taskIDs {
		args[i] = id
	}
	rows, err := d.db.Query(
		`SELECT task_id, COUNT(*) FROM notes
		 WHERE is_deleted=0 AND task_id IN (`+placeholders+`)
		 GROUP BY task_id`,
		args...,
	)
	if err != nil {
		return nil, err
	}
	defer rows.Close()
	for rows.Next() {
		var id int64
		var c int
		if err := rows.Scan(&id, &c); err != nil {
			return nil, err
		}
		out[id] = c
	}
	return out, rows.Err()
}