package handler

import (
	"net/http"
	"strconv"
	"strings"

	"github.com/gin-gonic/gin"

	"essaypad/internal/model"
	"essaypad/internal/serializer"
	"essaypad/internal/service"
)

type WeeklyHandler struct {
	svc *service.WeeklyService
}

func NewWeeklyHandler(svc *service.WeeklyService) *WeeklyHandler {
	return &WeeklyHandler{svc: svc}
}

type weeklyReq struct {
	Preset string `json:"preset"`
	Days   int    `json:"days"`
	Force  bool   `json:"force"`
}

type weeklyResp struct {
	*model.WeeklyReport
	FromCache bool `json:"from_cache"`
}

func (h *WeeklyHandler) Generate(c *gin.Context) {
	var req weeklyReq
	_ = c.ShouldBindJSON(&req)

	preset := req.Preset
	if preset == "" {
		if req.Days > 0 {
			switch req.Days {
			case 1:
				preset = "today"
			case 2:
				preset = "yesterday"
			case 7:
				preset = "week"
			default:
				preset = "week"
			}
		} else {
			preset = "week"
		}
	}

	report, fromCache, err := h.svc.GenerateReflection(preset, req.Force)
	if err != nil {
		serializer.Err(c, http.StatusInternalServerError, 1001, "ai generate failed: "+err.Error())
		return
	}
	serializer.Ok(c, weeklyResp{WeeklyReport: report, FromCache: fromCache})
}

func (h *WeeklyHandler) ListMessages(c *gin.Context) {
	reportID, err := strconv.ParseInt(c.Param("id"), 10, 64)
	if err != nil || reportID <= 0 {
		serializer.Err(c, http.StatusBadRequest, 400, "invalid report id")
		return
	}
	list, err := h.svc.ListMessages(reportID)
	if err != nil {
		serializer.Err(c, http.StatusInternalServerError, 500, err.Error())
		return
	}
	serializer.Ok(c, gin.H{"list": list})
}

func (h *WeeklyHandler) Chat(c *gin.Context) {
	reportID, err := strconv.ParseInt(c.Param("id"), 10, 64)
	if err != nil || reportID <= 0 {
		serializer.Err(c, http.StatusBadRequest, 400, "invalid report id")
		return
	}
	var req struct {
		Content string `json:"content"`
	}
	if err := c.ShouldBindJSON(&req); err != nil || strings.TrimSpace(req.Content) == "" {
		serializer.Err(c, http.StatusBadRequest, 400, "content is required")
		return
	}
	user, assistant, err := h.svc.Chat(reportID, strings.TrimSpace(req.Content))
	if err != nil {
		serializer.Err(c, http.StatusInternalServerError, 1001, "ai chat failed: "+err.Error())
		return
	}
	serializer.Ok(c, gin.H{"user_message": user, "assistant_message": assistant})
}
