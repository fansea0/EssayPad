package handler

import (
	"net/http"

	"github.com/gin-gonic/gin"

	"essaypad/internal/ai"
	"essaypad/internal/serializer"
)

type ConfigHandler struct {
	aic *ai.Client
}

func NewConfigHandler(aic *ai.Client) *ConfigHandler {
	return &ConfigHandler{aic: aic}
}

type updateAIConfigReq struct {
	BaseURL string `json:"base_url"`
	APIKey  string `json:"api_key"`
	Model   string `json:"model"`
}

func (h *ConfigHandler) Update(c *gin.Context) {
	if h.aic == nil {
		serializer.Err(c, http.StatusInternalServerError, 500, "ai client not initialized")
		return
	}
	var req updateAIConfigReq
	if err := c.ShouldBindJSON(&req); err != nil {
		serializer.Err(c, http.StatusBadRequest, 400, "invalid body")
		return
	}
	if err := h.aic.SetConfig(req.BaseURL, req.APIKey, req.Model); err != nil {
		serializer.Err(c, http.StatusInternalServerError, 500, err.Error())
		return
	}
	serializer.Ok(c, gin.H{})
}

func (h *ConfigHandler) Stats(c *gin.Context) {
	if h.aic == nil {
		serializer.Ok(c, ai.Stats{})
		return
	}
	serializer.Ok(c, h.aic.Stats())
}
