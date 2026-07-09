package store

import (
	"database/sql"
	"errors"
	"fmt"
	"strings"
	"time"

	"essaypad/internal/model"
)

var ErrPomodoroNotFound = errors.New("pomodoro session not found")

type PomodoroDAO struct {
	db *sql.DB
}

func NewPomodoroDAO(db *sql.DB) *PomodoroDAO {
	return &PomodoroDAO{db: db}
}

const pomodoroColumns = "id, task_id, planned_minutes, actual_minutes, status, started_at, ended_at, note"

func scanPomodoro(row interface {
	Scan(...interface{}) error
}) (*model.PomodoroSession, error) {
	var s model.PomodoroSession
	var note string
	if err := row.Scan(&s.ID, &s.TaskID, &s.PlannedMinutes, &s.ActualMinutes, &s.Status,
		&s.StartedAt, &s.EndedAt, &note); err != nil {
		return nil, err
	}
	s.Note = note
	return &s, nil
}

func (d *PomodoroDAO) Create(s *model.PomodoroSession) (int64, error) {
	if s.StartedAt == 0 {
		s.StartedAt = time.Now().Unix()
	}
	if s.Status == model.PomodoroStatusRunning {
		s.EndedAt = 0
	}
	res, err := d.db.Exec(
		`INSERT INTO pomodoro_sessions (task_id, planned_minutes, actual_minutes, status, started_at, ended_at, note) VALUES (?,?,?,?,?,?,?)`,
		s.TaskID, s.PlannedMinutes, s.ActualMinutes, s.Status, s.StartedAt, s.EndedAt, s.Note,
	)
	if err != nil {
		return 0, err
	}
	return res.LastInsertId()
}

func (d *PomodoroDAO) Get(id int64) (*model.PomodoroSession, error) {
	row := d.db.QueryRow(`SELECT `+pomodoroColumns+` FROM pomodoro_sessions WHERE id=?`, id)
	s, err := scanPomodoro(row)
	if errors.Is(err, sql.ErrNoRows) {
		return nil, ErrPomodoroNotFound
	}
	return s, err
}

func (d *PomodoroDAO) Complete(id int64, actualMinutes int, status int) (*model.PomodoroSession, error) {
	now := time.Now().Unix()
	res, err := d.db.Exec(
		`UPDATE pomodoro_sessions SET actual_minutes=?, status=?, ended_at=? WHERE id=?`,
		actualMinutes, status, now, id,
	)
	if err != nil {
		return nil, err
	}
	n, _ := res.RowsAffected()
	if n == 0 {
		return nil, ErrPomodoroNotFound
	}
	return d.Get(id)
}

func (d *PomodoroDAO) ListByTask(taskID int64, days int) ([]*model.PomodoroSession, error) {
	since := time.Now().AddDate(0, 0, -days).Unix()
	rows, err := d.db.Query(
		`SELECT `+pomodoroColumns+` FROM pomodoro_sessions WHERE task_id=? AND started_at>=? ORDER BY started_at DESC`,
		taskID, since,
	)
	if err != nil {
		return nil, err
	}
	defer rows.Close()
	var list []*model.PomodoroSession
	for rows.Next() {
		s, err := scanPomodoro(rows)
		if err != nil {
			return nil, fmt.Errorf("scan: %w", err)
		}
		list = append(list, s)
	}
	return list, rows.Err()
}

type TaskPomodoroStats struct {
	TaskID       int64 `json:"task_id"`
	TotalCount   int   `json:"total_count"`
	TodayCount   int   `json:"today_count"`
	TotalMinutes int   `json:"total_minutes"`
	TodayMinutes int   `json:"today_minutes"`
}

func (d *PomodoroDAO) StatsByTaskIDs(taskIDs []int64, days int) (map[int64]TaskPomodoroStats, error) {
	out := map[int64]TaskPomodoroStats{}
	if len(taskIDs) == 0 {
		return out, nil
	}
	now := time.Now()
	todayStart := time.Date(now.Year(), now.Month(), now.Day(), 0, 0, 0, 0, now.Location()).Unix()
	periodStart := now.Unix() - int64(days)*86400
	placeholders := strings.Repeat("?,", len(taskIDs)-1) + "?"
	args := make([]interface{}, 0, len(taskIDs)+3)
	args = append(args, todayStart)
	args = append(args, todayStart)
	for _, id := range taskIDs {
		args = append(args, id)
	}
	args = append(args, periodStart)
	rows, err := d.db.Query(
		`SELECT task_id,
		        COUNT(*),
		        SUM(CASE WHEN started_at>=? THEN 1 ELSE 0 END),
		        SUM(actual_minutes),
		        SUM(CASE WHEN started_at>=? THEN actual_minutes ELSE 0 END)
		 FROM pomodoro_sessions
		 WHERE task_id IN (`+placeholders+`) AND status IN (1,2) AND started_at>=?
		 GROUP BY task_id`,
		args...,
	)
	if err != nil {
		return nil, err
	}
	defer rows.Close()
	for rows.Next() {
		var s TaskPomodoroStats
		var totalCount, todayCount, totalMin, todayMin sql.NullInt64
		if err := rows.Scan(&s.TaskID, &totalCount, &todayCount, &totalMin, &todayMin); err != nil {
			return nil, err
		}
		s.TotalCount = int(totalCount.Int64)
		s.TodayCount = int(todayCount.Int64)
		s.TotalMinutes = int(totalMin.Int64)
		s.TodayMinutes = int(todayMin.Int64)
		out[s.TaskID] = s
	}
	return out, rows.Err()
}