package store

import (
	"database/sql"
	"time"

	"essaypad/internal/model"
)

type WeeklyReflectionMessageDAO struct{ db *sql.DB }

func NewWeeklyReflectionMessageDAO(db *sql.DB) *WeeklyReflectionMessageDAO {
	return &WeeklyReflectionMessageDAO{db: db}
}

func (d *WeeklyReflectionMessageDAO) Create(message *model.WeeklyReflectionMessage) (int64, error) {
	if message.CreatedAt == 0 {
		message.CreatedAt = time.Now().Unix()
	}
	result, err := d.db.Exec(`INSERT INTO weekly_reflection_messages
		(report_id, role, content, response_id, previous_response_id, created_at, is_deleted)
		VALUES (?,?,?,?,?,?,0)`, message.ReportID, message.Role, message.Content,
		message.ResponseID, message.PreviousResponseID, message.CreatedAt)
	if err != nil {
		return 0, err
	}
	return result.LastInsertId()
}

func (d *WeeklyReflectionMessageDAO) ListByReportID(reportID int64, limit int) ([]*model.WeeklyReflectionMessage, error) {
	if limit <= 0 || limit > 100 {
		limit = 100
	}
	rows, err := d.db.Query(`SELECT id, report_id, role, content, response_id, previous_response_id, created_at
		FROM weekly_reflection_messages WHERE report_id=? AND is_deleted=0
		ORDER BY created_at ASC, id ASC LIMIT ?`, reportID, limit)
	if err != nil {
		return nil, err
	}
	defer rows.Close()
	var list []*model.WeeklyReflectionMessage
	for rows.Next() {
		message := &model.WeeklyReflectionMessage{}
		if err := rows.Scan(&message.ID, &message.ReportID, &message.Role, &message.Content,
			&message.ResponseID, &message.PreviousResponseID, &message.CreatedAt); err != nil {
			return nil, err
		}
		list = append(list, message)
	}
	return list, rows.Err()
}
