package main

import (
	"log"
	"os"
	"path/filepath"

	"essaypad/config"
	"essaypad/internal/ai"
	"essaypad/internal/router"
	"essaypad/internal/store"
)

func main() {
	cfg := config.Load()

	if err := os.MkdirAll(filepath.Dir(cfg.DBPath), 0o755); err != nil {
		log.Fatalf("mkdir db dir: %v", err)
	}
	db, err := store.OpenDB(cfg.DBPath)
	if err != nil {
		log.Fatalf("open db: %v", err)
	}
	defer db.Close()

	aic, err := ai.NewClient(cfg.AIBaseURL, cfg.AIAPIKey, cfg.AIModel)
	if err != nil {
		log.Printf("warn: init AI client failed: %v (周报功能不可用)", err)
	}

	r := router.New(db, aic)
	addr := "127.0.0.1:" + cfg.Port
	log.Printf("essaypad server listening on %s", addr)
	if err := r.Run(addr); err != nil {
		log.Fatalf("run: %v", err)
	}
}
