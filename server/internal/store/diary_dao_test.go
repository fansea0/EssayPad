package store

import (
	"errors"
	"os"
	"path/filepath"
	"testing"
	"time"

	"essaypad/internal/model"
)

func newDiaryTestDAO(t *testing.T) (*DiaryDAO, func()) {
	t.Helper()
	dir := t.TempDir()
	dbPath := filepath.Join(dir, "test.db")
	db, err := OpenDB(dbPath)
	if err != nil {
		t.Fatal(err)
	}
	return NewDiaryDAO(db), func() {
		db.Close()
		os.Remove(dbPath)
	}
}

func TestDiaryCreateOrUpdateByDateCreatesAndUpdatesOneEntry(t *testing.T) {
	dao, cleanup := newDiaryTestDAO(t)
	defer cleanup()

	day := todayStartUnix()
	now := time.Now().Unix()
	first := &model.DiaryEntry{
		UserID:    0,
		DiaryDate: day,
		Title:     "早晨",
		Content:   "写第一版",
		Mood:      model.DiaryMoodCalm,
		Status:    model.DiaryStatusGood,
		Activity:  model.DiaryActivityWork,
		CreatedAt: now,
		UpdatedAt: now,
	}
	created, err := dao.CreateOrUpdateByDate(first)
	if err != nil {
		t.Fatalf("create: %v", err)
	}
	if created.ID <= 0 {
		t.Fatalf("expected id > 0, got %d", created.ID)
	}

	updatedInput := &model.DiaryEntry{
		UserID:    0,
		DiaryDate: day,
		Title:     "晚上",
		Content:   "补充记录",
		Mood:      model.DiaryMoodHappy,
		Status:    model.DiaryStatusExcellent,
		Activity:  model.DiaryActivityRest,
		CreatedAt: now + 10,
		UpdatedAt: now + 10,
	}
	updated, err := dao.CreateOrUpdateByDate(updatedInput)
	if err != nil {
		t.Fatalf("update by date: %v", err)
	}
	if updated.ID != created.ID {
		t.Fatalf("expected same diary id, got created=%d updated=%d", created.ID, updated.ID)
	}
	if updated.Title != "晚上" || updated.Content != "补充记录" || updated.Mood != model.DiaryMoodHappy {
		t.Fatalf("unexpected updated diary: %+v", updated)
	}

	list, total, err := dao.List(DiaryListFilter{Mode: "all"})
	if err != nil {
		t.Fatalf("list: %v", err)
	}
	if total != 1 || len(list) != 1 {
		t.Fatalf("expected one diary, got total=%d len=%d", total, len(list))
	}
}

func TestDiaryNoOpUpdateDoesNotTouchUpdatedAt(t *testing.T) {
	dao, cleanup := newDiaryTestDAO(t)
	defer cleanup()

	now := time.Now().Unix() - 100
	created, err := dao.CreateOrUpdateByDate(&model.DiaryEntry{
		UserID:    0,
		DiaryDate: todayStartUnix(),
		Title:     "未变",
		Content:   "内容",
		Mood:      model.DiaryMoodCalm,
		Status:    model.DiaryStatusNormal,
		Activity:  model.DiaryActivityStudy,
		CreatedAt: now,
		UpdatedAt: now,
	})
	if err != nil {
		t.Fatalf("create: %v", err)
	}

	updated, err := dao.CreateOrUpdateByDate(&model.DiaryEntry{
		UserID:    created.UserID,
		DiaryDate: created.DiaryDate,
		Title:     created.Title,
		Content:   created.Content,
		Mood:      created.Mood,
		Status:    created.Status,
		Activity:  created.Activity,
		CreatedAt: now + 80,
		UpdatedAt: now + 80,
	})
	if err != nil {
		t.Fatalf("no-op update: %v", err)
	}
	if updated.UpdatedAt != created.UpdatedAt {
		t.Fatalf("no-op update changed updated_at: before=%d after=%d", created.UpdatedAt, updated.UpdatedAt)
	}
}

func TestDiaryListFiltersAndSortsByDiaryDate(t *testing.T) {
	dao, cleanup := newDiaryTestDAO(t)
	defer cleanup()

	now := time.Now()
	today := time.Date(now.Year(), now.Month(), now.Day(), 0, 0, 0, 0, now.Location()).Unix()
	old := today - 10*86400
	yesterday := today - 86400

	entries := []*model.DiaryEntry{
		{DiaryDate: old, Title: "旧记录", Content: "十天前", Mood: 1, Status: 1, Activity: 1, CreatedAt: old, UpdatedAt: old},
		{DiaryDate: today, Title: "今天学习", Content: "Markdown", Mood: 2, Status: 2, Activity: 2, CreatedAt: today, UpdatedAt: today},
		{DiaryDate: yesterday, Title: "昨天出游", Content: "公园", Mood: 3, Status: 3, Activity: 3, CreatedAt: yesterday, UpdatedAt: yesterday},
	}
	for _, entry := range entries {
		if _, err := dao.CreateOrUpdateByDate(entry); err != nil {
			t.Fatalf("create %s: %v", entry.Title, err)
		}
	}

	all, total, err := dao.List(DiaryListFilter{Mode: "all"})
	if err != nil {
		t.Fatalf("list all: %v", err)
	}
	if total != 3 || len(all) != 3 {
		t.Fatalf("expected 3 all, got total=%d len=%d", total, len(all))
	}
	if all[0].Title != "今天学习" || all[1].Title != "昨天出游" || all[2].Title != "旧记录" {
		t.Fatalf("unexpected order: %+v", all)
	}

	week, total, err := dao.List(DiaryListFilter{Mode: "week"})
	if err != nil {
		t.Fatalf("list week: %v", err)
	}
	if total != 2 || len(week) != 2 {
		t.Fatalf("expected 2 week diaries, got total=%d len=%d", total, len(week))
	}

	searched, total, err := dao.List(DiaryListFilter{Mode: "all", Keyword: "markdown"})
	if err != nil {
		t.Fatalf("search: %v", err)
	}
	if total != 1 || searched[0].Title != "今天学习" {
		t.Fatalf("unexpected search result total=%d list=%+v", total, searched)
	}
}

func TestDiarySoftDeleteAllowsRecreateSameDate(t *testing.T) {
	dao, cleanup := newDiaryTestDAO(t)
	defer cleanup()

	day := todayStartUnix()
	created, err := dao.CreateOrUpdateByDate(&model.DiaryEntry{DiaryDate: day, Title: "旧", CreatedAt: day, UpdatedAt: day})
	if err != nil {
		t.Fatalf("create: %v", err)
	}
	if err := dao.SoftDelete(created.ID); err != nil {
		t.Fatalf("delete: %v", err)
	}
	if _, err := dao.Get(created.ID); !errors.Is(err, ErrDiaryNotFound) {
		t.Fatalf("expected ErrDiaryNotFound after delete, got %v", err)
	}

	recreated, err := dao.CreateOrUpdateByDate(&model.DiaryEntry{DiaryDate: day, Title: "新", CreatedAt: day + 10, UpdatedAt: day + 10})
	if err != nil {
		t.Fatalf("recreate: %v", err)
	}
	if recreated.ID != created.ID {
		t.Fatalf("expected deleted row restored for same date, got old=%d new=%d", created.ID, recreated.ID)
	}
	if recreated.Title != "新" {
		t.Fatalf("unexpected recreated diary: %+v", recreated)
	}
}
