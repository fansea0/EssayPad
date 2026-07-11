package store

import (
	"database/sql"
	"errors"
	"time"

	"essaypad/internal/model"
)

var ErrSettingNotFound = errors.New("setting not found")

type AppSettingDAO struct{ db *sql.DB }

func NewAppSettingDAO(db *sql.DB) *AppSettingDAO { return &AppSettingDAO{db: db} }

func (d *AppSettingDAO) Get(scope, key string) (*model.AppSetting, error) {
	var setting model.AppSetting
	err := d.db.QueryRow(`SELECT id, scope, setting_key, setting_value, value_type, is_secret, created_at, updated_at, is_deleted
		FROM app_settings WHERE scope=? AND setting_key=? AND is_deleted=0`, scope, key).Scan(
		&setting.ID, &setting.Scope, &setting.Key, &setting.Value, &setting.ValueType,
		&setting.IsSecret, &setting.CreatedAt, &setting.UpdatedAt, &setting.IsDeleted,
	)
	if errors.Is(err, sql.ErrNoRows) {
		return nil, ErrSettingNotFound
	}
	if err != nil {
		return nil, err
	}
	return &setting, nil
}

func (d *AppSettingDAO) Upsert(scope, key, value string, valueType, isSecret int) error {
	now := time.Now().Unix()
	_, err := d.db.Exec(`INSERT INTO app_settings
		(scope, setting_key, setting_value, value_type, is_secret, created_at, updated_at, is_deleted)
		VALUES (?, ?, ?, ?, ?, ?, ?, 0)
		ON CONFLICT(scope, setting_key) DO UPDATE SET
		setting_value=excluded.setting_value, value_type=excluded.value_type,
		is_secret=excluded.is_secret, updated_at=excluded.updated_at, is_deleted=0`,
		scope, key, value, valueType, isSecret, now, now,
	)
	return err
}

func (d *AppSettingDAO) UpsertMany(settings []*model.AppSetting) error {
	tx, err := d.db.Begin()
	if err != nil {
		return err
	}
	defer tx.Rollback()
	now := time.Now().Unix()
	for _, setting := range settings {
		if _, err := tx.Exec(`INSERT INTO app_settings
			(scope, setting_key, setting_value, value_type, is_secret, created_at, updated_at, is_deleted)
			VALUES (?, ?, ?, ?, ?, ?, ?, 0)
			ON CONFLICT(scope, setting_key) DO UPDATE SET
			setting_value=excluded.setting_value, value_type=excluded.value_type,
			is_secret=excluded.is_secret, updated_at=excluded.updated_at, is_deleted=0`,
			setting.Scope, setting.Key, setting.Value, setting.ValueType, setting.IsSecret, now, now); err != nil {
			return err
		}
	}
	return tx.Commit()
}
