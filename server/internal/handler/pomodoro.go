package handler

import (
	"errors"
	"net/http"
	"strconv"

	"github.com/gin-gonic/gin"

	"essaypad/internal/model"
	"essaypad/internal/serializer"
	"essaypad/internal/service"
	"essaypad/internal/store"
)

type PomodoroHandler struct {
	svc *service.PomodoroService
}

func NewPomodoroHandler(svc *service.PomodoroService) *PomodoroHandler {
	return &PomodoroHandler{svc: svc}
}

type createPomodoroReq struct {
	TaskID         int64 `json:"task_id"`
	PlannedMinutes int   `json:"planned_minutes"`
}

func (h *PomodoroHandler) Create(c *gin.Context) {
	var req createPomodoroReq
	if err := c.ShouldBindJSON(&req); err != nil {
		serializer.Err(c, http.StatusBadRequest, 400, "invalid body")
		return
	}
	if req.PlannedMinutes <= 0 || req.PlannedMinutes > 120 {
		serializer.Err(c, http.StatusBadRequest, 400, "planned_minutes must be 1-120")
		return
	}
	id, err := h.svc.Create(req.TaskID, req.PlannedMinutes)
	if err != nil {
		serializer.Err(c, http.StatusInternalServerError, 500, err.Error())
		return
	}
	serializer.Ok(c, gin.H{"id": id})
}

func (h *PomodoroHandler) List(c *gin.Context) {
	taskID, _ := strconv.ParseInt(c.Query("task_id"), 10, 64)
	days, _ := strconv.Atoi(c.DefaultQuery("days", "30"))
	if days <= 0 {
		days = 30
	}
	list, err := h.svc.ListByTask(taskID, days)
	if err != nil {
		serializer.Err(c, http.StatusInternalServerError, 500, err.Error())
		return
	}
	serializer.Ok(c, gin.H{"total": len(list), "list": list})
}

type completePomodoroReq struct {
	ActualMinutes int `json:"actual_minutes"`
	Status        int `json:"status"`
}

func (h *PomodoroHandler) Complete(c *gin.Context) {
	id, err := strconv.ParseInt(c.Param("id"), 10, 64)
	if err != nil {
		serializer.Err(c, http.StatusBadRequest, 400, "invalid id")
		return
	}
	var req completePomodoroReq
	if err := c.ShouldBindJSON(&req); err != nil {
		serializer.Err(c, http.StatusBadRequest, 400, "invalid body")
		return
	}
	if req.Status != model.PomodoroStatusCompleted && req.Status != model.PomodoroStatusAborted {
		serializer.Err(c, http.StatusBadRequest, 400, "status must be 1 (completed) or 2 (aborted)")
		return
	}
	s, err := h.svc.Complete(id, req.ActualMinutes, req.Status)
	if err != nil {
		if errors.Is(err, store.ErrPomodoroNotFound) {
			serializer.Err(c, http.StatusNotFound, 404, "not found")
			return
		}
		serializer.Err(c, http.StatusInternalServerError, 500, err.Error())
		return
	}
	serializer.Ok(c, s)
}