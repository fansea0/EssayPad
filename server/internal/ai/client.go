package ai

import (
	"context"
	"encoding/json"
	"fmt"
	"net/http"
	"strings"
	"sync"
	"time"

	arkmodel "github.com/cloudwego/eino-ext/components/model/ark"
	openaimodel "github.com/cloudwego/eino-ext/components/model/openai"
	"github.com/cloudwego/eino/schema"

	"essaypad/internal/model"
)

type Client struct {
	mu      sync.RWMutex
	chat    *openaimodel.ChatModel
	arkChat *arkmodel.ChatModel
	cfg     clientCfg
	stats   *Stats
}

type clientCfg struct {
	baseURL string
	apiKey  string
	model   string
}

func NewClient(baseURL, apiKey, modelName string) (*Client, error) {
	cfg := clientCfg{baseURL: baseURL, apiKey: apiKey, model: modelName}
	c := &Client{cfg: cfg, stats: newStats()}
	if apiKey == "" {
		return c, nil
	}
	cm, err := openaimodel.NewChatModel(context.Background(), &openaimodel.ChatModelConfig{
		BaseURL: baseURL,
		APIKey:  apiKey,
		Model:   modelName,
	})
	if err != nil {
		return c, nil
	}
	c.chat = cm
	if strings.Contains(baseURL, "ark.cn-beijing.volces.com") {
		c.arkChat, _ = arkmodel.NewChatModel(context.Background(), &arkmodel.ChatModelConfig{BaseURL: baseURL, APIKey: apiKey, Model: modelName})
	}
	return c, nil
}

// Stats 返回当前统计快照
func (c *Client) Stats() Stats {
	if c.stats == nil {
		return Stats{}
	}
	return c.stats.Snapshot()
}

type WeeklyInput struct {
	Notes []*model.Note
	Tasks TaskSummary
	Days  int
}

func (c *Client) GenerateWeekly(input WeeklyInput) (*model.WeeklyReport, error) {
	c.mu.RLock()
	hasChat := c.chat != nil
	c.mu.RUnlock()
	if hasChat {
		return c.generateWeeklyEino(input)
	}
	return c.generateWeeklyHTTP(input)
}

// ReloadConfig 原子替换进程内 AI 配置与模型客户端。
func (c *Client) ReloadConfig(baseURL, apiKey, modelName string) error {
	c.mu.Lock()
	defer c.mu.Unlock()

	c.cfg = clientCfg{baseURL: baseURL, apiKey: apiKey, model: modelName}

	// baseURL/apiKey 为空,降级为"未配置"——清空 chat
	if baseURL == "" || apiKey == "" {
		c.chat = nil
		c.arkChat = nil
		return nil
	}

	cm, err := openaimodel.NewChatModel(context.Background(), &openaimodel.ChatModelConfig{
		BaseURL: baseURL,
		APIKey:  apiKey,
		Model:   modelName,
	})
	if err != nil {
		return fmt.Errorf("create chat model: %w", err)
	}
	c.chat = cm
	c.arkChat = nil
	if strings.Contains(baseURL, "ark.cn-beijing.volces.com") {
		c.arkChat, _ = arkmodel.NewChatModel(context.Background(), &arkmodel.ChatModelConfig{BaseURL: baseURL, APIKey: apiKey, Model: modelName})
	}
	return nil
}

func (c *Client) GenerateReflection(input ReflectionInput) (*model.WeeklyReflection, string, int64, error) {
	c.mu.RLock()
	chat, arkChat := c.chat, c.arkChat
	c.mu.RUnlock()
	messages := []*schema.Message{{Role: schema.System, Content: reflectionSystemPrompt(input.Days)}, {Role: schema.User, Content: buildReflectionPrompt(input)}}
	if arkChat != nil {
		response, err := arkChat.Generate(context.Background(), messages, arkmodel.WithCache(&arkmodel.CacheOption{APIType: arkmodel.ResponsesAPI}))
		recordModelCall(c.stats, response, err)
		if err != nil {
			return nil, "", 0, fmt.Errorf("generate reflection: %w", err)
		}
		reflection, err := parseReflection(response.Content)
		responseID, _ := arkmodel.GetResponseID(response)
		return reflection, responseID, time.Now().Add(24 * time.Hour).Unix(), err
	}
	if chat == nil {
		return nil, "", 0, fmt.Errorf("AI client not configured")
	}
	response, err := chat.Generate(context.Background(), messages)
	recordModelCall(c.stats, response, err)
	if err != nil {
		return nil, "", 0, fmt.Errorf("generate reflection: %w", err)
	}
	reflection, err := parseReflection(response.Content)
	return reflection, "", 0, err
}

func (c *Client) ChatReflection(reflectionJSON string, history []*model.WeeklyReflectionMessage, content, previousResponseID string) (string, string, int64, error) {
	c.mu.RLock()
	chat, arkChat := c.chat, c.arkChat
	c.mu.RUnlock()
	if arkChat != nil && previousResponseID != "" {
		response, err := arkChat.Generate(context.Background(), []*schema.Message{schema.UserMessage(content)}, arkmodel.WithCache(&arkmodel.CacheOption{APIType: arkmodel.ResponsesAPI, HeadPreviousResponseID: &previousResponseID}))
		recordModelCall(c.stats, response, err)
		if err == nil {
			responseID, _ := arkmodel.GetResponseID(response)
			return response.Content, responseID, time.Now().Add(24 * time.Hour).Unix(), nil
		}
	}
	if chat == nil {
		return "", "", 0, fmt.Errorf("AI client not configured")
	}
	messages := []*schema.Message{{Role: schema.System, Content: reflectionChatSystemPrompt(reflectionJSON)}}
	for _, message := range history {
		role := schema.User
		if message.Role == model.WeeklyReflectionRoleAssistant {
			role = schema.Assistant
		}
		messages = append(messages, &schema.Message{Role: role, Content: message.Content})
	}
	messages = append(messages, schema.UserMessage(content))
	response, err := chat.Generate(context.Background(), messages)
	recordModelCall(c.stats, response, err)
	if err != nil {
		return "", "", 0, fmt.Errorf("chat reflection: %w", err)
	}
	return response.Content, "", 0, nil
}

func (c *Client) generateWeeklyEino(input WeeklyInput) (*model.WeeklyReport, error) {
	c.mu.RLock()
	chat := c.chat
	days := input.Days
	c.mu.RUnlock()

	grouped := groupByCategory(input.Notes)
	prompt := buildWeeklyPrompt(grouped, input.Tasks, input.Days)
	resp, err := chat.Generate(context.Background(), []*schema.Message{
		{Role: schema.System, Content: systemPrompt(days)},
		{Role: schema.User, Content: prompt},
	})
	if err != nil {
		recordModelCall(c.stats, nil, err)
		return nil, fmt.Errorf("llm call: %w", err)
	}
	recordModelCall(c.stats, resp, nil)
	return parseWeekly(resp.Content)
}

func recordModelCall(stats *Stats, response *schema.Message, err error) {
	if err != nil {
		stats.Record(false, err.Error(), nil)
		return
	}
	stats.Record(true, "", extractUsage(response))
}

// extractUsage 从 eino ChatResponse 中提取 token usage(若响应里有)
func extractUsage(resp *schema.Message) *Usage {
	if resp == nil || resp.ResponseMeta == nil || resp.ResponseMeta.Usage == nil {
		return nil
	}
	u := resp.ResponseMeta.Usage
	return &Usage{
		PromptTokens:     int64(u.PromptTokens),
		CompletionTokens: int64(u.CompletionTokens),
		TotalTokens:      int64(u.TotalTokens),
	}
}

func (c *Client) generateWeeklyHTTP(input WeeklyInput) (*model.WeeklyReport, error) {
	c.mu.RLock()
	cfg := c.cfg
	c.mu.RUnlock()

	if cfg.apiKey == "" {
		return nil, fmt.Errorf("AI client not configured (set ESSAYPAD_AI_API_KEY)")
	}
	grouped := groupByCategory(input.Notes)
	body := map[string]interface{}{
		"model": cfg.model,
		"messages": []map[string]string{
			{"role": "system", "content": systemPrompt(input.Days)},
			{"role": "user", "content": buildWeeklyPrompt(grouped, input.Tasks, input.Days)},
		},
		"temperature": 0.3,
	}
	payload, _ := json.Marshal(body)
	req, _ := http.NewRequest("POST", strings.TrimRight(cfg.baseURL, "/")+"/chat/completions", strings.NewReader(string(payload)))
	req.Header.Set("Authorization", "Bearer "+cfg.apiKey)
	req.Header.Set("Content-Type", "application/json")
	httpClient := &http.Client{Timeout: 60 * time.Second}
	resp, err := httpClient.Do(req)
	if err != nil {
		c.stats.Record(false, err.Error(), nil)
		return nil, fmt.Errorf("http call: %w", err)
	}
	defer resp.Body.Close()
	if resp.StatusCode != 200 {
		c.stats.Record(false, fmt.Sprintf("http status %d", resp.StatusCode), nil)
		return nil, fmt.Errorf("http status %d", resp.StatusCode)
	}
	// 解析整段响应,既拿 content 也拿 usage
	var raw struct {
		Choices []struct {
			Message struct {
				Content string `json:"content"`
			} `json:"message"`
		} `json:"choices"`
		Usage *Usage `json:"usage"`
	}
	if err := json.NewDecoder(resp.Body).Decode(&raw); err != nil {
		c.stats.Record(false, err.Error(), nil)
		return nil, fmt.Errorf("decode: %w", err)
	}
	if len(raw.Choices) == 0 {
		c.stats.Record(false, "no choices in response", nil)
		return nil, fmt.Errorf("no choices in response")
	}
	c.stats.Record(true, "", raw.Usage)
	return parseWeekly(raw.Choices[0].Message.Content)
}
