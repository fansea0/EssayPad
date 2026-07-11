package ai

import (
	"strings"
	"testing"
)

func TestParseReflectionAcceptsStoryArray(t *testing.T) {
	reflection, err := parseReflection(`{"greeting":"晚上好","one_liner":"稳稳推进","story":["第一段","第二段"],"observations":[],"growth":[],"suggestions":[]}`)
	if err != nil {
		t.Fatalf("parseReflection returned error: %v", err)
	}
	if reflection.Story != "第一段\n\n第二段" {
		t.Fatalf("unexpected story: %q", reflection.Story)
	}
}

func TestBuildReflectionPromptRequestsUserQuestions(t *testing.T) {
	prompt := buildReflectionPrompt(ReflectionInput{Days: 7})
	if !strings.Contains(prompt, "第一人称追问") || !strings.Contains(prompt, "不能写成 AI 问用户的话") {
		t.Fatalf("suggested questions instruction is missing: %s", prompt)
	}
}
