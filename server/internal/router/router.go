package router

import (
	"bytes"
	"database/sql"
	"io"
	"log"
	"net/http"
	"strings"

	"github.com/gin-gonic/gin"

	"essaypad/internal/ai"
	"essaypad/internal/handler"
	"essaypad/internal/service"
	"essaypad/internal/store"
)

func New(db *sql.DB, aic *ai.Client) *gin.Engine {
	r := gin.Default()
	r.Use(func(c *gin.Context) {
		if c.Request.Method == "PUT" || c.Request.Method == "POST" {
			body, _ := io.ReadAll(c.Request.Body)
			c.Request.Body = io.NopCloser(bytes.NewBuffer(body))
			if len(body) > 0 && len(body) < 1000 && !strings.HasPrefix(c.Request.URL.Path, "/api/v1/weekly/") {
				log.Printf("[SRV] %s %s body=%s", c.Request.Method, c.Request.URL.Path, string(body))
			}
		}
		c.Next()
	})
	dao := store.NewNoteDAO(db)
	weeklyDAO := store.NewWeeklyDAO(db)
	weeklyMessageDAO := store.NewWeeklyReflectionMessageDAO(db)
	taskDAO := store.NewTaskDAO(db)
	pomodoroDAO := store.NewPomodoroDAO(db)
	diaryDAO := store.NewDiaryDAO(db)
	noteSvc := service.NewNoteService(dao)
	weeklySvc := service.NewWeeklyService(dao, weeklyDAO, taskDAO, diaryDAO, weeklyMessageDAO, aic)
	taskSvc := service.NewTaskService(taskDAO, dao, pomodoroDAO)
	pomodoroSvc := service.NewPomodoroService(pomodoroDAO)
	diarySvc := service.NewDiaryService(diaryDAO)

	noteH := handler.NewNoteHandler(noteSvc)
	weeklyH := handler.NewWeeklyHandler(weeklySvc)
	taskH := handler.NewTaskHandler(taskSvc, dao)
	pomodoroH := handler.NewPomodoroHandler(pomodoroSvc)
	diaryH := handler.NewDiaryHandler(diarySvc)
	configH := handler.NewConfigHandler(aic)

	v1 := r.Group("/api/v1")
	{
		v1.POST("/notes", noteH.Create)
		v1.GET("/notes", noteH.List)
		v1.GET("/notes/:id", noteH.Get)
		v1.PUT("/notes/:id", noteH.Update)
		v1.DELETE("/notes/:id", noteH.Delete)
		v1.GET("/diaries", diaryH.List)
		v1.GET("/diaries/by-date", diaryH.GetByDate)
		v1.GET("/diaries/:id", diaryH.Get)
		v1.POST("/diaries", diaryH.CreateOrUpdateByDate)
		v1.PUT("/diaries/:id", diaryH.Update)
		v1.DELETE("/diaries/:id", diaryH.Delete)
		v1.POST("/tasks", taskH.Create)
		v1.GET("/tasks", taskH.List)
		v1.GET("/tasks/:id", taskH.Get)
		v1.PUT("/tasks/:id", taskH.Update)
		v1.DELETE("/tasks/:id", taskH.Delete)
		v1.POST("/tasks/:id/progress", taskH.UpdateProgress)
		v1.POST("/tasks/:id/complete", taskH.Complete)
		v1.POST("/tasks/:id/move-to-today", taskH.MoveToToday)
		v1.GET("/tasks/:id/notes", taskH.ListNotes)
		v1.POST("/tasks/:id/notes", taskH.AttachNote)
		v1.DELETE("/tasks/:id/notes/:noteId", taskH.DetachNote)
		v1.POST("/weekly/generate", weeklyH.Generate)
		v1.GET("/weekly/:id/messages", weeklyH.ListMessages)
		v1.POST("/weekly/:id/messages", weeklyH.Chat)
		v1.DELETE("/weekly/:id/messages", weeklyH.DeleteMessages)
		v1.PUT("/ai-config", configH.Update)
		v1.GET("/ai-config/stats", configH.Stats)
		v1.POST("/pomodoros", pomodoroH.Create)
		v1.GET("/pomodoros", pomodoroH.List)
		v1.POST("/pomodoros/:id/complete", pomodoroH.Complete)
	}
	r.GET("/health", func(c *gin.Context) { c.JSON(http.StatusOK, gin.H{"status": "ok"}) })
	return r
}
