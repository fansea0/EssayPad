package store

import (
	"database/sql"
	"errors"
	"fmt"
	"strings"
	"time"

	"essaypad/internal/model"
)

var ErrDiaryNotFound = errors.New("diary not found")

type DiaryDAO struct {
	db *sql.DB
}

func NewDiaryDAO(db *sql.DB) *DiaryDAO {
	return &DiaryDAO{db: db}
}

type DiaryListFilter struct {
	UserID  int64
	Mode    string
	Keyword string
}

const diaryColumns = "id, user_id, diary_date, title, content, mood, status, activity, created_at, updated_at"

func scanDiary(row interface {
	Scan(...interface{}) error
}) (*model.DiaryEntry, error) {
	var d model.DiaryEntry
	if err := row.Scan(&d.ID, &d.UserID, &d.DiaryDate, &d.Title, &d.Content, &d.Mood, &d.Status,
		&d.Activity, &d.CreatedAt, &d.UpdatedAt); err != nil {
		return nil, err
	}
	return &d, nil
}

func (d *DiaryDAO) CreateOrUpdateByDate(entry *model.DiaryEntry) (*model.DiaryEntry, error) {
	d.fillDefaults(entry)
	res, err := d.db.Exec(
		`INSERT INTO diary_entries
		 (user_id, diary_date, title, content, mood, status, activity, created_at, updated_at, is_deleted)
		 VALUES (?,?,?,?,?,?,?,?,?,0)
		 ON CONFLICT(user_id, diary_date) DO UPDATE SET
		   title=excluded.title,
		   content=excluded.content,
		   mood=excluded.mood,
		   status=excluded.status,
		   activity=excluded.activity,
		   updated_at=CASE
		     WHEN diary_entries.title = excluded.title
		      AND diary_entries.content = excluded.content
		      AND diary_entries.mood = excluded.mood
		      AND diary_entries.status = excluded.status
		      AND diary_entries.activity = excluded.activity
		      AND diary_entries.is_deleted = 0
		     THEN diary_entries.updated_at
		     ELSE excluded.updated_at
		   END,
		   is_deleted=0`,
		entry.UserID, entry.DiaryDate, entry.Title, entry.Content, entry.Mood, entry.Status,
		entry.Activity, entry.CreatedAt, entry.UpdatedAt,
	)
	if err != nil {
		return nil, err
	}
	id, _ := res.LastInsertId()
	if id > 0 {
		return d.Get(id)
	}
	return d.GetByDate(entry.UserID, entry.DiaryDate)
}

func (d *DiaryDAO) Get(id int64) (*model.DiaryEntry, error) {
	row := d.db.QueryRow(
		`SELECT `+diaryColumns+` FROM diary_entries WHERE id=? AND is_deleted=0`,
		id,
	)
	entry, err := scanDiary(row)
	if errors.Is(err, sql.ErrNoRows) {
		return nil, ErrDiaryNotFound
	}
	return entry, err
}

func (d *DiaryDAO) GetByDate(userID, diaryDate int64) (*model.DiaryEntry, error) {
	row := d.db.QueryRow(
		`SELECT `+diaryColumns+` FROM diary_entries WHERE user_id=? AND diary_date=? AND is_deleted=0`,
		userID, diaryDate,
	)
	entry, err := scanDiary(row)
	if errors.Is(err, sql.ErrNoRows) {
		return nil, ErrDiaryNotFound
	}
	return entry, err
}

func (d *DiaryDAO) List(filter DiaryListFilter) ([]*model.DiaryEntry, int, error) {
	where := []string{"is_deleted=0", "user_id=?"}
	args := []interface{}{filter.UserID}

	if filter.Mode == "week" {
		start := weekStartUnix()
		end := todayStartUnix() + 86400
		where = append(where, "diary_date>=?", "diary_date<?")
		args = append(args, start, end)
	}
	keyword := strings.TrimSpace(filter.Keyword)
	if keyword != "" {
		like := "%" + strings.ToLower(keyword) + "%"
		where = append(where, "(LOWER(title) LIKE ? OR LOWER(content) LIKE ?)")
		args = append(args, like, like)
	}

	whereSQL := strings.Join(where, " AND ")
	var total int
	if err := d.db.QueryRow(`SELECT COUNT(*) FROM diary_entries WHERE `+whereSQL, args...).Scan(&total); err != nil {
		return nil, 0, err
	}

	rows, err := d.db.Query(
		`SELECT `+diaryColumns+`
		 FROM diary_entries
		 WHERE `+whereSQL+`
		 ORDER BY diary_date DESC, updated_at DESC, id DESC`,
		args...,
	)
	if err != nil {
		return nil, 0, err
	}
	defer rows.Close()

	var list []*model.DiaryEntry
	for rows.Next() {
		entry, err := scanDiary(rows)
		if err != nil {
			return nil, 0, fmt.Errorf("scan: %w", err)
		}
		list = append(list, entry)
	}
	return list, total, rows.Err()
}

func (d *DiaryDAO) ListInRange(start, end int64) ([]*model.DiaryEntry, error) {
	rows, err := d.db.Query(`SELECT `+diaryColumns+` FROM diary_entries
		WHERE user_id=0 AND is_deleted=0 AND diary_date>=? AND diary_date<?
		ORDER BY diary_date DESC, id DESC`, start, end)
	if err != nil {
		return nil, err
	}
	defer rows.Close()
	var list []*model.DiaryEntry
	for rows.Next() {
		entry, err := scanDiary(rows)
		if err != nil {
			return nil, err
		}
		list = append(list, entry)
	}
	return list, rows.Err()
}

func (d *DiaryDAO) Update(id int64, fields map[string]interface{}) (*model.DiaryEntry, error) {
	if len(fields) == 0 {
		return d.Get(id)
	}
	old, err := d.Get(id)
	if err != nil {
		return nil, err
	}
	newEntry := *old
	for k, v := range fields {
		switch k {
		case "title":
			newEntry.Title, _ = v.(string)
		case "content":
			newEntry.Content, _ = v.(string)
		case "mood":
			newEntry.Mood, _ = v.(int)
		case "status":
			newEntry.Status, _ = v.(int)
		case "activity":
			newEntry.Activity, _ = v.(int)
		}
	}
	if sameDiaryContent(old, &newEntry) {
		return old, nil
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
	args = append(args, time.Now().Unix(), id)

	res, err := d.db.Exec(`UPDATE diary_entries SET `+set+` WHERE id=? AND is_deleted=0`, args...)
	if err != nil {
		return nil, err
	}
	n, _ := res.RowsAffected()
	if n == 0 {
		return nil, ErrDiaryNotFound
	}
	return d.Get(id)
}

func (d *DiaryDAO) SoftDelete(id int64) error {
	res, err := d.db.Exec(`UPDATE diary_entries SET is_deleted=1, updated_at=? WHERE id=? AND is_deleted=0`,
		time.Now().Unix(), id)
	if err != nil {
		return err
	}
	n, _ := res.RowsAffected()
	if n == 0 {
		return ErrDiaryNotFound
	}
	return nil
}

func (d *DiaryDAO) fillDefaults(entry *model.DiaryEntry) {
	now := time.Now().Unix()
	if entry.DiaryDate == 0 {
		entry.DiaryDate = todayStartUnix()
	}
	if entry.CreatedAt == 0 {
		entry.CreatedAt = now
	}
	if entry.UpdatedAt == 0 {
		entry.UpdatedAt = entry.CreatedAt
	}
}

func sameDiaryContent(a, b *model.DiaryEntry) bool {
	return a.Title == b.Title &&
		a.Content == b.Content &&
		a.Mood == b.Mood &&
		a.Status == b.Status &&
		a.Activity == b.Activity
}

func weekStartUnix() int64 {
	now := time.Now()
	today := time.Date(now.Year(), now.Month(), now.Day(), 0, 0, 0, 0, now.Location())
	return today.AddDate(0, 0, -6).Unix()
}
