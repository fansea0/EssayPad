package store

import (
	"database/sql"
	"encoding/json"
	"errors"
	"time"

	"essaypad/internal/model"
)

var ErrWeeklyNotFound = errors.New("weekly report not found")

type WeeklyDAO struct {
	db *sql.DB
}

func NewWeeklyDAO(db *sql.DB) *WeeklyDAO {
	return &WeeklyDAO{db: db}
}

func (d *WeeklyDAO) FindByWindow(preset string, start, end int64) (*model.WeeklyReport, error) {
	row := d.db.QueryRow(
		`SELECT id, preset, range_start, range_end, summary, highlights, action_items, note_count, created_at
		 FROM weekly_reports WHERE preset=? AND range_start=? AND range_end=?`,
		preset, start, end,
	)
	var r model.WeeklyReport
	var hi, ai string
	if err := row.Scan(&r.ID, &r.Preset, &r.RangeStart, &r.RangeEnd, &r.Summary, &hi, &ai, &r.NoteCount, &r.CreatedAt); err != nil {
		if errors.Is(err, sql.ErrNoRows) {
			return nil, ErrWeeklyNotFound
		}
		return nil, err
	}
	if hi != "" {
		_ = json.Unmarshal([]byte(hi), &r.Highlights)
	}
	if ai != "" {
		_ = json.Unmarshal([]byte(ai), &r.ActionItems)
	}
	return &r, nil
}

func (d *WeeklyDAO) Save(r *model.WeeklyReport) (int64, error) {
	if r.CreatedAt == 0 {
		r.CreatedAt = time.Now().Unix()
	}
	hi, _ := json.Marshal(r.Highlights)
	ai, _ := json.Marshal(r.ActionItems)
	res, err := d.db.Exec(
		`INSERT OR REPLACE INTO weekly_reports
		 (preset, range_start, range_end, summary, highlights, action_items, note_count, created_at)
		 VALUES (?,?,?,?,?,?,?,?)`,
		r.Preset, r.RangeStart, r.RangeEnd, r.Summary, string(hi), string(ai), r.NoteCount, r.CreatedAt,
	)
	if err != nil {
		return 0, err
	}
	return res.LastInsertId()
}