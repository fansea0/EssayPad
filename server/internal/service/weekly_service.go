package service

import (
	"encoding/json"
	"fmt"
	"time"

	"essaypad/internal/ai"
	"essaypad/internal/model"
	"essaypad/internal/store"
)

type WeeklyReport = model.WeeklyReport

type WeeklyService struct {
	noteDAO    *store.NoteDAO
	weeklyDAO  *store.WeeklyDAO
	taskDAO    *store.TaskDAO
	diaryDAO   *store.DiaryDAO
	messageDAO *store.WeeklyReflectionMessageDAO
	ai         *ai.Client
}

func NewWeeklyService(noteDAO *store.NoteDAO, weeklyDAO *store.WeeklyDAO, taskDAO *store.TaskDAO, diaryDAO *store.DiaryDAO, messageDAO *store.WeeklyReflectionMessageDAO, aic *ai.Client) *WeeklyService {
	return &WeeklyService{noteDAO: noteDAO, weeklyDAO: weeklyDAO, taskDAO: taskDAO, diaryDAO: diaryDAO, messageDAO: messageDAO, ai: aic}
}

func (s *WeeklyService) GenerateReflection(mode string, force bool) (*WeeklyReport, bool, error) {
	start, end, days := windowForMode(mode)
	if !force {
		if cached, err := s.weeklyDAO.FindByWindow(mode, start, end); err == nil && cached.ReflectionJSON != "" {
			return cached, true, nil
		}
	}
	notes, err := s.noteDAO.ListInRangeByMode(mode)
	if err != nil {
		return nil, false, err
	}
	diaries, err := s.diaryDAO.ListInRange(start, end)
	if err != nil {
		return nil, false, err
	}
	active, completed, overdue, err := s.taskDAO.ListForWeekly(days)
	if err != nil {
		return nil, false, err
	}
	reflection, responseID, expireAt, err := s.ai.GenerateReflection(ai.ReflectionInput{Notes: notes, Diaries: diaries, Tasks: ai.BuildTaskSummary(active, completed, overdue), Days: days})
	if err != nil {
		return nil, false, err
	}
	reflectionJSON, _ := json.Marshal(reflection)
	report := &model.WeeklyReport{Preset: mode, RangeStart: start, RangeEnd: end, Summary: reflection.OneLiner, Highlights: reflection.Observations, ActionItems: reflection.Suggestions, NoteCount: len(notes) + len(diaries) + len(active) + len(completed) + len(overdue), ReflectionJSON: string(reflectionJSON), ResponseID: responseID, ResponseExpireAt: expireAt, CreatedAt: time.Now().Unix()}
	id, err := s.weeklyDAO.Save(report)
	if err != nil {
		return nil, false, err
	}
	report.ID = id
	return report, false, nil
}

func (s *WeeklyService) ListMessages(reportID int64) ([]*model.WeeklyReflectionMessage, error) {
	return s.messageDAO.ListByReportID(reportID, 100)
}

func (s *WeeklyService) DeleteMessages(reportID int64) error {
	return s.messageDAO.SoftDeleteByReportID(reportID)
}

func (s *WeeklyService) Chat(reportID int64, content string) (*model.WeeklyReflectionMessage, *model.WeeklyReflectionMessage, error) {
	report, err := s.weeklyDAO.Get(reportID)
	if err != nil {
		return nil, nil, err
	}
	user := &model.WeeklyReflectionMessage{ReportID: reportID, Role: model.WeeklyReflectionRoleUser, Content: content, PreviousResponseID: report.ResponseID}
	if user.ID, err = s.messageDAO.Create(user); err != nil {
		return nil, nil, err
	}
	history, err := s.messageDAO.ListByReportID(reportID, 12)
	if err != nil {
		return nil, nil, err
	}
	previousID := report.ResponseID
	if len(history) > 1 && history[len(history)-2].ResponseID != "" {
		previousID = history[len(history)-2].ResponseID
	}
	reply, responseID, expireAt, err := s.ai.ChatReflection(report.ReflectionJSON, history[:len(history)-1], content, previousID)
	if err != nil {
		return nil, nil, err
	}
	assistant := &model.WeeklyReflectionMessage{ReportID: reportID, Role: model.WeeklyReflectionRoleAssistant, Content: reply, ResponseID: responseID, PreviousResponseID: previousID}
	if assistant.ID, err = s.messageDAO.Create(assistant); err != nil {
		return nil, nil, err
	}
	if expireAt > 0 {
		report.ResponseID, report.ResponseExpireAt = responseID, expireAt
		_, _ = s.weeklyDAO.Save(report)
	}
	return user, assistant, nil
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
