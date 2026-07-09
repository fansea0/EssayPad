package store

import (
	"path/filepath"
	"testing"
	"time"

	"essaypad/internal/model"
)

func newPomodoroTestDAO(t *testing.T) (*PomodoroDAO, *TaskDAO, func()) {
	t.Helper()
	dir := t.TempDir()
	dbPath := filepath.Join(dir, "test.db")
	db, err := OpenDB(dbPath)
	if err != nil {
		t.Fatal(err)
	}
	return NewPomodoroDAO(db), NewTaskDAO(db), func() { db.Close() }
}

func TestPomodoroCreateComplete(t *testing.T) {
	dao, taskDAO, cleanup := newPomodoroTestDAO(t)
	defer cleanup()

	now := time.Now().Unix()
	taskID, err := taskDAO.Create(&model.Task{
		Title:     "t",
		DueAt:     todayStartUnix(),
		CreatedAt: now,
		UpdatedAt: now,
	})
	if err != nil {
		t.Fatal(err)
	}

	id, err := dao.Create(&model.PomodoroSession{
		TaskID:         taskID,
		PlannedMinutes: 25,
		Status:         model.PomodoroStatusRunning,
		StartedAt:      now,
	})
	if err != nil {
		t.Fatal(err)
	}
	if id <= 0 {
		t.Fatalf("expected id > 0, got %d", id)
	}

	s, err := dao.Complete(id, 25, model.PomodoroStatusCompleted)
	if err != nil {
		t.Fatal(err)
	}
	if s.ActualMinutes != 25 {
		t.Fatalf("expected 25, got %d", s.ActualMinutes)
	}
	if s.EndedAt == 0 {
		t.Fatal("ended_at should be set")
	}
	if s.Status != model.PomodoroStatusCompleted {
		t.Fatalf("expected status=1, got %d", s.Status)
	}
}

func TestPomodoroStatsByTaskIDs(t *testing.T) {
	dao, _, cleanup := newPomodoroTestDAO(t)
	defer cleanup()

	now := time.Now().Unix()
	todayStart := time.Date(time.Now().Year(), time.Now().Month(), time.Now().Day(), 0, 0, 0, 0, time.Local).Unix()

	for i := 0; i < 2; i++ {
		id, err := dao.Create(&model.PomodoroSession{
			TaskID:         1,
			PlannedMinutes: 25,
			Status:         model.PomodoroStatusRunning,
			StartedAt:      now,
		})
		if err != nil {
			t.Fatal(err)
		}
		if _, err := dao.Complete(id, 25, model.PomodoroStatusCompleted); err != nil {
			t.Fatal(err)
		}
	}
	id, err := dao.Create(&model.PomodoroSession{
		TaskID:         1,
		PlannedMinutes: 25,
		Status:         model.PomodoroStatusRunning,
		StartedAt:      now,
	})
	if err != nil {
		t.Fatal(err)
	}
	if _, err := dao.Complete(id, 10, model.PomodoroStatusAborted); err != nil {
		t.Fatal(err)
	}

	id, err = dao.Create(&model.PomodoroSession{
		TaskID:         2,
		PlannedMinutes: 25,
		Status:         model.PomodoroStatusRunning,
		StartedAt:      todayStart - 14*86400,
	})
	if err != nil {
		t.Fatal(err)
	}
	if _, err := dao.Complete(id, 25, model.PomodoroStatusCompleted); err != nil {
		t.Fatal(err)
	}

	stats, err := dao.StatsByTaskIDs([]int64{1, 2}, 30)
	if err != nil {
		t.Fatal(err)
	}
	s1 := stats[1]
	if s1.TotalCount != 3 {
		t.Fatalf("expected task1 total 3, got %d", s1.TotalCount)
	}
	if s1.TodayCount != 3 {
		t.Fatalf("expected task1 today 3, got %d", s1.TodayCount)
	}
	if s1.TotalMinutes != 60 {
		t.Fatalf("expected task1 total min 60, got %d", s1.TotalMinutes)
	}
	if s1.TodayMinutes != 60 {
		t.Fatalf("expected task1 today min 60, got %d", s1.TodayMinutes)
	}

	s2 := stats[2]
	if s2.TotalCount != 1 {
		t.Fatalf("expected task2 total 1, got %d", s2.TotalCount)
	}
	if s2.TodayCount != 0 {
		t.Fatalf("expected task2 today 0, got %d", s2.TodayCount)
	}
}

func TestPomodoroListByTask(t *testing.T) {
	dao, _, cleanup := newPomodoroTestDAO(t)
	defer cleanup()

	now := time.Now().Unix()
	id, err := dao.Create(&model.PomodoroSession{
		TaskID:         42,
		PlannedMinutes: 25,
		Status:         model.PomodoroStatusRunning,
		StartedAt:      now,
	})
	if err != nil {
		t.Fatal(err)
	}
	if _, err := dao.Complete(id, 25, model.PomodoroStatusCompleted); err != nil {
		t.Fatal(err)
	}

	list, err := dao.ListByTask(42, 7)
	if err != nil {
		t.Fatal(err)
	}
	if len(list) != 1 {
		t.Fatalf("expected 1, got %d", len(list))
	}
	if list[0].TaskID != 42 {
		t.Fatalf("expected task 42, got %d", list[0].TaskID)
	}
}

func TestPomodoroGetNotFound(t *testing.T) {
	dao, _, cleanup := newPomodoroTestDAO(t)
	defer cleanup()

	_, err := dao.Get(99999)
	if err != ErrPomodoroNotFound {
		t.Fatalf("expected ErrPomodoroNotFound, got %v", err)
	}
}