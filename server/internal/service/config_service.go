package service

import (
	"fmt"
	"strings"
	"sync"

	"essaypad/internal/ai"
	"essaypad/internal/model"
	"essaypad/internal/store"
)

const aiSettingScope = "ai"

const (
	aiBaseURLKey = "base_url"
	aiAPIKeyKey  = "api_key"
	aiModelKey   = "model"
)

type AIConfig struct {
	BaseURL string
	APIKey  string
	Model   string
}

type AIConfigView struct {
	BaseURL   string `json:"base_url"`
	Model     string `json:"model"`
	HasAPIKey bool   `json:"has_api_key"`
}

type ConfigService struct {
	mu       sync.RWMutex
	dao      *store.AppSettingDAO
	aiClient *ai.Client
	defaults AIConfig
	config   AIConfig
}

func NewConfigService(dao *store.AppSettingDAO, aiClient *ai.Client, defaults AIConfig) *ConfigService {
	return &ConfigService{dao: dao, aiClient: aiClient, defaults: defaults, config: defaults}
}

func (s *ConfigService) Current() (AIConfigView, error) {
	config := s.snapshot()
	return AIConfigView{BaseURL: config.BaseURL, Model: config.Model, HasAPIKey: config.APIKey != ""}, nil
}

func (s *ConfigService) Reload() error {
	config, err := s.loadFromDB()
	if err != nil {
		return err
	}
	if err := s.aiClient.ReloadConfig(config.BaseURL, config.APIKey, config.Model); err != nil {
		return err
	}
	s.setConfig(config)
	return nil
}

func (s *ConfigService) Stats() ai.Stats { return s.aiClient.Stats() }

func (s *ConfigService) Update(baseURL, modelName string, apiKey *string) error {
	current := s.snapshot()
	baseURL = strings.TrimSpace(baseURL)
	modelName = strings.TrimSpace(modelName)
	if baseURL == "" || modelName == "" {
		return fmt.Errorf("base_url and model are required")
	}
	next := AIConfig{BaseURL: baseURL, APIKey: current.APIKey, Model: modelName}
	if apiKey != nil {
		next.APIKey = strings.TrimSpace(*apiKey)
	}
	if err := s.aiClient.ReloadConfig(next.BaseURL, next.APIKey, next.Model); err != nil {
		return err
	}
	settings := []*model.AppSetting{
		{Scope: aiSettingScope, Key: aiBaseURLKey, Value: next.BaseURL, ValueType: model.SettingValueTypeString},
		{Scope: aiSettingScope, Key: aiAPIKeyKey, Value: next.APIKey, ValueType: model.SettingValueTypeString, IsSecret: 1},
		{Scope: aiSettingScope, Key: aiModelKey, Value: next.Model, ValueType: model.SettingValueTypeString},
	}
	if err := s.dao.UpsertMany(settings); err != nil {
		_ = s.aiClient.ReloadConfig(current.BaseURL, current.APIKey, current.Model)
		return err
	}
	s.setConfig(next)
	return nil
}

func (s *ConfigService) snapshot() AIConfig {
	s.mu.RLock()
	defer s.mu.RUnlock()
	return s.config
}

func (s *ConfigService) setConfig(config AIConfig) {
	s.mu.Lock()
	s.config = config
	s.mu.Unlock()
}

func (s *ConfigService) loadFromDB() (AIConfig, error) {
	config := s.defaults
	items := []struct {
		key   string
		apply func(string)
	}{
		{aiBaseURLKey, func(value string) { config.BaseURL = value }},
		{aiAPIKeyKey, func(value string) { config.APIKey = value }},
		{aiModelKey, func(value string) { config.Model = value }},
	}
	for _, item := range items {
		setting, err := s.dao.Get(aiSettingScope, item.key)
		if err == store.ErrSettingNotFound {
			continue
		}
		if err != nil {
			return AIConfig{}, err
		}
		item.apply(setting.Value)
	}
	return config, nil
}
