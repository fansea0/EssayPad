package store

import (
	"path/filepath"
	"testing"
	"time"

	"essaypad/internal/model"
)

func TestNoteTaskRelation(t *testing.T) {
	dir := t.TempDir()
	dbPath := filepath.Join(dir, "test.db")
	db, err := OpenDB(dbPath)
	if err != nil {
		t.Fatal(err)
	}
	defer db.Close()

	noteDAO := NewNoteDAO(db)
	taskDAO := NewTaskDAO(db)

	now := time.Now().Unix()
	taskID, err := taskDAO.Create(&model.Task{
		Title:     "关联测试",
		DueAt:     todayStartUnix(),
		CreatedAt: now,
		UpdatedAt: now,
	})
	if err != nil {
		t.Fatalf("create task: %v", err)
	}

	note1ID, err := noteDAO.Create(&model.Note{
		Category:  model.CategoryIdea,
		Title:     "n1",
		Content:   "",
		TaskID:    taskID,
		CreatedAt: now,
		UpdatedAt: now,
	})
	if err != nil {
		t.Fatalf("create note1: %v", err)
	}

	note2ID, err := noteDAO.Create(&model.Note{
		Category:  model.CategoryIdea,
		Title:     "n2",
		Content:   "",
		CreatedAt: now,
		UpdatedAt: now,
	})
	if err != nil {
		t.Fatalf("create note2: %v", err)
	}

	notes, err := noteDAO.ListByTask(taskID)
	if err != nil {
		t.Fatalf("list by task: %v", err)
	}
	if len(notes) != 1 {
		t.Fatalf("expected 1 note in task, got %d", len(notes))
	}
	if notes[0].ID != note1ID {
		t.Fatalf("expected note1, got %d", notes[0].ID)
	}
	if notes[0].TaskID != taskID {
		t.Fatalf("expected task_id=%d, got %d", taskID, notes[0].TaskID)
	}

	counts, err := noteDAO.CountByTaskIDs([]int64{taskID, note2ID})
	if err != nil {
		t.Fatalf("count: %v", err)
	}
	if counts[taskID] != 1 {
		t.Fatalf("expected count=1 for task, got %d", counts[taskID])
	}
	if counts[note2ID] != 0 {
		t.Fatalf("expected count=0 for non-task id, got %d", counts[note2ID])
	}

	if err := noteDAO.UpdateTask(note1ID, 0); err != nil {
		t.Fatalf("detach: %v", err)
	}
	notes2, err := noteDAO.ListByTask(taskID)
	if err != nil {
		t.Fatalf("list after detach: %v", err)
	}
	if len(notes2) != 0 {
		t.Fatalf("expected 0 after detach, got %d", len(notes2))
	}

	got, err := noteDAO.Get(note1ID)
	if err != nil {
		t.Fatalf("get note1: %v", err)
	}
	if got.TaskID != 0 {
		t.Fatalf("expected task_id=0 after detach, got %d", got.TaskID)
	}
}