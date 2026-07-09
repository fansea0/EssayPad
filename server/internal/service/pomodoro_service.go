package service

import (
	"essaypad/internal/model"
	"essaypad/internal/store"
)

type PomodoroService struct {
	dao *store.PomodoroDAO
}

func NewPomodoroService(dao *store.PomodoroDAO) *PomodoroService {
	return &PomodoroService{dao: dao}
}

func (s *PomodoroService) Create(taskID int64, plannedMinutes int) (int64, error) {
	sess := &model.PomodoroSession{
		TaskID:         taskID,
		PlannedMinutes: plannedMinutes,
		Status:         model.PomodoroStatusRunning,
	}
	id, err := s.dao.Create(sess)
	if err != nil {
		return 0, err
	}
	return id, nil
}

func (s *PomodoroService) Complete(id int64, actualMinutes int, status int) (*model.PomodoroSession, error) {
	return s.dao.Complete(id, actualMinutes, status)
}

func (s *PomodoroService) ListByTask(taskID int64, days int) ([]*model.PomodoroSession, error) {
	return s.dao.ListByTask(taskID, days)
}

func (s *PomodoroService) StatsByTaskIDs(taskIDs []int64, days int) (map[int64]store.TaskPomodoroStats, error) {
	return s.dao.StatsByTaskIDs(taskIDs, days)
}