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

type TaskHandler struct {
	svc     *service.TaskService
	noteDAO *store.NoteDAO
}

func NewTaskHandler(svc *service.TaskService, noteDAO *store.NoteDAO) *TaskHandler {
	return &TaskHandler{svc: svc, noteDAO: noteDAO}
}

type createTaskReq struct {
	Title       string `json:"title"`
	Description string `json:"description"`
	Priority    int    `json:"priority"`
	DueAt       int64  `json:"due_at"`
}

func (h *TaskHandler) Create(c *gin.Context) {
	var req createTaskReq
	if err := c.ShouldBindJSON(&req); err != nil {
		serializer.Err(c, http.StatusBadRequest, 400, "invalid body")
		return
	}
	now := gnuTime()
	t := &model.Task{
		Title:       req.Title,
		Description: req.Description,
		Priority:    req.Priority,
		DueAt:       req.DueAt,
		Status:      model.TaskStatusActive,
		Progress:    0,
		CreatedAt:   now,
		UpdatedAt:   now,
	}
	id, err := h.svc.Create(t)
	if err != nil {
		taskMapErr(c, err)
		return
	}
	t.ID = id
	withCount, _ := h.svc.GetWithCount(id)
	if withCount != nil {
		serializer.Ok(c, withCount)
		return
	}
	serializer.Ok(c, t)
}

func (h *TaskHandler) List(c *gin.Context) {
	group := c.DefaultQuery("group", "all")
	list, err := h.svc.ListByGroupWithCount(group)
	if err != nil {
		serializer.Err(c, http.StatusInternalServerError, 500, err.Error())
		return
	}
	if list == nil {
		list = []service.TaskWithCount{}
	}
	serializer.Ok(c, gin.H{"total": len(list), "list": list})
}

func (h *TaskHandler) Get(c *gin.Context) {
	id, err := strconv.ParseInt(c.Param("id"), 10, 64)
	if err != nil {
		serializer.Err(c, http.StatusBadRequest, 400, "invalid id")
		return
	}
	t, err := h.svc.GetWithCount(id)
	if err != nil {
		taskMapErr(c, err)
		return
	}
	serializer.Ok(c, t)
}

type updateTaskReq struct {
	Title       *string `json:"title"`
	Description *string `json:"description"`
	Progress    *int    `json:"progress"`
	Priority    *int    `json:"priority"`
	DueAt       *int64  `json:"due_at"`
	Status      *int    `json:"status"`
}

func (h *TaskHandler) Update(c *gin.Context) {
	id, err := strconv.ParseInt(c.Param("id"), 10, 64)
	if err != nil {
		serializer.Err(c, http.StatusBadRequest, 400, "invalid id")
		return
	}
	var req updateTaskReq
	if err := c.ShouldBindJSON(&req); err != nil {
		serializer.Err(c, http.StatusBadRequest, 400, "invalid body")
		return
	}
	fields := map[string]interface{}{}
	if req.Title != nil {
		fields["title"] = *req.Title
	}
	if req.Description != nil {
		fields["description"] = *req.Description
	}
	if req.Progress != nil {
		if !model.ValidProgress(*req.Progress) {
			serializer.Err(c, http.StatusBadRequest, 400, "progress must be 0/25/50/75/100")
			return
		}
		fields["progress"] = *req.Progress
	}
	if req.Priority != nil {
		if !model.ValidTaskPriority(*req.Priority) {
			serializer.Err(c, http.StatusBadRequest, 400, "invalid priority")
			return
		}
		fields["priority"] = *req.Priority
	}
	if req.DueAt != nil {
		fields["due_at"] = *req.DueAt
	}
	if req.Status != nil {
		fields["status"] = *req.Status
	}

	t, err := h.svc.Update(id, fields)
	if err != nil {
		taskMapErr(c, err)
		return
	}
	withCount, _ := h.svc.GetWithCount(id)
	if withCount != nil {
		serializer.Ok(c, withCount)
		return
	}
	serializer.Ok(c, t)
}

type progressReq struct {
	Progress int `json:"progress"`
}

func (h *TaskHandler) UpdateProgress(c *gin.Context) {
	id, err := strconv.ParseInt(c.Param("id"), 10, 64)
	if err != nil {
		serializer.Err(c, http.StatusBadRequest, 400, "invalid id")
		return
	}
	var req progressReq
	if err := c.ShouldBindJSON(&req); err != nil {
		serializer.Err(c, http.StatusBadRequest, 400, "invalid body")
		return
	}
	if !model.ValidProgress(req.Progress) {
		serializer.Err(c, http.StatusBadRequest, 400, "progress must be 0/25/50/75/100")
		return
	}
	t, err := h.svc.UpdateProgress(id, req.Progress)
	if err != nil {
		taskMapErr(c, err)
		return
	}
	withCount, _ := h.svc.GetWithCount(id)
	if withCount != nil {
		serializer.Ok(c, withCount)
		return
	}
	serializer.Ok(c, t)
}

func (h *TaskHandler) Complete(c *gin.Context) {
	id, err := strconv.ParseInt(c.Param("id"), 10, 64)
	if err != nil {
		serializer.Err(c, http.StatusBadRequest, 400, "invalid id")
		return
	}
	t, err := h.svc.Complete(id)
	if err != nil {
		taskMapErr(c, err)
		return
	}
	withCount, _ := h.svc.GetWithCount(id)
	if withCount != nil {
		serializer.Ok(c, withCount)
		return
	}
	serializer.Ok(c, t)
}

func (h *TaskHandler) MoveToToday(c *gin.Context) {
	id, err := strconv.ParseInt(c.Param("id"), 10, 64)
	if err != nil {
		serializer.Err(c, http.StatusBadRequest, 400, "invalid id")
		return
	}
	t, err := h.svc.MoveToToday(id)
	if err != nil {
		taskMapErr(c, err)
		return
	}
	withCount, _ := h.svc.GetWithCount(id)
	if withCount != nil {
		serializer.Ok(c, withCount)
		return
	}
	serializer.Ok(c, t)
}

func (h *TaskHandler) Delete(c *gin.Context) {
	id, err := strconv.ParseInt(c.Param("id"), 10, 64)
	if err != nil {
		serializer.Err(c, http.StatusBadRequest, 400, "invalid id")
		return
	}
	if err := h.svc.Delete(id); err != nil {
		taskMapErr(c, err)
		return
	}
	serializer.Ok(c, gin.H{})
}

// ListNotes 列出任务关联的所有笔记
func (h *TaskHandler) ListNotes(c *gin.Context) {
	id, err := strconv.ParseInt(c.Param("id"), 10, 64)
	if err != nil {
		serializer.Err(c, http.StatusBadRequest, 400, "invalid id")
		return
	}
	if _, err := h.svc.Get(id); err != nil {
		taskMapErr(c, err)
		return
	}
	notes, err := h.noteDAO.ListByTask(id)
	if err != nil {
		serializer.Err(c, http.StatusInternalServerError, 500, err.Error())
		return
	}
	if notes == nil {
		notes = []*model.Note{}
	}
	serializer.Ok(c, gin.H{"total": len(notes), "list": notes})
}

type attachNoteReq struct {
	NoteID int64 `json:"note_id"`
}

// AttachNote 把现有笔记绑定到任务
func (h *TaskHandler) AttachNote(c *gin.Context) {
	taskID, err := strconv.ParseInt(c.Param("id"), 10, 64)
	if err != nil {
		serializer.Err(c, http.StatusBadRequest, 400, "invalid id")
		return
	}
	var req attachNoteReq
	if err := c.ShouldBindJSON(&req); err != nil {
		serializer.Err(c, http.StatusBadRequest, 400, "invalid body")
		return
	}
	if _, err := h.svc.Get(taskID); err != nil {
		taskMapErr(c, err)
		return
	}
	if _, err := h.noteDAO.Get(req.NoteID); err != nil {
		if errors.Is(err, store.ErrNotFound) {
			serializer.Err(c, http.StatusNotFound, 404, "note not found")
			return
		}
		serializer.Err(c, http.StatusInternalServerError, 500, err.Error())
		return
	}
	if err := h.noteDAO.UpdateTask(req.NoteID, taskID); err != nil {
		taskMapErr(c, err)
		return
	}
	serializer.Ok(c, gin.H{"ok": true})
}

// DetachNote 把笔记从任务解绑
func (h *TaskHandler) DetachNote(c *gin.Context) {
	noteID, err := strconv.ParseInt(c.Param("noteId"), 10, 64)
	if err != nil {
		serializer.Err(c, http.StatusBadRequest, 400, "invalid noteId")
		return
	}
	if err := h.noteDAO.UpdateTask(noteID, 0); err != nil {
		taskMapErr(c, err)
		return
	}
	serializer.Ok(c, gin.H{"ok": true})
}

func taskMapErr(c *gin.Context, err error) {
	switch {
	case errors.Is(err, store.ErrTaskNotFound):
		serializer.Err(c, http.StatusNotFound, 404, "task not found")
	case errors.Is(err, store.ErrNotFound):
		serializer.Err(c, http.StatusNotFound, 404, "not found")
	case errors.Is(err, service.ErrTitleEmpty):
		serializer.Err(c, http.StatusBadRequest, 400, "title is required")
	default:
		serializer.Err(c, http.StatusInternalServerError, 500, err.Error())
	}
}