package config

import (
	"os"
	"strconv"
)

type Config struct {
	Port      string
	DBPath    string
	AIBaseURL string
	AIAPIKey  string
	AIModel   string
}

func Load() *Config {
	return &Config{
		Port:      getEnv("ESSAYPAD_PORT", "18888"),
		DBPath:    getEnv("ESSAYPAD_DB_PATH", "./data/essaypad.db"),
		AIBaseURL: getEnv("ESSAYPAD_AI_BASE_URL", "https://ark.cn-beijing.volces.com/api/v3"),
		AIAPIKey:  getEnv("ESSAYPAD_AI_API_KEY", ""),
		AIModel:   getEnv("ESSAYPAD_AI_MODEL", "doubao-seed-2-0-mini-260428"),
	}
}

func getEnv(k, def string) string {
	v := os.Getenv(k)
	if v == "" {
		return def
	}
	return v
}

func (c *Config) PortInt() int {
	n, _ := strconv.Atoi(c.Port)
	return n
}
