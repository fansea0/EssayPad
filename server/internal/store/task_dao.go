package store

import (
	"database/sql"
	"errors"
	"fmt"
	"time"

	"essaypad/internal/model"
)

var ErrTaskNotFound = errors.New("task not found")

type TaskDAO struct {
	db *sql.DB
}

func NewTaskDAO(db *sql.DB) *TaskDAO {
	return &TaskDAO{db: db}
}

const taskColumns = "id, title, description, progress, priority, status, due_at, created_at, updated_at, completed_at"

func scanTask(row interface {
	Scan(...interface{}) error
}) (*model.Task, error) {
	var t model.Task
	if err := row.Scan(&t.ID, &t.Title, &t.Description, &t.Progress, &t.Priority, &t.Status,
		&t.DueAt, &t.CreatedAt, &t.UpdatedAt, &t.CompletedAt); err != nil {
		return nil, err
	}
	return &t, nil
}

func (d *TaskDAO) Create(t *model.Task) (int64, error) {
	if t.CreatedAt == 0 {
		t.CreatedAt = time.Now().Unix()
	}
	if t.UpdatedAt == 0 {
		t.UpdatedAt = t.CreatedAt
	}
	if t.DueAt == 0 {
		t.DueAt = todayStartUnix()
	}
	res, err := d.db.Exec(
		`INSERT INTO tasks (title, description, progress, priority, status, due_at, created_at, updated_at, completed_at)
		 VALUES (?,?,?,?,?,?,?,?,?)`,
		t.Title, t.Description, t.Progress, t.Priority, t.Status,
		t.DueAt, t.CreatedAt, t.UpdatedAt, t.CompletedAt,
	)
	if err != nil {
		return 0, err
	}
	return res.LastInsertId()
}

func (d *TaskDAO) Get(id int64) (*model.Task, error) {
	row := d.db.QueryRow(
		`SELECT `+taskColumns+` FROM tasks WHERE id=? AND is_deleted=0`, id)
	t, err := scanTask(row)
	if errors.Is(err, sql.ErrNoRows) {
		return nil, ErrTaskNotFound
	}
	return t, err
}

func (d *TaskDAO) Update(id int64, fields map[string]interface{}) (*model.Task, error) {
	if len(fields) == 0 {
		return d.Get(id)
	}
	set := ""
	args := []interface{}{}
	for k, v := range fields {
		if set != "" {
			set += ","
		}
		set += k + "=?"
		args = append(args, v)
	}
	set += ",updated_at=?"
	args = append(args, time.Now().Unix())
	args = append(args, id)

	res, err := d.db.Exec(`UPDATE tasks SET `+set+` WHERE id=? AND is_deleted=0`, args...)
	if err != nil {
		return nil, err
	}
	n, _ := res.RowsAffected()
	if n == 0 {
		return nil, ErrTaskNotFound
	}
	return d.Get(id)
}

func (d *TaskDAO) SoftDelete(id int64) error {
	res, err := d.db.Exec(`UPDATE tasks SET is_deleted=1, updated_at=? WHERE id=?`,
		time.Now().Unix(), id)
	if err != nil {
		return err
	}
	n, _ := res.RowsAffected()
	if n == 0 {
		return ErrTaskNotFound
	}
	return nil
}

func (d *TaskDAO) ListByGroup(group string) ([]*model.Task, error) {
	now := time.Now()
	loc := now.Location()
	today := time.Date(now.Year(), now.Month(), now.Day(), 0, 0, 0, 0, loc)
	todayStart := today.Unix()

	var query string
	var args []interface{}

	switch group {
	case "today":
		query = `SELECT ` + taskColumns + ` FROM tasks WHERE is_deleted=0 AND due_at=? ORDER BY priority DESC, id ASC`
		args = []interface{}{todayStart}
	case "yesterday":
		query = `SELECT ` + taskColumns + ` FROM tasks WHERE is_deleted=0 AND due_at=? ORDER BY priority DESC, id ASC`
		args = []interface{}{todayStart - 86400}
	case "week":
		weekday := int(now.Weekday())
		if weekday == 0 {
			weekday = 7
		}
		daysFromMonday := weekday - 1
		mondayStart := todayStart - int64(daysFromMonday)*86400
		query = `SELECT ` + taskColumns + ` FROM tasks WHERE is_deleted=0 AND due_at>=? ORDER BY due_at DESC, priority DESC, id ASC`
		args = []interface{}{mondayStart}
	case "long_term":
		query = `SELECT ` + taskColumns + ` FROM tasks WHERE is_deleted=0 AND priority=? AND status=? ORDER BY updated_at DESC, id ASC`
		args = []interface{}{model.TaskPriorityImportant, model.TaskStatusActive}
	default: // all
		query = `SELECT ` + taskColumns + ` FROM tasks WHERE is_deleted=0 ORDER BY due_at DESC, priority DESC, id ASC`
	}

	rows, err := d.db.Query(query, args...)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	var list []*model.Task
	for rows.Next() {
		t, err := scanTask(rows)
		if err != nil {
			return nil, fmt.Errorf("scan: %w", err)
		}
		list = append(list, t)
	}
	return list, rows.Err()
}

func (d *TaskDAO) ListForWeekly(days int) (active, completed, overdue []*model.Task, err error) {
	now := time.Now()
	loc := now.Location()
	todayStart := time.Date(now.Year(), now.Month(), now.Day(), 0, 0, 0, 0, loc).Unix()
	nowUnix := now.Unix()
	since := nowUnix - int64(days)*86400

	rows, err := d.db.Query(
		`SELECT `+taskColumns+` FROM tasks WHERE is_deleted=0 AND status=0 AND due_at>=? AND due_at<=? ORDER BY priority DESC, id ASC`,
		since, todayStart)
	if err != nil {
		return nil, nil, nil, err
	}
	for rows.Next() {
		t, e := scanTask(rows)
		if e != nil {
			rows.Close()
			return nil, nil, nil, e
		}
		active = append(active, t)
	}
	rows.Close()

	rows, err = d.db.Query(
		`SELECT `+taskColumns+` FROM tasks WHERE is_deleted=0 AND status=1 AND completed_at>=? AND completed_at<=? ORDER BY completed_at DESC`,
		since, nowUnix)
	if err != nil {
		return nil, nil, nil, err
	}
	for rows.Next() {
		t, e := scanTask(rows)
		if e != nil {
			rows.Close()
			return nil, nil, nil, e
		}
		completed = append(completed, t)
	}
	rows.Close()

	rows, err = d.db.Query(
		`SELECT `+taskColumns+` FROM tasks WHERE is_deleted=0 AND status=0 AND due_at<? ORDER BY due_at ASC`,
		todayStart)
	if err != nil {
		return nil, nil, nil, err
	}
	for rows.Next() {
		t, e := scanTask(rows)
		if e != nil {
			rows.Close()
			return nil, nil, nil, e
		}
		overdue = append(overdue, t)
	}
	rows.Close()

	return active, completed, overdue, nil
}

func todayStartUnix() int64 {
	now := time.Now()
	return time.Date(now.Year(), now.Month(), now.Day(), 0, 0, 0, 0, now.Location()).Unix()
}
