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

type DiaryHandler struct {
	svc *service.DiaryService
}

func NewDiaryHandler(svc *service.DiaryService) *DiaryHandler {
	return &DiaryHandler{svc: svc}
}

type saveDiaryReq struct {
	DiaryDate int64  `json:"diary_date"`
	Title     string `json:"title"`
	Content   string `json:"content"`
	Mood      int    `json:"mood"`
	Status    int    `json:"status"`
	Activity  int    `json:"activity"`
}

func (h *DiaryHandler) CreateOrUpdateByDate(c *gin.Context) {
	var req saveDiaryReq
	if err := c.ShouldBindJSON(&req); err != nil {
		serializer.Err(c, http.StatusBadRequest, 400, "invalid body")
		return
	}
	now := gnuTime()
	entry := &model.DiaryEntry{
		UserID:    0,
		DiaryDate: req.DiaryDate,
		Title:     req.Title,
		Content:   req.Content,
		Mood:      req.Mood,
		Status:    req.Status,
		Activity:  req.Activity,
		CreatedAt: now,
		UpdatedAt: now,
	}
	saved, err := h.svc.CreateOrUpdateByDate(entry)
	if err != nil {
		diaryMapErr(c, err)
		return
	}
	serializer.Ok(c, saved)
}

func (h *DiaryHandler) List(c *gin.Context) {
	filter := store.DiaryListFilter{
		UserID:  0,
		Mode:    c.DefaultQuery("mode", "all"),
		Keyword: c.Query("keyword"),
	}
	list, total, err := h.svc.List(filter)
	if err != nil {
		diaryMapErr(c, err)
		return
	}
	if list == nil {
		list = []*model.DiaryEntry{}
	}
	serializer.Ok(c, gin.H{"total": total, "list": list})
}

func (h *DiaryHandler) GetByDate(c *gin.Context) {
	date, err := strconv.ParseInt(c.Query("date"), 10, 64)
	if err != nil {
		serializer.Err(c, http.StatusBadRequest, 400, "invalid date")
		return
	}
	entry, err := h.svc.GetByDate(0, date)
	if err != nil {
		diaryMapErr(c, err)
		return
	}
	serializer.Ok(c, entry)
}

func (h *DiaryHandler) Get(c *gin.Context) {
	id, err := strconv.ParseInt(c.Param("id"), 10, 64)
	if err != nil {
		serializer.Err(c, http.StatusBadRequest, 400, "invalid id")
		return
	}
	entry, err := h.svc.Get(id)
	if err != nil {
		diaryMapErr(c, err)
		return
	}
	serializer.Ok(c, entry)
}

type updateDiaryReq struct {
	Title    *string `json:"title"`
	Content  *string `json:"content"`
	Mood     *int    `json:"mood"`
	Status   *int    `json:"status"`
	Activity *int    `json:"activity"`
}

func (h *DiaryHandler) Update(c *gin.Context) {
	id, err := strconv.ParseInt(c.Param("id"), 10, 64)
	if err != nil {
		serializer.Err(c, http.StatusBadRequest, 400, "invalid id")
		return
	}
	var req updateDiaryReq
	if err := c.ShouldBindJSON(&req); err != nil {
		serializer.Err(c, http.StatusBadRequest, 400, "invalid body")
		return
	}
	fields := map[string]interface{}{}
	if req.Title != nil {
		fields["title"] = *req.Title
	}
	if req.Content != nil {
		fields["content"] = *req.Content
	}
	if req.Mood != nil {
		fields["mood"] = *req.Mood
	}
	if req.Status != nil {
		fields["status"] = *req.Status
	}
	if req.Activity != nil {
		fields["activity"] = *req.Activity
	}

	entry, err := h.svc.Update(id, fields)
	if err != nil {
		diaryMapErr(c, err)
		return
	}
	serializer.Ok(c, entry)
}

func (h *DiaryHandler) Delete(c *gin.Context) {
	id, err := strconv.ParseInt(c.Param("id"), 10, 64)
	if err != nil {
		serializer.Err(c, http.StatusBadRequest, 400, "invalid id")
		return
	}
	if err := h.svc.Delete(id); err != nil {
		diaryMapErr(c, err)
		return
	}
	serializer.Ok(c, gin.H{})
}

func diaryMapErr(c *gin.Context, err error) {
	switch {
	case errors.Is(err, store.ErrDiaryNotFound):
		serializer.Err(c, http.StatusNotFound, 404, "not found")
	case errors.Is(err, service.ErrInvalidDiaryDate):
		serializer.Err(c, http.StatusBadRequest, 400, "invalid diary date")
	case errors.Is(err, service.ErrInvalidDiaryMood):
		serializer.Err(c, http.StatusBadRequest, 400, "invalid diary mood")
	case errors.Is(err, service.ErrInvalidDiaryStatus):
		serializer.Err(c, http.StatusBadRequest, 400, "invalid diary status")
	case errors.Is(err, service.ErrInvalidDiaryActivity):
		serializer.Err(c, http.StatusBadRequest, 400, "invalid diary activity")
	default:
		serializer.Err(c, http.StatusInternalServerError, 500, err.Error())
	}
}
