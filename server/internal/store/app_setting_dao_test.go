package store

import (
	"testing"

	"essaypad/internal/model"
)

func TestAppSettingDAOUpsertAndGet(t *testing.T) {
	db, err := OpenDB(t.TempDir() + "/test.db")
	if err != nil {
		t.Fatal(err)
	}
	defer db.Close()
	dao := NewAppSettingDAO(db)

	if err := dao.Upsert("ai", "api_key", "secret", model.SettingValueTypeString, 1); err != nil {
		t.Fatal(err)
	}
	setting, err := dao.Get("ai", "api_key")
	if err != nil {
		t.Fatal(err)
	}
	if setting.Value != "secret" || setting.IsSecret != 1 {
		t.Fatalf("unexpected setting: %+v", setting)
	}

	if err := dao.Upsert("ai", "api_key", "updated", model.SettingValueTypeString, 1); err != nil {
		t.Fatal(err)
	}
	setting, err = dao.Get("ai", "api_key")
	if err != nil || setting.Value != "updated" {
		t.Fatalf("upsert failed: setting=%+v err=%v", setting, err)
	}
}

func TestAppSettingDAOUpsertManyIsAtomic(t *testing.T) {
	db, err := OpenDB(t.TempDir() + "/test.db")
	if err != nil {
		t.Fatal(err)
	}
	defer db.Close()
	dao := NewAppSettingDAO(db)
	settings := []*model.AppSetting{
		{Scope: "ai", Key: "base_url", Value: "https://example.com/v1", ValueType: model.SettingValueTypeString},
		{Scope: "ai", Key: "model", Value: "model-a", ValueType: model.SettingValueTypeString},
	}
	if err := dao.UpsertMany(settings); err != nil {
		t.Fatal(err)
	}
	for _, item := range settings {
		stored, err := dao.Get(item.Scope, item.Key)
		if err != nil || stored.Value != item.Value {
			t.Fatalf("missing setting %s: %+v %v", item.Key, stored, err)
		}
	}
}
