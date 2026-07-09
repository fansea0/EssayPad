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
		AIBaseURL: "https://ark.cn-beijing.volces.com/api/v3",
		AIAPIKey:  "d1cc74fc-2c9f-4a20-821c-2b54e90e65bb",
		AIModel:   "doubao-seed-2-0-mini-260428",
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
