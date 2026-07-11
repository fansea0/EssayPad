package model

const (
	SettingValueTypeString = iota
	SettingValueTypeJSON
)

type AppSetting struct {
	ID        int64  `json:"id"`
	Scope     string `json:"scope"`
	Key       string `json:"key"`
	Value     string `json:"-"`
	ValueType int    `json:"value_type"`
	IsSecret  int    `json:"is_secret"`
	CreatedAt int64  `json:"created_at"`
	UpdatedAt int64  `json:"updated_at"`
	IsDeleted int    `json:"is_deleted"`
}
