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

type NoteHandler struct {
	svc *service.NoteService
}

func NewNoteHandler(svc *service.NoteService) *NoteHandler {
	return &NoteHandler{svc: svc}
}

type createNoteReq struct {
	Category int    `json:"category"`
	Title    string `json:"title"`
	Content  string `json:"content"`
	TaskID   int64  `json:"task_id"`
}

func (h *NoteHandler) Create(c *gin.Context) {
	var req createNoteReq
	if err := c.ShouldBindJSON(&req); err != nil {
		serializer.Err(c, http.StatusBadRequest, 400, "invalid body")
		return
	}
	now := gnuTime()
	note := &model.Note{
		Category:  req.Category,
		Title:     req.Title,
		Content:   req.Content,
		TaskID:    req.TaskID,
		CreatedAt: now,
		UpdatedAt: now,
	}
	id, err := h.svc.Create(note)
	if err != nil {
		mapErr(c, err)
		return
	}
	note.ID = id
	serializer.Ok(c, note)
}

func (h *NoteHandler) List(c *gin.Context) {
	cat, _ := strconv.Atoi(c.Query("category"))
	page, _ := strconv.Atoi(c.DefaultQuery("page", "1"))
	ps, _ := strconv.Atoi(c.DefaultQuery("page_size", "20"))
	list, total, err := h.svc.List(cat, page, ps)
	if err != nil {
		mapErr(c, err)
		return
	}
	serializer.Ok(c, gin.H{"total": total, "list": list})
}

func (h *NoteHandler) Get(c *gin.Context) {
	id, err := strconv.ParseInt(c.Param("id"), 10, 64)
	if err != nil {
		serializer.Err(c, http.StatusBadRequest, 400, "invalid id")
		return
	}
	note, err := h.svc.Get(id)
	if err != nil {
		mapErr(c, err)
		return
	}
	serializer.Ok(c, note)
}

type updateNoteReq struct {
	Title    *string `json:"title"`
	Content  *string `json:"content"`
	Category *int    `json:"category"`
}

func (h *NoteHandler) Update(c *gin.Context) {
	id, err := strconv.ParseInt(c.Param("id"), 10, 64)
	if err != nil {
		serializer.Err(c, http.StatusBadRequest, 400, "invalid id")
		return
	}
	var req updateNoteReq
	if err := c.ShouldBindJSON(&req); err != nil {
		serializer.Err(c, http.StatusBadRequest, 400, "invalid body")
		return
	}
	old, err := h.svc.Get(id)
	if err != nil {
		mapErr(c, err)
		return
	}
	title := old.Title
	content := old.Content
	cat := old.Category
	if req.Title != nil {
		title = *req.Title
	}
	if req.Content != nil {
		content = *req.Content
	}
	if req.Category != nil {
		cat = *req.Category
	}
	if err := h.svc.Update(id, title, content, cat); err != nil {
		mapErr(c, err)
		return
	}
	updated, _ := h.svc.Get(id)
	serializer.Ok(c, updated)
}

func (h *NoteHandler) Delete(c *gin.Context) {
	id, err := strconv.ParseInt(c.Param("id"), 10, 64)
	if err != nil {
		serializer.Err(c, http.StatusBadRequest, 400, "invalid id")
		return
	}
	if err := h.svc.Delete(id); err != nil {
		mapErr(c, err)
		return
	}
	serializer.Ok(c, gin.H{})
}

func mapErr(c *gin.Context, err error) {
	switch {
	case errors.Is(err, store.ErrNotFound):
		serializer.Err(c, http.StatusNotFound, 404, "not found")
	case errors.Is(err, service.ErrInvalidCategory):
		serializer.Err(c, http.StatusBadRequest, 400, "invalid category")
	case errors.Is(err, service.ErrTitleEmpty):
		serializer.Err(c, http.StatusBadRequest, 400, "title is required")
	default:
		serializer.Err(c, http.StatusInternalServerError, 500, err.Error())
	}
}
