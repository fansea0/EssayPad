package handler

import (
	"net/http"

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

	report, fromCache, err := h.svc.GenerateByMode(preset, req.Force)
	if err != nil {
		serializer.Err(c, http.StatusInternalServerError, 1001, "ai generate failed: "+err.Error())
		return
	}
	serializer.Ok(c, weeklyResp{WeeklyReport: report, FromCache: fromCache})
}