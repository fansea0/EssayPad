package service

import (
	"fmt"
	"time"

	"essaypad/internal/ai"
	"essaypad/internal/model"
	"essaypad/internal/store"
)

type WeeklyReport = model.WeeklyReport

type WeeklyService struct {
	noteDAO   *store.NoteDAO
	weeklyDAO *store.WeeklyDAO
	taskDAO   *store.TaskDAO
	ai        *ai.Client
}

func NewWeeklyService(noteDAO *store.NoteDAO, weeklyDAO *store.WeeklyDAO, taskDAO *store.TaskDAO, aic *ai.Client) *WeeklyService {
	return &WeeklyService{noteDAO: noteDAO, weeklyDAO: weeklyDAO, taskDAO: taskDAO, ai: aic}
}

func (s *WeeklyService) GenerateByMode(mode string, force bool) (*WeeklyReport, bool, error) {
	start, end, days := windowForMode(mode)
	if !force {
		if cached, err := s.weeklyDAO.FindByWindow(mode, start, end); err == nil {
			return cached, true, nil
		}
	}
	notes, err := s.noteDAO.ListInRangeByMode(mode)
	if err != nil {
		return nil, false, err
	}

	active, completed, overdue, err := s.taskDAO.ListForWeekly(days)
	if err != nil {
		return nil, false, fmt.Errorf("list tasks for weekly: %w", err)
	}
	taskSummary := ai.BuildTaskSummary(active, completed, overdue)

	generated, err := s.ai.GenerateWeekly(ai.WeeklyInput{
		Notes: notes,
		Tasks: taskSummary,
		Days:  days,
	})
	if err != nil {
		return nil, false, err
	}
	generated.Preset = mode
	generated.RangeStart = start
	generated.RangeEnd = end
	generated.NoteCount = len(notes) + len(active) + len(completed) + len(overdue)
	if generated.CreatedAt == 0 {
		generated.CreatedAt = time.Now().Unix()
	}
	if id, err := s.weeklyDAO.Save(generated); err != nil {
		fmt.Printf("warn: save weekly report failed: %v\n", err)
	} else {
		generated.ID = id
	}
	return generated, false, nil
}

// windowForMode returns (start, end, days) for the preset.
// "week" = today 00:00 -6 days ~ tomorrow 00:00 (7 calendar days).
func windowForMode(mode string) (start, end int64, days int) {
	now := time.Now()
	loc := now.Location()
	todayStart := time.Date(now.Year(), now.Month(), now.Day(), 0, 0, 0, 0, loc)

	switch mode {
	case "today":
		start = todayStart.Unix()
		end = todayStart.Add(24 * time.Hour).Unix()
		days = 1
	case "yesterday":
		start = todayStart.AddDate(0, 0, -1).Unix()
		end = todayStart.Unix()
		days = 1
	case "week":
		start = todayStart.AddDate(0, 0, -6).Unix()
		end = todayStart.Add(24 * time.Hour).Unix()
		days = 7
	default:
		start = todayStart.AddDate(0, 0, -6).Unix()
		end = todayStart.Add(24 * time.Hour).Unix()
		days = 7
	}
	return
}