package store

import (
	"os"
	"path/filepath"
	"testing"
	"time"

	"essaypad/internal/model"
)

func newTestDB(t *testing.T) (*NoteDAO, func()) {
	t.Helper()
	dir := t.TempDir()
	dbPath := filepath.Join(dir, "test.db")
	db, err := OpenDB(dbPath)
	if err != nil {
		t.Fatal(err)
	}
	return NewNoteDAO(db), func() {
		db.Close()
		os.Remove(dbPath)
	}
}

func TestCreateAndGet(t *testing.T) {
	dao, cleanup := newTestDB(t)
	defer cleanup()

	now := time.Now().Unix()
	note := &model.Note{
		Category:  model.CategoryBug,
		Title:     "登录页 500",
		Content:   "## 复现\n点登录就崩",
		CreatedAt: now,
		UpdatedAt: now,
	}
	id, err := dao.Create(note)
	if err != nil {
		t.Fatalf("create: %v", err)
	}
	if id <= 0 {
		t.Fatalf("expected id > 0, got %d", id)
	}

	got, err := dao.Get(id)
	if err != nil {
		t.Fatalf("get: %v", err)
	}
	if got.Title != note.Title || got.Content != note.Content {
		t.Fatalf("mismatch: %+v", got)
	}
}

func TestListByCategory(t *testing.T) {
	dao, cleanup := newTestDB(t)
	defer cleanup()

	now := time.Now().Unix()
	for i := 0; i < 3; i++ {
		_, _ = dao.Create(&model.Note{Category: model.CategoryBug, Title: "b", Content: "c", CreatedAt: now, UpdatedAt: now})
	}
	for i := 0; i < 2; i++ {
		_, _ = dao.Create(&model.Note{Category: model.CategoryIdea, Title: "i", Content: "c", CreatedAt: now, UpdatedAt: now})
	}

	list, total, err := dao.List(model.CategoryBug, 1, 10)
	if err != nil {
		t.Fatalf("list: %v", err)
	}
	if total != 3 || len(list) != 3 {
		t.Fatalf("expected 3 bug notes, got total=%d len=%d", total, len(list))
	}
}

func TestUpdate(t *testing.T) {
	dao, cleanup := newTestDB(t)
	defer cleanup()

	now := time.Now().Unix()
	id, _ := dao.Create(&model.Note{Category: model.CategoryIdea, Title: "old", Content: "old", CreatedAt: now, UpdatedAt: now})

	if err := dao.Update(id, "new title", "new content", model.CategoryRequirement); err != nil {
		t.Fatalf("update: %v", err)
	}
	got, _ := dao.Get(id)
	if got.Title != "new title" || got.Content != "new content" || got.Category != model.CategoryRequirement {
		t.Fatalf("update failed: %+v", got)
	}
}

func TestSoftDelete(t *testing.T) {
	dao, cleanup := newTestDB(t)
	defer cleanup()

	now := time.Now().Unix()
	id, _ := dao.Create(&model.Note{Category: model.CategoryIdea, Title: "x", Content: "x", CreatedAt: now, UpdatedAt: now})

	if err := dao.SoftDelete(id); err != nil {
		t.Fatalf("soft delete: %v", err)
	}
	_, err := dao.Get(id)
	if err == nil {
		t.Fatal("expected error for deleted note")
	}
}

func TestListInRange(t *testing.T) {
	dao, cleanup := newTestDB(t)
	defer cleanup()

	old := time.Now().Add(-10 * 24 * time.Hour).Unix()
	recent := time.Now().Unix()

	_, _ = dao.Create(&model.Note{Category: model.CategoryIdea, Title: "old", Content: "o", CreatedAt: old, UpdatedAt: old})
	_, _ = dao.Create(&model.Note{Category: model.CategoryIdea, Title: "new", Content: "n", CreatedAt: recent, UpdatedAt: recent})

	notes, err := dao.ListInRange(7)
	if err != nil {
		t.Fatalf("list in range: %v", err)
	}
	if len(notes) != 1 {
		t.Fatalf("expected 1 recent note, got %d", len(notes))
	}
}

func TestListInRangeByModeToday(t *testing.T) {
	dao, cleanup := newTestDB(t)
	defer cleanup()

	loc := time.Local
	today := time.Date(time.Now().Year(), time.Now().Month(), time.Now().Day(), 0, 0, 0, 0, loc)
	todayStart := today.Unix()
	yesterdayTs := todayStart - 43200
	nowTs := todayStart + 3600

	_, _ = dao.Create(&model.Note{Category: model.CategoryIdea, Title: "today1", Content: "", CreatedAt: nowTs, UpdatedAt: nowTs})
	_, _ = dao.Create(&model.Note{Category: model.CategoryIdea, Title: "today2", Content: "", CreatedAt: todayStart + 1, UpdatedAt: todayStart + 1})
	_, _ = dao.Create(&model.Note{Category: model.CategoryIdea, Title: "yesterday", Content: "", CreatedAt: yesterdayTs, UpdatedAt: yesterdayTs})

	notes, err := dao.ListInRangeByMode("today")
	if err != nil {
		t.Fatalf("list in range: %v", err)
	}
	if len(notes) != 2 {
		t.Fatalf("expected 2 today notes, got %d", len(notes))
	}
	for _, n := range notes {
		if n.Title == "yesterday" {
			t.Fatalf("yesterday note leaked into today: %+v", n)
		}
	}
}

func TestListInRangeByModeYesterday(t *testing.T) {
	dao, cleanup := newTestDB(t)
	defer cleanup()

	loc := time.Local
	today := time.Date(time.Now().Year(), time.Now().Month(), time.Now().Day(), 0, 0, 0, 0, loc)
	yesterday := today.AddDate(0, 0, -1)
	yesterdayMid := yesterday.Unix() + 43200
	nowTs := today.Unix() + 3600

	_, _ = dao.Create(&model.Note{Category: model.CategoryIdea, Title: "y", Content: "", CreatedAt: yesterdayMid, UpdatedAt: yesterdayMid})
	_, _ = dao.Create(&model.Note{Category: model.CategoryIdea, Title: "t", Content: "", CreatedAt: nowTs, UpdatedAt: nowTs})

	notes, err := dao.ListInRangeByMode("yesterday")
	if err != nil {
		t.Fatalf("list in range: %v", err)
	}
	if len(notes) != 1 {
		t.Fatalf("expected 1 yesterday note, got %d", len(notes))
	}
	if notes[0].Title != "y" {
		t.Fatalf("unexpected note: %+v", notes[0])
	}
}

func TestListInRangeByModeWeek(t *testing.T) {
	dao, cleanup := newTestDB(t)
	defer cleanup()

	nowTs := time.Now().Unix()
	oldTs := nowTs - 14*86400

	_, _ = dao.Create(&model.Note{Category: model.CategoryIdea, Title: "thisweek", Content: "", CreatedAt: nowTs, UpdatedAt: nowTs})
	_, _ = dao.Create(&model.Note{Category: model.CategoryIdea, Title: "long", Content: "", CreatedAt: oldTs, UpdatedAt: oldTs})
	_, _ = dao.Create(&model.Note{Category: model.CategoryDraft, Title: "draft", Content: "", CreatedAt: nowTs, UpdatedAt: nowTs})

	notes, err := dao.ListInRangeByMode("week")
	if err != nil {
		t.Fatalf("list in range: %v", err)
	}
	if len(notes) != 1 {
		t.Fatalf("expected 1 week note, got %d", len(notes))
	}
	if notes[0].Title != "thisweek" {
		t.Fatalf("unexpected note: %+v", notes[0])
	}
}

func TestTrimCategoryToLimit(t *testing.T) {
	dao, cleanup := newTestDB(t)
	defer cleanup()

	now := time.Now().Unix()
	for i := 0; i < 25; i++ {
		ts := now - int64(25-i)
		_, err := dao.Create(&model.Note{
			Category:  model.CategoryDraft,
			Title:     "x",
			Content:   "",
			CreatedAt: ts,
			UpdatedAt: ts,
		})
		if err != nil {
			t.Fatalf("create %d: %v", i, err)
		}
	}

	n, err := dao.TrimCategoryToLimit(model.CategoryDraft, 20)
	if err != nil {
		t.Fatalf("trim: %v", err)
	}
	if n != 5 {
		t.Fatalf("expected delete 5, got %d", n)
	}

	list, total, err := dao.List(model.CategoryDraft, 1, 100)
	if err != nil {
		t.Fatalf("list: %v", err)
	}
	if total != 20 || len(list) != 20 {
		t.Fatalf("expected 20 draft notes, got total=%d len=%d", total, len(list))
	}
}
