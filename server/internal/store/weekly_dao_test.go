package store

import (
	"testing"
	"time"

	"essaypad/internal/model"
)

func TestWeeklyDAOFindAndSave(t *testing.T) {
	db, err := OpenDB(t.TempDir() + "/test.db")
	if err != nil {
		t.Fatal(err)
	}
	defer db.Close()
	dao := NewWeeklyDAO(db)

	r := &model.WeeklyReport{
		Preset:      "week",
		RangeStart:  1000,
		RangeEnd:    2000,
		Summary:     "test",
		Highlights:  []string{"a", "b"},
		ActionItems: []string{"x"},
		NoteCount:   5,
		CreatedAt:   time.Now().Unix(),
	}
	id, err := dao.Save(r)
	if err != nil {
		t.Fatal(err)
	}
	if id <= 0 {
		t.Fatal("expected id > 0")
	}

	found, err := dao.FindByWindow("week", 1000, 2000)
	if err != nil {
		t.Fatal(err)
	}
	if found.Summary != "test" {
		t.Fatalf("summary mismatch: %s", found.Summary)
	}
	if len(found.Highlights) != 2 {
		t.Fatalf("highlights mismatch: %v", found.Highlights)
	}
	if found.NoteCount != 5 {
		t.Fatalf("note_count mismatch: %d", found.NoteCount)
	}

	_, err = dao.FindByWindow("week", 2000, 3000)
	if err != ErrWeeklyNotFound {
		t.Fatalf("expected ErrWeeklyNotFound, got %v", err)
	}

	r2 := &model.WeeklyReport{
		Preset: "week", RangeStart: 1000, RangeEnd: 2000,
		Summary: "replaced", Highlights: []string{"c"}, ActionItems: []string{"y"},
		NoteCount: 9, CreatedAt: time.Now().Unix(),
	}
	replacedID, err := dao.Save(r2)
	if err != nil {
		t.Fatalf("save replace: %v", err)
	}
	if replacedID != id {
		t.Fatalf("report id changed after replacement: got %d want %d", replacedID, id)
	}
	got, err := dao.FindByWindow("week", 1000, 2000)
	if err != nil {
		t.Fatal(err)
	}
	if got.Summary != "replaced" || got.NoteCount != 9 || len(got.Highlights) != 1 {
		t.Fatalf("replace mismatch: %+v", got)
	}
}

func TestWeeklyReflectionMessageDAO(t *testing.T) {
	db, err := OpenDB(t.TempDir() + "/test.db")
	if err != nil {
		t.Fatal(err)
	}
	defer db.Close()
	dao := NewWeeklyReflectionMessageDAO(db)

	if _, err := dao.Create(&model.WeeklyReflectionMessage{
		ReportID: 1, Role: model.WeeklyReflectionRoleUser, Content: "我该怎么调整？", CreatedAt: 10,
	}); err != nil {
		t.Fatal(err)
	}
	if _, err := dao.Create(&model.WeeklyReflectionMessage{
		ReportID: 1, Role: model.WeeklyReflectionRoleAssistant, Content: "先完成一件重要的事。", ResponseID: "resp_1", CreatedAt: 11,
	}); err != nil {
		t.Fatal(err)
	}

	list, err := dao.ListByReportID(1, 12)
	if err != nil {
		t.Fatal(err)
	}
	if len(list) != 2 || list[1].ResponseID != "resp_1" {
		t.Fatalf("unexpected messages: %+v", list)
	}
}
