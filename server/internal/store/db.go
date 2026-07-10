package store

import (
	"database/sql"
	"fmt"

	_ "modernc.org/sqlite"
)

const schema = `
CREATE TABLE IF NOT EXISTS notes (
	id INTEGER PRIMARY KEY AUTOINCREMENT,
	category TINYINT NOT NULL DEFAULT 0,
	title VARCHAR(200) NOT NULL DEFAULT '',
	content TEXT NOT NULL DEFAULT '',
	created_at BIGINT NOT NULL DEFAULT 0,
	updated_at BIGINT NOT NULL DEFAULT 0,
	is_deleted TINYINT NOT NULL DEFAULT 0,
	task_id BIGINT NOT NULL DEFAULT 0
);
CREATE INDEX IF NOT EXISTS idx_notes_category_updated ON notes(category, updated_at DESC);
CREATE INDEX IF NOT EXISTS idx_notes_updated ON notes(updated_at DESC);

CREATE TABLE IF NOT EXISTS weekly_reports (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    preset TEXT NOT NULL DEFAULT '',
    range_start BIGINT NOT NULL DEFAULT 0,
    range_end BIGINT NOT NULL DEFAULT 0,
    summary TEXT NOT NULL DEFAULT '',
    highlights TEXT NOT NULL DEFAULT '',
    action_items TEXT NOT NULL DEFAULT '',
    note_count INTEGER NOT NULL DEFAULT 0,
    created_at BIGINT NOT NULL DEFAULT 0
);
CREATE UNIQUE INDEX IF NOT EXISTS idx_weekly_reports_window
  ON weekly_reports(preset, range_start, range_end);
CREATE INDEX IF NOT EXISTS idx_weekly_reports_created
  ON weekly_reports(created_at DESC);

CREATE TABLE IF NOT EXISTS tasks (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    title VARCHAR(200) NOT NULL DEFAULT '',
    description TEXT NOT NULL DEFAULT '',
    progress INTEGER NOT NULL DEFAULT 0,
    priority TINYINT NOT NULL DEFAULT 0,
    status TINYINT NOT NULL DEFAULT 0,
    due_at BIGINT NOT NULL DEFAULT 0,
    created_at BIGINT NOT NULL DEFAULT 0,
    updated_at BIGINT NOT NULL DEFAULT 0,
    completed_at BIGINT NOT NULL DEFAULT 0,
    is_deleted TINYINT NOT NULL DEFAULT 0
);
CREATE INDEX IF NOT EXISTS idx_tasks_due_status ON tasks(due_at DESC, status);
CREATE INDEX IF NOT EXISTS idx_tasks_status_updated ON tasks(status, updated_at DESC);

CREATE TABLE IF NOT EXISTS pomodoro_sessions (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    task_id BIGINT NOT NULL DEFAULT 0,
    planned_minutes INTEGER NOT NULL DEFAULT 0,
    actual_minutes INTEGER NOT NULL DEFAULT 0,
    status TINYINT NOT NULL DEFAULT 0,
    started_at BIGINT NOT NULL DEFAULT 0,
    ended_at BIGINT NOT NULL DEFAULT 0,
    note TEXT NOT NULL DEFAULT ''
);
CREATE INDEX IF NOT EXISTS idx_pomodoro_task_ended ON pomodoro_sessions(task_id, ended_at DESC);
CREATE INDEX IF NOT EXISTS idx_pomodoro_ended ON pomodoro_sessions(ended_at DESC);

CREATE TABLE IF NOT EXISTS diary_entries (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    user_id BIGINT NOT NULL DEFAULT 0,
    diary_date BIGINT NOT NULL DEFAULT 0,
    title VARCHAR(200) NOT NULL DEFAULT '',
    content TEXT NOT NULL DEFAULT '',
    mood TINYINT NOT NULL DEFAULT 0,
    status TINYINT NOT NULL DEFAULT 0,
    activity TINYINT NOT NULL DEFAULT 0,
    created_at BIGINT NOT NULL DEFAULT 0,
    updated_at BIGINT NOT NULL DEFAULT 0,
    is_deleted TINYINT NOT NULL DEFAULT 0
);
CREATE UNIQUE INDEX IF NOT EXISTS uniq_diary_user_date ON diary_entries(user_id, diary_date);
CREATE INDEX IF NOT EXISTS idx_diary_user_date_deleted ON diary_entries(user_id, diary_date DESC, is_deleted);
CREATE INDEX IF NOT EXISTS idx_diary_user_updated ON diary_entries(user_id, updated_at DESC);
`

func OpenDB(path string) (*sql.DB, error) {
	db, err := sql.Open("sqlite", path+"?_pragma=journal_mode(WAL)&_pragma=foreign_keys(1)")
	if err != nil {
		return nil, fmt.Errorf("open sqlite: %w", err)
	}
	if err := db.Ping(); err != nil {
		return nil, fmt.Errorf("ping db: %w", err)
	}
	if _, err := db.Exec(schema); err != nil {
		return nil, fmt.Errorf("migrate: %w", err)
	}
	if err := migrate(db); err != nil {
		return nil, fmt.Errorf("migrate columns: %w", err)
	}
	return db, nil
}

// migrate: 老 db 升级,补 task_id 列
func migrate(db *sql.DB) error {
	rows, err := db.Query("PRAGMA table_info(notes)")
	if err != nil {
		return err
	}
	hasTaskID := false
	for rows.Next() {
		var cid int
		var name, ctype string
		var notnull, pk int
		var dflt sql.NullString
		if err := rows.Scan(&cid, &name, &ctype, &notnull, &dflt, &pk); err != nil {
			rows.Close()
			return err
		}
		if name == "task_id" {
			hasTaskID = true
		}
	}
	rows.Close()
	if !hasTaskID {
		if _, err := db.Exec("ALTER TABLE notes ADD COLUMN task_id BIGINT NOT NULL DEFAULT 0"); err != nil {
			return err
		}
	}
	if _, err := db.Exec("CREATE INDEX IF NOT EXISTS idx_notes_task_id ON notes(task_id)"); err != nil {
		return err
	}
	return nil
}
