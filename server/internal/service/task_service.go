package service

import (
	"time"

	"essaypad/internal/model"
	"essaypad/internal/store"
)

type TaskService struct {
	dao         *store.TaskDAO
	noteDAO     *store.NoteDAO
	pomodoroDAO *store.PomodoroDAO
}

func NewTaskService(dao *store.TaskDAO, noteDAO *store.NoteDAO, pomodoroDAO *store.PomodoroDAO) *TaskService {
	return &TaskService{dao: dao, noteDAO: noteDAO, pomodoroDAO: pomodoroDAO}
}

func (s *TaskService) Create(t *model.Task) (int64, error) {
	if t.Title == "" {
		return 0, ErrTitleEmpty
	}
	if t.Priority == 0 {
		t.Priority = model.TaskPriorityNormal
	}
	if !model.ValidTaskPriority(t.Priority) {
		t.Priority = model.TaskPriorityNormal
	}
	return s.dao.Create(t)
}

func (s *TaskService) Get(id int64) (*model.Task, error) {
	return s.dao.Get(id)
}

func (s *TaskService) Update(id int64, fields map[string]interface{}) (*model.Task, error) {
	return s.dao.Update(id, fields)
}

func (s *TaskService) Delete(id int64) error {
	return s.dao.SoftDelete(id)
}

func (s *TaskService) ListByGroup(group string) ([]*model.Task, error) {
	return s.dao.ListByGroup(group)
}

// TaskWithCount 任务 + 关联笔记数 + 番茄统计(响应结构,不污染 model.Task)
type TaskWithCount struct {
	*model.Task
	NoteCount            int `json:"note_count"`
	PomodoroCount        int `json:"pomodoro_count"`
	PomodoroMinutes      int `json:"pomodoro_minutes"`
	PomodoroTodayMinutes int `json:"pomodoro_today_minutes"`
}

func (s *TaskService) ListByGroupWithCount(group string) ([]TaskWithCount, error) {
	tasks, err := s.dao.ListByGroup(group)
	if err != nil {
		return nil, err
	}
	if len(tasks) == 0 {
		return []TaskWithCount{}, nil
	}
	ids := make([]int64, len(tasks))
	for i, t := range tasks {
		ids[i] = t.ID
	}
	counts, err := s.noteDAO.CountByTaskIDs(ids)
	if err != nil {
		return nil, err
	}
	pomodoroStats, _ := s.pomodoroDAO.StatsByTaskIDs(ids, 30)
	out := make([]TaskWithCount, len(tasks))
	for i := range tasks {
		t := tasks[i]
		stats := pomodoroStats[t.ID]
		out[i] = TaskWithCount{
			Task:                 t,
			NoteCount:            counts[t.ID],
			PomodoroCount:        stats.TotalCount,
			PomodoroMinutes:      stats.TotalMinutes,
			PomodoroTodayMinutes: stats.TodayMinutes,
		}
	}
	return out, nil
}

func (s *TaskService) GetWithCount(id int64) (*TaskWithCount, error) {
	t, err := s.dao.Get(id)
	if err != nil {
		return nil, err
	}
	counts, err := s.noteDAO.CountByTaskIDs([]int64{id})
	if err != nil {
		return nil, err
	}
	pomodoroStats, _ := s.pomodoroDAO.StatsByTaskIDs([]int64{id}, 30)
	stats := pomodoroStats[id]
	return &TaskWithCount{
		Task:                 t,
		NoteCount:            counts[id],
		PomodoroCount:        stats.TotalCount,
		PomodoroMinutes:      stats.TotalMinutes,
		PomodoroTodayMinutes: stats.TodayMinutes,
	}, nil
}

func (s *TaskService) MoveToToday(id int64) (*model.Task, error) {
	now := time.Now()
	todayStart := time.Date(now.Year(), now.Month(), now.Day(), 0, 0, 0, 0, now.Location()).Unix()
	return s.dao.Update(id, map[string]interface{}{
		"due_at": todayStart,
		"status": model.TaskStatusActive,
	})
}

func (s *TaskService) Complete(id int64) (*model.Task, error) {
	now := time.Now().Unix()
	return s.dao.Update(id, map[string]interface{}{
		"progress":     100,
		"status":       model.TaskStatusDone,
		"completed_at": now,
	})
}

func (s *TaskService) UpdateProgress(id int64, progress int) (*model.Task, error) {
	if !model.ValidProgress(progress) {
		return s.dao.Get(id)
	}
	return s.dao.Update(id, map[string]interface{}{"progress": progress})
}
