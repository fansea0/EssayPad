package store

import (
	"os"
	"path/filepath"
	"testing"
	"time"

	"essaypad/internal/model"
)

func newTaskTestDAO(t *testing.T) (*TaskDAO, func()) {
	t.Helper()
	dir := t.TempDir()
	dbPath := filepath.Join(dir, "test.db")
	db, err := OpenDB(dbPath)
	if err != nil {
		t.Fatal(err)
	}
	return NewTaskDAO(db), func() {
		db.Close()
		os.Remove(dbPath)
	}
}

func TestTaskCreateGetUpdate(t *testing.T) {
	dao, cleanup := newTaskTestDAO(t)
	defer cleanup()

	now := time.Now().Unix()
	t1 := &model.Task{
		Title:     "重构登录页",
		Progress:  0,
		Priority:  model.TaskPriorityUrgent,
		Status:    model.TaskStatusActive,
		DueAt:     todayStartUnix(),
		CreatedAt: now,
		UpdatedAt: now,
	}
	id, err := dao.Create(t1)
	if err != nil {
		t.Fatal(err)
	}
	if id <= 0 {
		t.Fatalf("expected id > 0, got %d", id)
	}

	got, err := dao.Get(id)
	if err != nil {
		t.Fatal(err)
	}
	if got.Title != "重构登录页" || got.Progress != 0 || got.Priority != 2 {
		t.Fatalf("mismatch: %+v", got)
	}

	fields := map[string]interface{}{"progress": 50, "priority": 1}
	updated, err := dao.Update(id, fields)
	if err != nil {
		t.Fatal(err)
	}
	if updated.Progress != 50 || updated.Priority != 1 {
		t.Fatalf("update mismatch: %+v", updated)
	}
}

func TestTaskListByGroup(t *testing.T) {
	dao, cleanup := newTaskTestDAO(t)
	defer cleanup()

	now := time.Now().Unix()
	today := todayStartUnix()
	yesterday := today - 86400

	for i := 0; i < 3; i++ {
		if _, err := dao.Create(&model.Task{Title: "today", DueAt: today, CreatedAt: now, UpdatedAt: now}); err != nil {
			t.Fatal(err)
		}
	}
	if _, err := dao.Create(&model.Task{Title: "yesterday", DueAt: yesterday, CreatedAt: now, UpdatedAt: now}); err != nil {
		t.Fatal(err)
	}

	todayList, err := dao.ListByGroup("today")
	if err != nil {
		t.Fatal(err)
	}
	if len(todayList) != 3 {
		t.Fatalf("expected 3 today, got %d", len(todayList))
	}

	yList, err := dao.ListByGroup("yesterday")
	if err != nil {
		t.Fatal(err)
	}
	if len(yList) != 1 {
		t.Fatalf("expected 1 yesterday, got %d", len(yList))
	}

	all, err := dao.ListByGroup("all")
	if err != nil {
		t.Fatal(err)
	}
	if len(all) != 4 {
		t.Fatalf("expected 4 all, got %d", len(all))
	}
}

func TestTaskSoftDelete(t *testing.T) {
	dao, cleanup := newTaskTestDAO(t)
	defer cleanup()

	now := time.Now().Unix()
	id, err := dao.Create(&model.Task{Title: "x", DueAt: todayStartUnix(), CreatedAt: now, UpdatedAt: now})
	if err != nil {
		t.Fatal(err)
	}

	if err := dao.SoftDelete(id); err != nil {
		t.Fatal(err)
	}
	_, err = dao.Get(id)
	if err != ErrTaskNotFound {
		t.Fatalf("expected ErrTaskNotFound, got %v", err)
	}
}

func TestTaskListForWeekly(t *testing.T) {
	dao, cleanup := newTaskTestDAO(t)
	defer cleanup()

	now := time.Now().Unix()
	today := todayStartUnix()
	longAgo := now - 14*86400

	if _, err := dao.Create(&model.Task{Title: "active", Status: model.TaskStatusActive, Progress: 50, DueAt: today, CreatedAt: now, UpdatedAt: now}); err != nil {
		t.Fatal(err)
	}
	if _, err := dao.Create(&model.Task{Title: "done", Status: model.TaskStatusDone, DueAt: today, CreatedAt: now, UpdatedAt: now, CompletedAt: now}); err != nil {
		t.Fatal(err)
	}
	if _, err := dao.Create(&model.Task{Title: "overdue", Status: model.TaskStatusActive, Progress: 0, DueAt: longAgo, CreatedAt: now, UpdatedAt: now}); err != nil {
		t.Fatal(err)
	}

	active, done, overdue, err := dao.ListForWeekly(7)
	if err != nil {
		t.Fatal(err)
	}
	if len(active) != 1 {
		t.Fatalf("expected 1 active, got %d", len(active))
	}
	if len(done) != 1 {
		t.Fatalf("expected 1 done, got %d", len(done))
	}
	if len(overdue) != 1 {
		t.Fatalf("expected 1 overdue, got %d", len(overdue))
	}
}

func TestTaskGetNotFound(t *testing.T) {
	dao, cleanup := newTaskTestDAO(t)
	defer cleanup()

	_, err := dao.Get(999)
	if err != ErrTaskNotFound {
		t.Fatalf("expected ErrTaskNotFound, got %v", err)
	}
}

func TestTaskUpdateEmptyFields(t *testing.T) {
	dao, cleanup := newTaskTestDAO(t)
	defer cleanup()

	now := time.Now().Unix()
	id, _ := dao.Create(&model.Task{Title: "x", DueAt: todayStartUnix(), CreatedAt: now, UpdatedAt: now})

	got, err := dao.Update(id, map[string]interface{}{})
	if err != nil {
		t.Fatal(err)
	}
	if got.Title != "x" {
		t.Fatalf("empty update should be no-op: %+v", got)
	}
}