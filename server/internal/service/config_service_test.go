package service

import (
	"testing"

	"essaypad/internal/ai"
	"essaypad/internal/model"
	"essaypad/internal/store"
)

func TestConfigServiceCachesUntilReload(t *testing.T) {
	db, err := store.OpenDB(t.TempDir() + "/test.db")
	if err != nil {
		t.Fatal(err)
	}
	defer db.Close()
	dao := store.NewAppSettingDAO(db)
	client, err := ai.NewClient("https://default.example/v1", "", "default-model")
	if err != nil {
		t.Fatal(err)
	}
	svc := NewConfigService(dao, client, AIConfig{BaseURL: "https://default.example/v1", Model: "default-model"})
	if err := svc.Reload(); err != nil {
		t.Fatal(err)
	}

	if err := dao.Upsert("ai", "model", "database-model", model.SettingValueTypeString, 0); err != nil {
		t.Fatal(err)
	}
	before, _ := svc.Current()
	if before.Model != "default-model" {
		t.Fatalf("config changed without reload: %+v", before)
	}
	if err := svc.Reload(); err != nil {
		t.Fatal(err)
	}
	after, _ := svc.Current()
	if after.Model != "database-model" {
		t.Fatalf("config did not reload: %+v", after)
	}
}
