package ai

import (
	"errors"
	"testing"

	"github.com/cloudwego/eino/schema"
)

func TestRecordModelCallTracksUsage(t *testing.T) {
	stats := newStats()
	response := &schema.Message{ResponseMeta: &schema.ResponseMeta{Usage: &schema.TokenUsage{
		PromptTokens: 120, CompletionTokens: 30, TotalTokens: 150,
	}}}

	recordModelCall(stats, response, nil)

	snapshot := stats.Snapshot()
	if snapshot.TotalCalls != 1 || snapshot.Success != 1 {
		t.Fatalf("unexpected call counts: %+v", snapshot)
	}
	if snapshot.PromptTokens != 120 || snapshot.CompletionTokens != 30 || snapshot.TotalTokens != 150 {
		t.Fatalf("unexpected usage: %+v", snapshot)
	}
}

func TestRecordModelCallTracksFailure(t *testing.T) {
	stats := newStats()

	recordModelCall(stats, nil, errors.New("request failed"))

	snapshot := stats.Snapshot()
	if snapshot.TotalCalls != 1 || snapshot.Failed != 1 || snapshot.LastError != "request failed" {
		t.Fatalf("unexpected failure stats: %+v", snapshot)
	}
}
