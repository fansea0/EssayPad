package handler

import (
	"net/http"

	"github.com/gin-gonic/gin"

	"essaypad/internal/serializer"
	"essaypad/internal/service"
)

type ConfigHandler struct {
	svc *service.ConfigService
}

func NewConfigHandler(svc *service.ConfigService) *ConfigHandler {
	return &ConfigHandler{svc: svc}
}

type updateAIConfigReq struct {
	BaseURL string  `json:"base_url"`
	APIKey  *string `json:"api_key"`
	Model   string  `json:"model"`
}

func (h *ConfigHandler) Update(c *gin.Context) {
	if h.svc == nil {
		serializer.Err(c, http.StatusInternalServerError, 500, "ai client not initialized")
		return
	}
	var req updateAIConfigReq
	if err := c.ShouldBindJSON(&req); err != nil {
		serializer.Err(c, http.StatusBadRequest, 400, "invalid body")
		return
	}
	if err := h.svc.Update(req.BaseURL, req.Model, req.APIKey); err != nil {
		serializer.Err(c, http.StatusInternalServerError, 500, err.Error())
		return
	}
	serializer.Ok(c, gin.H{})
}

func (h *ConfigHandler) Get(c *gin.Context) {
	config, err := h.svc.Current()
	if err != nil {
		serializer.Err(c, http.StatusInternalServerError, 500, err.Error())
		return
	}
	serializer.Ok(c, config)
}

func (h *ConfigHandler) Stats(c *gin.Context) {
	serializer.Ok(c, h.svc.Stats())
}
