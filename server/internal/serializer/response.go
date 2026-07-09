package serializer

import "github.com/gin-gonic/gin"

const CodeOK = 0

type Resp struct {
	Code int         `json:"code"`
	Msg  string      `json:"msg"`
	Data interface{} `json:"data,omitempty"`
}

func Ok(c *gin.Context, data interface{}) {
	c.JSON(200, Resp{Code: CodeOK, Msg: "ok", Data: data})
}

func Err(c *gin.Context, status int, code int, msg string) {
	c.AbortWithStatusJSON(status, Resp{Code: code, Msg: msg})
}
