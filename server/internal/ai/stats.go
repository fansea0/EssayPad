package ai

import (
	"sync"
	"time"
)

type Usage struct {
	PromptTokens     int64 `json:"prompt_tokens"`
	CompletionTokens int64 `json:"completion_tokens"`
	TotalTokens      int64 `json:"total_tokens"`
}

type CallLog struct {
	At      int64  `json:"at"`
	Success bool   `json:"success"`
	Error   string `json:"error,omitempty"`
	Usage   *Usage `json:"usage,omitempty"`
}

type Stats struct {
	mu               sync.RWMutex
	TotalCalls       int64     `json:"total_calls"`
	Success          int64     `json:"success"`
	Failed           int64     `json:"failed"`
	PromptTokens     int64     `json:"prompt_tokens"`
	CompletionTokens int64     `json:"completion_tokens"`
	TotalTokens      int64     `json:"total_tokens"`
	LastCallAt       int64     `json:"last_call_at"`
	LastError        string    `json:"last_error,omitempty"`
	LastUsage        *Usage    `json:"last_usage,omitempty"`
	Recent           []CallLog `json:"recent"`
}

func newStats() *Stats {
	return &Stats{Recent: []CallLog{}}
}

func (s *Stats) Record(success bool, errMsg string, usage *Usage) {
	if s == nil {
		return
	}
	s.mu.Lock()
	defer s.mu.Unlock()

	now := time.Now().Unix()
	s.TotalCalls++
	s.LastCallAt = now
	if success {
		s.Success++
		s.LastError = ""
	} else {
		s.Failed++
		s.LastError = errMsg
	}
	if usage != nil {
		s.PromptTokens += usage.PromptTokens
		s.CompletionTokens += usage.CompletionTokens
		s.TotalTokens += usage.TotalTokens
		copied := *usage
		s.LastUsage = &copied
	} else {
		s.LastUsage = nil
	}

	log := CallLog{At: now, Success: success, Error: errMsg, Usage: usage}
	s.Recent = append([]CallLog{log}, s.Recent...)
	if len(s.Recent) > 20 {
		s.Recent = s.Recent[:20]
	}
}

func (s *Stats) Snapshot() Stats {
	if s == nil {
		return Stats{Recent: []CallLog{}}
	}
	s.mu.RLock()
	defer s.mu.RUnlock()

	out := Stats{
		TotalCalls:       s.TotalCalls,
		Success:          s.Success,
		Failed:           s.Failed,
		PromptTokens:     s.PromptTokens,
		CompletionTokens: s.CompletionTokens,
		TotalTokens:      s.TotalTokens,
		LastCallAt:       s.LastCallAt,
		LastError:        s.LastError,
		Recent:           append([]CallLog(nil), s.Recent...),
	}
	if s.LastUsage != nil {
		copied := *s.LastUsage
		out.LastUsage = &copied
	}
	return out
}
